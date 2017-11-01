# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
package AuctionDataManager;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use DataManagers::DataManager;
use Parameters qw(getParamValue);
use WeathervaneTypes;
use List::Util qw[min max];
use POSIX;
use Try::Tiny;
use Log::Log4perl qw(get_logger);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

extends 'DataManager';

has '+name' => ( default => 'Weathervane', );

has 'dbLoaderClasspath' => (
	is  => 'rw',
	isa => 'Str',
);

# default scale factors
my $defaultUsersScaleFactor           = 5;
my $defaultUsersPerAuctionScaleFactor = 15.0;

override 'initialize' => sub {
	my ($self) = @_;

	super();

	my $weathervaneHome  = $self->getParamValue('weathervaneHome');
	my $dbLoaderImageDir = $self->getParamValue('dbLoaderImageDir');
	if ( !( $dbLoaderImageDir =~ /^\// ) ) {
		$dbLoaderImageDir = $weathervaneHome . "/" . $dbLoaderImageDir;
	}
	$self->setParamValue( 'dbLoaderImageDir', $dbLoaderImageDir );

	my $dbLoaderDir = $self->getParamValue('dbLoaderDir');
	$self->setParamValue( 'dbLoaderDir',
		"$dbLoaderDir/dbLoader.jar:$dbLoaderDir/dbLoaderLibs/*:$dbLoaderDir/dbLoaderLibs" );

	$self->dbLoaderClasspath( "$dbLoaderDir/dbLoader.jar:$dbLoaderDir/dbLoaderLibs/*:$dbLoaderDir/dbLoaderLibs" );

};

sub prepareData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $reloadDb       = $self->getParamValue('reloadDb');
	my $appInstance    = $self->appInstance;
	my $retVal         = 0;

	$console_logger->info(
		"Configuring and starting data services for appInstance " . "$appInstanceNum of workload $workloadNum.\n" );

	# The data services must be started for checking whether the data is loaded
	if ($reloadDb) {
		$appInstance->clearDataServicesBeforeStart($logPath);
	}
	$appInstance->configureAndStartDataServices($logPath);
	# Make sure that the services know their external port numbers
	$self->appInstance->setExternalPortNumbers();
	sleep(10);

	# Make sure that all of the data services are up
	$logger->debug(
		"Checking that all data services are up for appInstance $appInstanceNum of workload $workloadNum." );
	my $allUp = $appInstance->isUpDataServices($logPath);
	if ( !$allUp ) {
		$console_logger->error(
			"Couldn't bring up all data services for appInstance $appInstanceNum of workload $workloadNum." );
		return 0;
	}
	$logger->debug( "All data services are up for appInstance $appInstanceNum of workload $workloadNum." );

	my $loadedData = 0;
	if ($reloadDb) {
		$appInstance->clearDataServicesAfterStart($logPath);

		# Either need to or have been asked to load the data
		$retVal = $self->loadData( $users, $logPath );
		if ( !$retVal ) { return 0; }
		$loadedData = 1;

		# Clear reloadDb so we don't reload on each run of a series
		$self->setParamValue( 'reloadDb', 0 );
	}
	else {
		if ( !$self->isDataLoaded( $users, $logPath ) ) {
			if ( $self->getParamValue('loadDb') ) {
				$console_logger->info(
					    "Data is not loaded for $users users for appInstance "
					  . "$appInstanceNum of workload $workloadNum. Loading data." );

				# Load the data
				$appInstance->stopDataServices($logPath);
				$appInstance->unRegisterPortNumbers();
				$appInstance->cleanupDataServices();
				$appInstance->removeDataServices($logPath);
				$appInstance->clearDataServicesBeforeStart($logPath);
				$appInstance->configureAndStartDataServices( $logPath, $users );
				# Make sure that the services know their external port numbers
				$self->appInstance->setExternalPortNumbers();

				$logger->debug( "All data services configured and started for appInstance "
					  . "$appInstanceNum of workload $workloadNum.  Checking if they are up." );

				# Make sure that all of the data services are up
				my $allUp = $appInstance->isUpDataServices($logPath);
				if ( !$allUp ) {
					$console_logger->error( "Couldn't bring up all data services for appInstance "
						  . "$appInstanceNum of workload $workloadNum." );
					return 0;
				}

				$logger->debug( "Clear data services after start for appInstance "
					  . "$appInstanceNum of workload $workloadNum.  Checking if they are up." );
				$appInstance->clearDataServicesAfterStart($logPath);

				$retVal = $self->loadData( $users, $logPath );
				if ( !$retVal ) { return 0; }
				$loadedData = 1;

			}
			else {
				$console_logger->error( "Data not loaded for $users users for appInstance "
					  . "$appInstanceNum of workload $workloadNum. To load data, run again with loadDb=true.  Exiting.\n"
				);
				return 0;

			}
		}
		else {
			$console_logger->info( "Data is already loaded for appInstance "
				  . "$appInstanceNum of workload $workloadNum.  Preparing data for current run." );

			# cleanup the databases from any previous run
			$self->cleanData( $users, $logPath );

		}
	}

	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$springProfilesActive .= ",dbprep";
	my $dbLoaderClasspath = $self->dbLoaderClasspath;

	# if the number of auctions wasn't explicitly set, determine based on
	# the usersPerAuctionScaleFactor
	my $auctions = $self->getParamValue('auctions');
	if ( !$auctions ) {
		$auctions = ceil( $users / $self->getParamValue('usersPerAuctionScaleFactor') );
		if ( $auctions < 4 ) {
			$auctions = 4;
		}
	}

	my $dbServersRef    = $self->appInstance->getActiveServicesByType('dbServer');
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

	# If the imageStore type is filesystem, then clean added images from the filesystem
	if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {

		my $fileServersRef    = $self->appInstance->getActiveServicesByType('fileServer');
		my $imageStoreDataDir = $self->getParamValue('imageStoreDir');
		foreach my $fileServer (@$fileServersRef) {
			my $sshConnectString = $fileServer->host->sshConnectString;
			`$sshConnectString \"find $imageStoreDataDir -name '*added*' -delete 2>&1\"`;
		}

	}

	my $logName = "$logPath/PrepareData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	print $logHandle "Preparing auctions to be active in current run\n";
	my $nosqlHostname;
	my $mongodbPort;
	if ( $self->appInstance->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {

		# The mongos will be running on the dataManager
		$nosqlHostname = $self->getIpAddr();
		$mongodbPort   = $self->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $self->appInstance->numNosqlReplicas > 0 ) {
		for ( my $i = 1 ; $i <= $#{$nosqlServersRef} ; $i++ ) {
			my $nosqlService = $nosqlServersRef->[$i];
			$nosqlHostname = $nosqlService->getIpAddr();
			$mongodbPort   = $nosqlService->portMap->{'mongod'};
			$mongodbReplicaSet .= ",$nosqlHostname:$mongodbPort";
		}
	}

	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->getIpAddr();
	my $dbPort        = $dbService->portMap->{ $dbService->getImpl() };

	my $dbLoaderOptions = "";
	if ( $self->getParamValue('dbLoaderEnableJprofiler') ) {
		$dbLoaderOptions .=
		  " -agentpath:/opt/jprofiler7/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m ";
	}

	my $dbPrepOptions = " -a $auctions ";
	$dbPrepOptions .= " -m " . $self->appInstance->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $self->appInstance->numNosqlReplicas . " ";

	my $maxDuration = $self->getParamValue('maxDuration');
	my $totalTime =
	  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
	$dbPrepOptions .= " -f " . max( $maxDuration, $totalTime ) . " ";
	$dbPrepOptions .= " -u " . $users . " ";

	my $heap             = $self->getParamValue('dbLoaderHeap');
	my $sshConnectString = $self->host->sshConnectString;
	my $cmdString =
"$sshConnectString \"java -Xms$heap -Xmx$heap -client $dbLoaderOptions -cp $dbLoaderClasspath -Dspring.profiles.active='$springProfilesActive' -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1\"";
	print $logHandle $cmdString . "\n";
	my $cmdOut = `$cmdString`;
	print $logHandle $cmdOut;
	if ($?) {
		$console_logger->error( "Data preparation process failed.  Check PrepareData.log for more information." );
		return 0;
	}

	if (   ( $self->appInstance->numNosqlReplicas > 0 )
		&& ( $self->appInstance->numNosqlShards == 0 ) )
	{
		$console_logger->info("Waiting for MongoDB Replicas to finish synchronizing.");
		waitForMongodbReplicaSync( $self, $logHandle );
	}

	# stop the data services. They must be started in the main process
	# so that the port numbers are available
	$appInstance->stopDataServices($logPath);
	$appInstance->removeDataServices($logPath);
	$appInstance->unRegisterPortNumbers();

	close $logHandle;
}

sub pretouchData {
	my ( $self, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $retVal         = 0;
	$logger->debug( "pretouchData for workload ", $workloadNum );

	my $logName = "$logPath/PretouchData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

	my @pids            = ();
	if ( $self->getParamValue('mongodbTouch') ) {
		my $nosqlService = $nosqlServersRef->[0];
		if ($nosqlService->host->getParamValue('vicHost')) {
			# mongoDb takes longer to start on VIC
			sleep 240;
		}

		foreach $nosqlService (@$nosqlServersRef) {

			my $hostname = $nosqlService->getIpAddr();
			my $port     = $nosqlService->portMap->{'mongod'};
			my $cmdString;
			my $cmdout;
			my $pid;
			if ( $self->getParamValue('mongodbTouchFull') ) {
				$pid = fork();
				if ( !defined $pid ) {
					$console_logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					print $logHandle "Touching imageFull collection to preload data and indexes\n";
					$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageFull.find({'imageid' : {\$gt : 0}}, {'image' : 0}).count()' auctionFullImages";
					$cmdout = `$cmdString`;
					print $logHandle "$cmdString\n";
					print $logHandle $cmdout;

					$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageFull.find({'_id' : {\$ne : 0}}, {'image' : 0}).count()' auctionFullImages";
					$cmdout = `$cmdString`;
					print $logHandle "$cmdString\n";
					print $logHandle $cmdout;
					exit;
				}
				else {
					push @pids, $pid;
				}
			}

			if ( $self->getParamValue('mongodbTouchPreview') ) {
				$pid = fork();
				if ( !defined $pid ) {
					$console_logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					print $logHandle "Touching imagePreview collection to preload data and indexes\n";
					$cmdString =
"mongo --port $port --host $hostname --eval 'db.imagePreview.find({'imageid' : {\$gt : 0}}, {'image' : 0}).count()' auctionPreviewImages";
					$cmdout = `$cmdString`;
					print $logHandle "$cmdString\n";
					print $logHandle $cmdout;
					exit;
				}
				else {
					push @pids, $pid;
				}

				$pid = fork();
				if ( !defined $pid ) {
					$console_logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					$cmdString =
"mongo --port $port --host $hostname --eval 'db.imagePreview.find({'_id' : {\$ne : 0}}, {'image' : 0}).count()' auctionPreviewImages";
					$cmdout = `$cmdString`;
					print $logHandle "$cmdString\n";
					print $logHandle $cmdout;
					exit;
				}
				else {
					push @pids, $pid;
				}
			}
			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				print $logHandle "Touching imageThumbnail collection to preload data and indexes\n";
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageThumbnail.find({'imageid' : {\$gt : 0}}, {'image' : 0}).count()' auctionThumbnailImages";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;

				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageThumbnail.find({'_id' : {\$ne : 0}}, {'image' : 0}).count()' auctionThumbnailImages";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				print $logHandle "Touching imageInfo collection to preload data and indexes\n";
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageInfo.find({'filepath' : {\$ne : \"\"}}).count()' imageInfo";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;

				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.imageInfo.find({'_id' : {\$ne : 0}}).count()' imageInfo";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				print $logHandle "Touching attendanceRecord collection to preload data and indexes\n";
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.attendanceRecord.find({'_id' : {\$ne : 0}}).count()' attendanceRecord";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.attendanceRecord.find({'userId' : {\$gt : 0}, 'timestamp' : {\$gt:ISODate(\"2000-01-01\")}}).count()' attendanceRecord";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;

				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.attendanceRecord.find({'userId' : {\$gt : 0}, '_id' : {\$ne: 0 }}).count()' attendanceRecord";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.attendanceRecord.find({'userId' : {\$gt : 0}, 'auctionId' : {\$gt: 0 }, 'state' :{\$ne : \"\"} }).count()' attendanceRecord";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.attendanceRecord.find({'auctionId' : {\$gt : 0}}).count()' attendanceRecord";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				print $logHandle "Touching bid collection to preload data and indexes\n";
				$cmdString =
				  "mongo --port $port --host $hostname --eval 'db.bid.find({'_id' : {\$ne : 0}}).count()' bid";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.bid.find({'bidderId' : {\$gt : 0}, 'bidTime' : {\$gt:ISODate(\"2000-01-01\")}}).count()' bid";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
"mongo --port $port --host $hostname --eval 'db.bid.find({'bidderId' : {\$gt : 0}, '_id' : {\$ne: 0 }}).count()' bid";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$cmdString =
				  "mongo --port $port --host $hostname --eval 'db.bid.find({'itemid' : {\$gt : 0}}).count()' bid";
				$cmdout = `$cmdString`;
				print $logHandle "$cmdString\n";
				print $logHandle $cmdout;
				exit;
			}
			else {
				push @pids, $pid;
			}

		}

	}

	foreach my $pid (@pids) {
		waitpid $pid, 0;
	}

	$logger->debug( "pretouchData complete for workload ", $workloadNum );

	close $logHandle;
}

sub loadData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger   = get_logger("Console");
	my $logger           = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $hostname         = $self->host->hostName;
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $logName          = "$logPath/loadData-W${workloadNum}I${appInstanceNum}-$hostname.log";
	my $appInstance      = $self->appInstance;
	my $sshConnectString = $self->host->sshConnectString;

	$logger->debug("loadData for workload $workloadNum, appInstance $appInstanceNum");

	my $applog;
	open( $applog, ">$logName" )
	  or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	  };

	my $maxUsers = $self->getParamValue('maxUsers');
	if ( $users > $maxUsers ) {
		$maxUsers = $users;
	}

	$console_logger->info(
		"Workload $workloadNum, appInstance $appInstanceNum: Loading data for a maximum of $maxUsers users" );

	# if the number of auctions wasn't explicitly set, determine based on
	# the usersPerAuctionScaleFactor
	my $auctions = $self->getParamValue('auctions');
	if ( !$auctions ) {
		$auctions = ceil( $users / $self->getParamValue('usersPerAuctionScaleFactor') );
	}

	my $nosqlServersRef = $appInstance->getActiveServicesByType('nosqlServer');
	my $cmdout;
	my $replicaMasterHostname = "";
	my $replicaMasterPort = "";
	if (   ( $appInstance->numNosqlShards > 0 )
		&& ( $appInstance->numNosqlReplicas > 0 ) )
	{
		$console_logger->( "Loading data in sharded and replicated mongo is not supported yet" );
		return 0;
	}
	elsif ( $appInstance->numNosqlShards > 0 ) {
		print $applog "Sharding MongoDB\n";
		my $localPort = $self->portMap->{'mongos'};
		my $cmdString;

		# Add the shards to the database
		foreach my $nosqlServer (@$nosqlServersRef) {
			my $hostname = $nosqlServer->getIpAddr();
			my $port     = $nosqlServer->portMap->{'mongod'};
			print $applog "Add $hostname as shard.\n";
			$cmdString = "mongo --port $localPort --eval 'printjson(sh.addShard(\\\"$hostname:$port\\\"))'";
			my $cmdout = `$sshConnectString \"$cmdString\"`;
			print $applog "$sshConnectString \"$cmdString\"\n";
			print $applog $cmdout;
		}

		# enable sharding for the databases

		print $applog "Enabling sharding for auction database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"auction\\\"))'";
		my $cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for bid database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"bid\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for attendanceRecord database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"attendanceRecord\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for imageInfo database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"imageInfo\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionFullImages database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"auctionFullImages\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionPreviewImages database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"auctionPreviewImages\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionThumbnailImages database.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.enableSharding(\\\"auctionThumbnailImages\\\"))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;

		# Create indexes for collections
		print $applog "Adding hashed index for userId in attendanceRecord Collection.\n";
		$cmdString =
"mongo --port $localPort attendanceRecord --eval 'printjson(db.attendanceRecord.ensureIndex({userId : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for bidderId in bid Collection.\n";
		$cmdString = "mongo --port $localPort bid --eval 'printjson(db.bid.ensureIndex({bidderId : \\\"hashed\\\"}))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for entityid in imageInfo Collection.\n";
		$cmdString =
		  "mongo --port $localPort imageInfo --eval 'printjson(db.imageInfo.ensureIndex({entityid : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imageFull Collection.\n";
		$cmdString =
"mongo --port $localPort auctionFullImages --eval 'printjson(db.imageFull.ensureIndex({imageid : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imagePreview Collection.\n";
		$cmdString =
"mongo --port $localPort auctionPreviewImages --eval 'printjson(db.imagePreview.ensureIndex({imageid : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imageThumbnail Collection.\n";
		$cmdString =
"mongo --port $localPort auctionThumbnailImages --eval 'printjson(db.imageThumbnail.ensureIndex({imageid : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;

		# shard the collections
		print $applog "Sharding attendanceRecord collection on hashed userId.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"attendanceRecord.attendanceRecord\\\", {\\\"userId\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Sharding bid collection on hashed bidderId.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"bid.bid\\\",{\\\"bidderId\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Sharding imageInfo collection on hashed entityid.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"imageInfo.imageInfo\\\",{\\\"entityid\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Sharding imageFull collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"auctionFullImages.imageFull\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Sharding imagePreview collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"auctionPreviewImages.imagePreview\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;
		print $applog "Sharding imageThumbnail collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --eval 'printjson(sh.shardCollection(\\\"auctionThumbnailImages.imageThumbnail\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))'";
		$cmdout = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;

		# disable the balancer
		print $applog "Disabling the balancer.\n";
		$cmdString = "mongo --port $localPort --eval 'printjson(sh.setBalancerState(false))'";
		$cmdout    = `$sshConnectString \"$cmdString\"`;
		print $applog "$sshConnectString \"$cmdString\"\n";
		print $applog $cmdout;

	}
	elsif ( $appInstance->numNosqlReplicas > 0 ) {
		$logger->debug("Creating the MongoDB Replica Set");
		print $applog "Creating the MongoDB Replica Set\n";
		my $cmdString;
		
		# Create the replica set
		foreach my $nosqlServer (@$nosqlServersRef) {
			my $hostname = $nosqlServer->getIpAddr();
			my $port     = $nosqlServer->portMap->{'mongod'};
			if ( $replicaMasterHostname eq "" ) {
				$replicaMasterHostname = $hostname;
				$replicaMasterPort = $port;

				# Initiate replica set
				print $applog "Add $hostname as replica primary.\n";
				my $replicaName      = "auction" . $nosqlServer->shardNum;
				my $replicaConfig = "{_id : \"$replicaName\", members: [ { _id : 0, host : \"$replicaMasterHostname:$replicaMasterPort\" } ],}";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.initiate($replicaConfig))'";				
				$logger->debug("Add $hostname as replica primary: $cmdString");
				$cmdout = `$cmdString`;
				$logger->debug("Add $hostname as replica primary result : $cmdout");
				print $applog $cmdout;

				print $applog "rs.status() : \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())'";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() : \n$cmdout");
				print $applog $cmdout;

				sleep(30);

				print $applog "rs.status() after 30s: \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())'";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() after 30s : \n$cmdout");
				print $applog $cmdout;

				sleep(30);

				print $applog "rs.status() after 60s: \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())'";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() after 60s : \n$cmdout");
				print $applog $cmdout;

			}
			else {
				print $applog "Add $hostname as replica secondary.\n";
				$cmdString = "mongo --host $replicaMasterHostname --port $replicaMasterPort --eval 'printjson(rs.add(\"$hostname:$port\"))'";
				$logger->debug("Add $hostname as replica secondary: $cmdString");
				$cmdout = `$cmdString`;
				$logger->debug("Add $hostname as replica secondary result : $cmdout");
				print $applog $cmdout;

				print $applog "rs.status() : \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $replicaMasterPort --eval 'printjson(rs.status())'";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() : \n$cmdout");
				print $applog $cmdout;

			}
		}

	}

	# Load the data
	my $dbScriptDir     = $self->getParamValue('dbScriptDir');
	my $dbLoaderOptions = "-d $dbScriptDir/items.json -t " . $self->getParamValue('dbLoaderThreads');
	$dbLoaderOptions .= " -u $maxUsers ";

	$dbLoaderOptions .= " -m " . $appInstance->numNosqlShards . " ";
	$dbLoaderOptions .= " -p " . $appInstance->numNosqlReplicas . " ";

	my $maxDuration = $self->getParamValue('maxDuration');
	my $totalTime =
	  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
	$dbLoaderOptions .= " -f " . max( $maxDuration, $totalTime ) . " ";

	$dbLoaderOptions .= " -a 'Workload $workloadNum, appInstance $appInstanceNum.' ";
	if ( $self->getParamValue('dbLoaderImageDir') ) {
		$dbLoaderOptions .= " -r \"" . $self->getParamValue('dbLoaderImageDir') . "\"";
	}

	my $dbLoaderJavaOptions = "";
	if ( $self->getParamValue('dbLoaderEnableJprofiler') ) {
		$dbLoaderJavaOptions .=
		  "  -agentpath:/opt/jprofiler7/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m ";
	}

	my $springProfilesActive = $appInstance->getSpringProfilesActive();
	$springProfilesActive .= ",dbloader";

	my $dbLoaderClasspath = $self->dbLoaderClasspath;
	my $heap              = $self->getParamValue('dbLoaderHeap');

	my $nosqlHostname;
	my $mongodbPort;
	if ( $appInstance->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {

		# The mongos will be running on the data manager
		$nosqlHostname = $self->getIpAddr();
		$mongodbPort   = $self->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "";
	if ( $appInstance->numNosqlReplicas > 0 ) {
		for ( my $i = 0 ; $i <= $#{$nosqlServersRef} ; $i++ ) {
			my $nosqlService  = $nosqlServersRef->[$i];
			my $nosqlHostname = $nosqlService->getIpAddr();
			my $replicaPort;
			if ($nosqlHostname eq $replicaMasterHostname) {
				$replicaPort = $nosqlService->internalPortMap->{'mongod'};
				print $applog "Creating mongodbReplicaSet define.  $nosqlHostname is primary ($replicaMasterHostname), using port $replicaPort.\n";
				$mongodbReplicaSet .= "$nosqlHostname:$replicaPort";
			} else {
				$replicaPort = $nosqlService->portMap->{'mongod'};
				print $applog "Creating mongodbReplicaSet define.  $nosqlHostname is secondary, using port $replicaPort.\n";
				$mongodbReplicaSet .= ",$nosqlHostname:$replicaPort";
			}
		}
	}

	my $dbServicesRef = $self->appInstance->getActiveServicesByType('dbServer');
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->getIpAddr();
	my $dbPort        = $dbService->portMap->{ $dbService->getImpl() };

	my $ppid = fork();
	if ( $ppid == 0 ) {
		print $applog "Starting dbLoader\n";
		my $cmdString =
"java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -Dwkld=W${workloadNum}I${appInstanceNum} -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBLoader $dbLoaderOptions ";
		my $cmdOut =
`$sshConnectString "$cmdString 2>&1 | tee /tmp/dbLoader_W${workloadNum}I${appInstanceNum}.log" 2>&1  > $logPath/dbLoader_W${workloadNum}I${appInstanceNum}.log `;
		print $applog "$sshConnectString $cmdString\n";
		print $applog $cmdOut;
		exit;
	}

	# get the pid of the dbLoader process
	sleep(30);
	my $loaderPid = "";
	my $out = `$sshConnectString ps x`;
	$logger->debug("Looking for pid of dbLoader_W${workloadNum}I${appInstanceNum}: $out");
	if ( $out =~ /^\s*(\d+)\s\?.*\d\d\sjava.*-Dwkld=W${workloadNum}I${appInstanceNum}.*DBLoader/m ) {
		$loaderPid = $1;
		$logger->debug("Found pid $loaderPid for dbLoader_W${workloadNum}I${appInstanceNum}");
	}
	else {
		# Check again if the data is loaded.  The dbLoader may have finished
		# before 30 seconds
		my $isDataLoaded = 0;
		try {
			$isDataLoaded = $self->isDataLoaded( $users, $logPath );
		};

		if ( !$isDataLoaded ) {
			# check one last time for the pid
			my $out = `$sshConnectString ps x`;
			$logger->debug("Looking for pid of dbLoader_W${workloadNum}I${appInstanceNum}: $out");
			if ( $out =~ /^\s*(\d+)\s\?.*\d\d\sjava.*-Dwkld=W${workloadNum}I${appInstanceNum}.*DBLoader/m ) {
				$loaderPid = $1;
				$logger->debug("Found pid $loaderPid for dbLoader_W${workloadNum}I${appInstanceNum}");
			} else {
				$console_logger->error( "Can't find dbloader pid for workload $workloadNum, appInstance $appInstanceNum" );
				return 0;
			}		
		}
	}

	if ($loaderPid) {
		# open a pipe to follow progress
		open my $driver, "$sshConnectString tail -f --pid=$loaderPid /tmp/dbLoader_W${workloadNum}I${appInstanceNum}.log |"
		  or do {
			$console_logger->error(
				"Can't fork to follow dbloader at $logPath/dbLoader_W${workloadNum}I${appInstanceNum}.log : $!" );
			return 0;
		  };

		while ( my $inline = <$driver> ) {
			if (!($inline =~ /^\d\d\:\d\d/)) {
				print $inline;
			}
		}
		close $driver;
	}
	
	if (   ( $appInstance->numNosqlReplicas > 0 )
		&& ( $appInstance->numNosqlShards == 0 ) )
	{
		$console_logger->info("Waiting for MongoDB Replicas to finish synchronizing.");
		waitForMongodbReplicaSync( $self, $applog );
	}

	close $applog;

	# Now make sure that the data is really loaded properly
	my $isDataLoaded = 0;
	try {
		$isDataLoaded = $self->isDataLoaded( $users, $logPath );
	};

	if ( !$isDataLoaded ) {
		$console_logger->error(
			"Data is still not loaded properly.  Check the logs of the data services for errors.\n" );
		return 0;
	}
	return 1;
}

sub isDataLoaded {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");

	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	$logger->debug("isDataLoaded for workload $workloadNum, appInstance $appInstanceNum");

	my $hostname = $self->host->hostName;

	my $logName = "$logPath/isDataLoaded-W${workloadNum}I${appInstanceNum}-$hostname.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# if the number of auctions wasn't explicitly set, determine based on
	# the usersPerAuctionScaleFactor
	my $auctions = $self->getParamValue('auctions');
	if ( !$auctions ) {
		$auctions = ceil( $users / $self->getParamValue('usersPerAuctionScaleFactor') );
	}

	my $dbPrepOptions = " -a $auctions -c ";
	$dbPrepOptions .= " -m " . $self->appInstance->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $self->appInstance->numNosqlReplicas . " ";

	my $maxDuration = $self->getParamValue('maxDuration');
	my $totalTime =
	  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
	$dbPrepOptions .= " -f " . max( $maxDuration, $totalTime ) . " ";
	$dbPrepOptions .= " -u " . $users . " ";

	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$springProfilesActive .= ",dbprep";

	my $dbLoaderClasspath = $self->dbLoaderClasspath;

	my $nosqlServicesRef = $self->appInstance->getActiveServicesByType("nosqlServer");
	my $nosqlHostname;
	my $mongodbPort;
	if ( $self->appInstance->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServicesRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {

		# The mongos will be running on the datManager
		$nosqlHostname = $self->getIpAddr();
		$mongodbPort   = $self->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $self->appInstance->numNosqlReplicas > 0 ) {
		for ( my $i = 1 ; $i <= $#{$nosqlServicesRef} ; $i++ ) {
			my $nosqlService  = $nosqlServicesRef->[$i];
			my $nosqlHostname = $nosqlService->getIpAddr();
			my $mongodbPort   = $nosqlService->portMap->{'mongod'};
			$mongodbReplicaSet .= ",$nosqlHostname:$mongodbPort";
		}
	}

	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->getIpAddr();
	my $dbPort        = $dbService->portMap->{ $dbService->getImpl() };

	my $sshConnectString = $self->host->sshConnectString;
	print $applog
"$sshConnectString java -client -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1\n";
	my $cmdOut =
`$sshConnectString java -client -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1`;
	print $applog $cmdOut;
	print $applog "$? \n";
	if ($?) {
		$logger->debug( "Data is not loaded for workload $workloadNum, appInstance $appInstanceNum. \$? = $?" );
		return 0;
	}
	else {
		$logger->debug( "Data is loaded for workload $workloadNum, appInstance $appInstanceNum. \$? = $?" );
		return 1;
	}

	close $applog;

}

sub waitForMongodbReplicaSync {
	my ( $self, $runLog ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");

	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	$logger->debug( "waitFormongodbReplicaSync for workload $workloadNum, appInstance $appInstanceNum" );

	my $nosqlServersRef  = $self->appInstance->getActiveServicesByType('nosqlServer');
	my $nosqlServer      = $nosqlServersRef->[0];
	my $nosqlHostname    = $nosqlServer->getIpAddr();
	my $port             = $nosqlServer->portMap->{'mongod'};
	my $sshConnectString = $self->host->sshConnectString;
	my $inSync           = 0;
	while ( !$inSync ) {
		sleep 30;

		my $time1 = -1;
		my $time2 = -1;
		$inSync = 1;
		print $runLog "Checking MongoDB Replica Sync.  rs.status: \n";
		my $cmdString = "mongo --host $nosqlHostname --port $port --eval 'printjson(rs.status())'";
		my $cmdout = `$cmdString`;
		print $runLog $cmdout;

		my @lines = split /\n/, $cmdout;

		# Parse rs.status to see if timestamp is same on primary and secondaries
		foreach my $line (@lines) {
			if ( $line =~ /\"optime\"\s*:\s*Timestamp\((\d+)\,\s*(\d+)/ ) {
				if ( $time1 == -1 ) {
					$time1 = $1;
					$time2 = $2;
				}
				elsif ( ( $time1 != $1 ) || ( $time2 != $2 ) ) {
					print $runLog "Not yet in sync\n";
					$inSync = 0;
					last;
				}
			}
		}
	}
}

sub cleanData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');

	my $appInstance = $self->appInstance;
	my $retVal      = 0;

	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$springProfilesActive .= ",dbprep";
	my $dbLoaderClasspath = $self->dbLoaderClasspath;

	$console_logger->info(
		"Cleaning and compacting storage on all data services.  This can take a long time after large runs." );
	$logger->debug("cleanData.  user = $users, logPath = $logPath");

	# Not preparing any auctions, just cleaning up
	my $auctions = 0;

	my $dbServersRef    = $self->appInstance->getActiveServicesByType('dbServer');
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

	# If the imageStore type is filesystem, then clean added images from the filesystem
	if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
		$logger->debug("cleanData. Deleting added images from fileserver");

		my $fileServersRef    = $self->appInstance->getActiveServicesByType('fileServer');
		my $imageStoreDataDir = $self->getParamValue('imageStoreDir');
		foreach my $fileServer (@$fileServersRef) {
			$logger->debug(
				"cleanData. Deleting added images for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum, " on host ", $fileServer->getIpAddr()
			);
			my $sshConnectString = $fileServer->host->sshConnectString;
			`$sshConnectString \"find $imageStoreDataDir -name '*added*' -delete 2>&1\"`;
		}

	}

	my $logName = "$logPath/CleanData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};
	$logger->debug("cleanData. opened log $logName");

	$logger->debug(
		"cleanData. Cleaning up data services for appInstance " . "$appInstanceNum of workload $workloadNum." );
	print $logHandle "Cleaning up data services for appInstance " . "$appInstanceNum of workload $workloadNum.\n";
	my $nosqlHostname;
	my $mongodbPort;
	if ( $self->appInstance->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {

		# The mongos will be running on the dataManager
		$nosqlHostname = $self->getIpAddr();
		$mongodbPort   = $self->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $self->appInstance->numNosqlReplicas > 0 ) {
		for ( my $i = 1 ; $i <= $#{$nosqlServersRef} ; $i++ ) {
			my $nosqlService = $nosqlServersRef->[$i];
			$nosqlHostname = $nosqlService->getIpAddr();
			$mongodbPort   = $nosqlService->portMap->{'mongod'};
			$mongodbReplicaSet .= ",$nosqlHostname:$mongodbPort";
		}
	}

	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->getIpAddr();
	my $dbPort        = $dbService->portMap->{ $dbService->getImpl() };

	my $dbLoaderOptions = "";
	if ( $self->getParamValue('dbLoaderEnableJprofiler') ) {
		$dbLoaderOptions .=
		  " -agentpath:/opt/jprofiler7/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m ";
	}

	my $dbPrepOptions = " -a $auctions ";
	$dbPrepOptions .= " -m " . $self->appInstance->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $self->appInstance->numNosqlReplicas . " ";

	my $maxDuration = $self->getParamValue('maxDuration');
	my $steadyState = $self->getParamValue('steadyState');
	$dbPrepOptions .= " -f " . max( $maxDuration, $steadyState ) . " ";

	$dbPrepOptions .= " -u " . $users . " ";

	my $heap             = $self->getParamValue('dbLoaderHeap');
	my $sshConnectString = $self->host->sshConnectString;
	my $cmdString =
"$sshConnectString \"java -Xms$heap -Xmx$heap -client $dbLoaderOptions -cp $dbLoaderClasspath -Dspring.profiles.active='$springProfilesActive' -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1\"";
	$logger->debug(
		"cleanData. Running dbPrep to clean data for workload ",
		$workloadNum, " appInstance ",
		$appInstanceNum, ". The command line is: ", $cmdString
	);
	print $logHandle $cmdString . "\n";
	my $cmdOut = `$cmdString`;
	$logger->debug(
		"cleanData. Ran dbPrep to clean data for workload ",
		$workloadNum, " appInstance ",
		$appInstanceNum, ". The output is: ", $cmdOut
	);
	print $logHandle $cmdOut;

	if ($?) {
		$console_logger->error(
			"Data cleaning process failed.  Check CleanData_W${workloadNum}I${appInstanceNum}.log for more information."
		);
		return 0;
	}

	if (   ( $self->appInstance->numNosqlReplicas > 0 )
		&& ( $self->appInstance->numNosqlShards == 0 ) )
	{
		$console_logger->info("Waiting for MongoDB Replicas to finish synchronizing.");
		waitForMongodbReplicaSync( $self, $logHandle );
	}

	if ( $self->getParamValue('mongodbCompact') ) {

		# Compact all mongodb collections
		foreach my $nosqlService (@$nosqlServersRef) {
			my $hostname         = $nosqlService->getIpAddr();
			my $port             = $nosqlService->portMap->{'mongod'};
			print $logHandle "Compacting MongoDB collections on $hostname\n";
			$logger->debug(
				"cleanData. Compacting MongoDB collections on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);

			$logger->debug(
				"cleanData. Compacting attendanceRecord collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			my $cmdString =
"mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"attendanceRecord\" }))' attendanceRecord";
			print $logHandle "$cmdString\n";
			my $cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Compacting bid collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			$cmdString =
			  "mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"bid\" }))' bid";
			print $logHandle "$cmdString\n";
			$cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Compacting imageInfo collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			$cmdString =
"mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"imageInfo\" }))' imageInfo";
			print $logHandle "$cmdString\n";
			$cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Compacting imageFull collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			$cmdString =
"mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"imageFull\" }))' auctionFullImages";
			print $logHandle "$cmdString\n";
			$cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Compacting imagePreview collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			$cmdString =
"mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"imagePreview\" }))' auctionPreviewImages";
			print $logHandle "$cmdString\n";
			$cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Compacting imageThumbnail collection on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);
			$cmdString =
"mongo --port $port --host $hostname --eval 'printjson(db.runCommand({ compact: \"imageThumbnail\" }))' auctionThumbnailImages";
			print $logHandle "$cmdString\n";
			$cmdout = `$cmdString`;
			print $logHandle $cmdout;

			$logger->debug(
				"cleanData. Getting du -hsc /mnt/mongoData on $hostname for workload ",
				$workloadNum, " appInstance ",
				$appInstanceNum
			);

		}
	}
	close $logHandle;
}

__PACKAGE__->meta->make_immutable;

1;

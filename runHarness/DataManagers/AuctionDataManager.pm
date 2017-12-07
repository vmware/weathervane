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
		"Configuring and starting data services for appInstance $appInstanceNum of workload $workloadNum.\n" );
	$logger->debug("prepareData users = $users, logPath = $logPath");

	# Start the data services
	if ($reloadDb) {
		# Avoid an extra stop/start cycle for the data services since we know
		# we are reloading the data
		$appInstance->clearDataServicesBeforeStart($logPath);
	}
	$appInstance->startServices("data", $logPath);
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

	# Calculate the values for the environment variables used by the auctiondatamanager container
	my %envVarMap;
	$envVarMap{"USERSPERAUCTIONSCALEFACTOR"} = $self->getParamValue('usersPerAuctionScaleFactor');	
	$envVarMap{"MAXUSERS"} = $self->getParamValue('maxUsers');	
	$envVarMap{"WORKLOADNUM"} = $workloadNum;	
	$envVarMap{"APPINSTANCENUM"} = $appInstanceNum;	

	my $maxDuration = $self->getParamValue('maxDuration');
	my $totalTime =
	  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
	$envVarMap{"MAXDURATION"} = max( $maxDuration, $totalTime );

	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	my $nosqlServerRef = $nosqlServersRef->[0];
	my $numNosqlShards = $nosqlServerRef->numNosqlShards;
	$envVarMap{"NUMNOSQLSHARDS"} = $numNosqlShards;
	
	my $numNosqlReplicas = $nosqlServerRef->numNosqlReplicas;
	$envVarMap{"NUMNOSQLREPLICAS"} = $numNosqlReplicas;
	
	my $mongodbHostname;
	my $mongodbPort;
	if ( $nosqlService->numNosqlShards == 0 ) {
		$mongodbHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {
		# The mongos will be running on an appServer
		my $appServersRef = $self->appInstance->getActiveServicesByType("appServer");
		my $appServerRef = $appServersRef->[0];
		$mongodbHostname = $appServerRef->getIpAddr();
		$mongodbPort   = $appServerRef->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$mongodbHostname:$mongodbPort";
	if ( $nosqlService->numNosqlReplicas > 0 ) {
		for ( my $i = 1 ; $i <= $#{$nosqlServicesRef} ; $i++ ) {
			my $nosqlService  = $nosqlServicesRef->[$i];
			my $mongodbHostname = $nosqlService->getIpAddr();
			my $mongodbPort   = $nosqlService->portMap->{'mongod'};
			$mongodbReplicaSet .= ",$mongodbHostname:$mongodbPort";
		}
	}
	$envVarMap{"MONGODBHOSTNAME"} = $mongodbHostname;
	$envVarMap{"MONGODBPORT"} = $mongodbPort;
	$envVarMap{"MONGODBREPLICASET"} = $mongodbReplicaSet;
	

	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->getIpAddr();
	my $dbPort        = $dbService->portMap->{ $dbService->getImpl() };
	$envVarMap{"DBHOSTNAME"} = $dbHostname;
	$envVarMap{"DBPORT"} = $dbPort;
	
	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$envVarMap{"SPRINGPROFILESACTIVE"} = $springProfilesActive;
	
	# Start the  auctiondatamanager container
	
		
	my $loadedData = 0;
	if ($reloadDb) {
		$appInstance->clearDataServicesAfterStart($logPath);

		# Have been asked to reload the data
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
				$appInstance->stopServices("data", $logPath);
				$appInstance->unRegisterPortNumbers();
				$appInstance->clearDataServicesBeforeStart($logPath);
				$appInstance->startServices("data", $logPath);
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
	my $nosqlService = $nosqlServersRef->[0];

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
	if ( $nosqlService->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {
		# The mongos will be running on an appServer
		my $appServersRef = $self->appInstance->getActiveServicesByType("appServer");
		my $appServerRef = $appServersRef->[0];
		$nosqlHostname = $appServerRef->getIpAddr();
		$mongodbPort   = $appServerRef->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $nosqlService->numNosqlReplicas > 0 ) {
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
	$dbPrepOptions .= " -m " . $nosqlService->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $nosqlService->numNosqlReplicas . " ";

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

	if (   ( $nosqlService->numNosqlReplicas > 0 )
		&& ( $nosqlService->numNosqlShards == 0 ) )
	{
		$console_logger->info("Waiting for MongoDB Replicas to finish synchronizing.");
		waitForMongodbReplicaSync( $self, $logHandle );
	}

	# stop the data services. They must be started in the main process
	# so that the port numbers are available
	$appInstance->stopServices("data", $logPath);
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


	# Load the data
	my $dbScriptDir     = $self->getParamValue('dbScriptDir');
	my $dbLoaderOptions = "-d $dbScriptDir/items.json -t " . $self->getParamValue('dbLoaderThreads');
	$dbLoaderOptions .= " -u $maxUsers ";

	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	my $nosqlService = $nosqlServersRef->[0];
	$dbLoaderOptions .= " -m " . $nosqlService->numNosqlShards . " ";
	$dbLoaderOptions .= " -p " . $nosqlService->numNosqlReplicas . " ";

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
	if ( $nosqlService->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {
		# The mongos will be running on an appServer
		my $appServersRef = $self->appInstance->getActiveServicesByType("appServer");
		my $appServerRef = $appServersRef->[0];
		$nosqlHostname = $appServerRef->getIpAddr();
		$mongodbPort   = $appServerRef->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "";
	for ( my $i = 0 ; $i <= $#{$nosqlServersRef} ; $i++ ) {
		my $nosqlService  = $nosqlServersRef->[$i];
		my $nosqlHostname = $nosqlService->getIpAddr();
		my $replicaPort;
		if ($i == 0) {
			$replicaPort = $nosqlService->internalPortMap->{'mongod'};
			print $applog "Creating mongodbReplicaSet define.  $nosqlHostname is primary ($nosqlHostname), using port $replicaPort.\n";
			$mongodbReplicaSet .= "$nosqlHostname:$replicaPort";
		} else {
			$replicaPort = $nosqlService->portMap->{'mongod'};
			print $applog "Creating mongodbReplicaSet define.  $nosqlHostname is secondary, using port $replicaPort.\n";
			$mongodbReplicaSet .= ",$nosqlHostname:$replicaPort";
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
	
	if (   ( $nosqlService->numNosqlReplicas > 0 )
		&& ( $nosqlService->numNosqlShards == 0 ) )
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

	my $nosqlServicesRef = $self->appInstance->getActiveServicesByType("nosqlServer");
	my $nosqlService = $nosqlServicesRef->[0];

	my $dbPrepOptions = " -a $auctions -c ";
	$dbPrepOptions .= " -m " . $nosqlService->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $nosqlService->numNosqlReplicas . " ";

	my $maxDuration = $self->getParamValue('maxDuration');
	my $totalTime =
	  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
	$dbPrepOptions .= " -f " . max( $maxDuration, $totalTime ) . " ";
	$dbPrepOptions .= " -u " . $users . " ";

	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$springProfilesActive .= ",dbprep";

	my $dbLoaderClasspath = $self->dbLoaderClasspath;

	my $nosqlHostname;
	my $mongodbPort;
	if ( $nosqlService->numNosqlShards == 0 ) {
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {
		# The mongos will be running on an appServer
		my $appServersRef = $self->appInstance->getActiveServicesByType("appServer");
		my $appServerRef = $appServersRef->[0];
		$nosqlHostname = $appServerRef->getIpAddr();
		$mongodbPort   = $appServerRef->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $nosqlService->numNosqlReplicas > 0 ) {
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
	my $nosqlService = $nosqlServersRef->[0];

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
	if ( $nosqlService->numNosqlShards == 0 ) {
		my $nosqlService = $nosqlServersRef->[0];
		$nosqlHostname = $nosqlService->getIpAddr();
		$mongodbPort   = $nosqlService->portMap->{'mongod'};
	}
	else {

		# The mongos will be running on an appServer
		my $appServersRef = $self->appInstance->getActiveServicesByType("appServer");
		my $appServerRef = $appServersRef->[0];
		$nosqlHostname = $appServerRef->getIpAddr();
		$mongodbPort   = $appServerRef->portMap->{'mongos'};
	}

	my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
	if ( $nosqlService->numNosqlReplicas > 0 ) {
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
	$dbPrepOptions .= " -m " . $nosqlService->numNosqlShards . " ";
	$dbPrepOptions .= " -p " . $nosqlService->numNosqlReplicas . " ";

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

	if (   ( $nosqlService->numNosqlReplicas > 0 )
		&& ( $nosqlService->numNosqlShards == 0 ) )
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

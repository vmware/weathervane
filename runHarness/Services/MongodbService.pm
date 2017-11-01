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
package MongodbService;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use Services::Service;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'MongoDB', );

has '+version' => ( default => '3.0.x', );

has '+description' => ( default => '', );

# This is the number of the shard that this service instance
# is a part of, from 1 to numShards
has 'shardNum' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

# This is the number of the replica that this service instance
# represents.
has 'replicaNum' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

# This holds the total number of config servers
# to be used in sharded mode MongoDB requires
# this to be 3, but we don't want to hard-code
# the number in case it changes someday.
has 'numConfigServers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 3,
);

override 'initialize' => sub {
	my ( $self, $numNosqlServers ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("initialize called with numNosqlServers = $numNosqlServers");
	my $console_logger = get_logger("Console");
	my $appInstance    = $self->appInstance;

	# If it hasn't already been done, figure out how many shards, and how many
	# replicas per shard.
	if ( !$appInstance->has_numNosqlShards ) {
		my $replicasPerShard = $self->getParamValue('nosqlReplicasPerShard');
		my $sharded          = $self->getParamValue('nosqlSharded');
		my $replicated       = $self->getParamValue('nosqlReplicated');

		if ($sharded) {
			if ($replicated) {
				$console_logger->error("Configuring MongoDB as both sharded and replicated is not yet supported.");
				exit(-1);
			}
			if ( $numNosqlServers < 2 ) {
				$console_logger->error("When sharding MongoDB, the number of servers must be greater than 1.");
				exit(-1);
			}
			$appInstance->numNosqlShards($numNosqlServers);
			$appInstance->numNosqlReplicas(0);
		}
		elsif ($replicated) {
			if ( ( $numNosqlServers % $replicasPerShard ) > 0 ) {
				$console_logger->error(
"When replicating MongoDB, the number of servers must be an even multiple of the number of replicas-per-shard."
				);
				exit(-1);
			}
			$appInstance->numNosqlShards(0);
			$appInstance->numNosqlReplicas( $numNosqlServers / $replicasPerShard );
		}
		else {
			if ( $numNosqlServers > 1 ) {
				$console_logger->error(
"When the number of MongoDB servers is greater than 1, the deployment must be sharded or replicated."
				);
				exit(-1);
			}
			$appInstance->numNosqlShards(0);
			$appInstance->numNosqlReplicas(0);
		}

	}

	super();
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $appInstance = $self->appInstance;

	if ( ( $appInstance->numNosqlShards > 0 ) && ( $appInstance->numNosqlReplicas > 0 ) ) {
		$self->stopShardedReplicatedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlShards > 0 ) {
		$self->stopShardedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlReplicas > 0 ) {
		$self->stopReplicatedMongodb($logPath);
	}
	else {
		$self->stopSingleMongodb($logPath);
	}

}

sub stopShardedMongodb {
	my ( $self, $logPath ) = @_;
	my $logger           = get_logger("Weathervane::Services::MongodbService");
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopShardedMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	my $appInstance      = $self->appInstance;
	$logger->debug("stop ShardedMongodbService");

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::stopShardedMongodb\n";
	$logger->debug("In StopShardedMongodb");

	my $cmdOut;

	# If this is the first MongoDB service to run,
	# then configure the numShardsProcessed variable
	if ( !$appInstance->has_numShardsProcessed() ) {
		print $dblog "Setting numShardsProcessed to 1.\n";
		$appInstance->numShardsProcessed(1);
	}
	else {
		my $numShardsProcessed = $appInstance->numShardsProcessed;
		print $dblog "Incrementing numShardsProcessed from $numShardsProcessed \n";
		$appInstance->numShardsProcessed( $numShardsProcessed + 1 );
	}

	# first check for mongod and mongoc on this node and stop if present
	$cmdOut = `$sshConnectString \"ps x | grep mongo | grep -v grep\"`;
	print $dblog "Result of ps x | grep mongo:\n";
	print $dblog "$cmdOut\n";
	my @lines = split /\n/, $cmdOut;

	foreach my $line (@lines) {
		if ( $line =~ /^\s*(\d+)\s.*mongod\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod shard is running on $hostname.  Stopping\n";
			my $port = $self->internalPortMap->{'mongod'};
			$cmdOut = `$sshConnectString mongod --shutdown -f /etc/mongod.conf 2>&1`;
			print $dblog "$cmdOut\n";
			if ( $cmdOut =~ /There\sdoesn't\sseem/ ) {

				# Mongod can't be shutdown normally
				print $dblog "mongod shard is still running on $hostname.  Stopping\n";
				$cmdOut = `$sshConnectString kill -9 $pid`;
				print $dblog "$cmdOut\n";
			}
		}
		if ( $line =~ /^\s*(\d+)\s.*mongoc1\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod configserver1 is running on $hostname.  Stopping\n";
			my $port = $self->internalPortMap->{'mongoc1'};
			$cmdOut = `$sshConnectString mongod --shutdown -f /etc/mongoc1.conf  2>&1`;
			print $dblog "$cmdOut\n";
			if ( $cmdOut =~ /There\sdoesn't\sseem/ ) {

				# Mongod can't be shutdown normally
				print $dblog "mongod configserver1 is still running on $hostname.  Stopping\n";
				$cmdOut = `$sshConnectString kill -9 $pid`;
				print $dblog "$cmdOut\n";
			}
		}
		if ( $line =~ /^\s*(\d+)\s.*mongoc2\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod configserver2 is running on $hostname.  Stopping\n";
			my $port = $self->internalPortMap->{'mongoc2'};
			$cmdOut = `$sshConnectString mongod --shutdown -f /etc/mongoc2.conf  2>&1`;
			print $dblog "$cmdOut\n";
			if ( $cmdOut =~ /There\sdoesn't\sseem/ ) {

				# Mongod can't be shutdown normally
				print $dblog "mongod configserver2 is still running on $hostname.  Stopping\n";
				$cmdOut = `$sshConnectString kill -9 $pid`;
				print $dblog "$cmdOut\n";
			}
		}
		if ( $line =~ /^\s*(\d+)\s.*mongoc3\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod configserver3 is running on $hostname.  Stopping\n";
			my $port = $self->internalPortMap->{'mongoc3'};
			$cmdOut = `$sshConnectString mongod --shutdown -f /etc/mongoc3.conf  2>&1`;
			print $dblog "$cmdOut\n";
			if ( $cmdOut =~ /There\sdoesn't\sseem/ ) {

				# Mongod can't be shutdown normally
				print $dblog "mongod configserver3 is still running on $hostname.  Stopping\n";
				$cmdOut = `$sshConnectString kill -9 $pid`;
				print $dblog "$cmdOut\n";
			}
		}
	}

	my $dir = $self->getParamValue('mongodbDataDir');
	$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";
	$dir    = $self->getParamValue('mongodbC1DataDir');
	$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";
	$dir    = $self->getParamValue('mongodbC2DataDir');
	$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";
	$dir    = $self->getParamValue('mongodbC3DataDir');
	$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";

	# if this is the first mongodbService then stop the mongos routers
	if ( $appInstance->numShardsProcessed == 1 ) {
		my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
		foreach my $appServer (@$appServersRef) {
			my $appHostname         = $appServer->host->hostName;
			my $appSshConnectString = $appServer->host->sshConnectString;

			print $dblog "Checking whether mongos is running on $appHostname\n";

			# first make sure the mongos is running.  If so, stop it.
			$cmdOut = `$appSshConnectString \"ps x | grep mongo | grep -v grep\"`;
			print $dblog "ps output on $appHostname: $cmdOut\n";
			@lines = split /\n/, $cmdOut;

			foreach my $line (@lines) {

				if ( $line =~ /\s*(\d+)\s.*mongos\.conf/ ) {
					my $pid = $1;
					print $dblog "mongos router is running on $appHostname.  Stopping process $pid\n";
					$cmdOut = `$appSshConnectString kill $pid`;
				}
			}
		}

		# first make sure the mongos is running.  If so, stop it.
		my $dataManagerHostname         = $appInstance->dataManager->host->hostName;
		my $dataManagerSshConnectString = $appInstance->dataManager->host->sshConnectString;
		print $dblog "Checking whether mongos is running on $dataManagerHostname\n";

		$cmdOut = `$dataManagerSshConnectString \"ps x | grep mongo | grep -v grep\"`;
		print $dblog "ps output on $dataManagerHostname: $cmdOut\n";
		@lines = split /\n/, $cmdOut;

		foreach my $line (@lines) {
			if ( $line =~ /\s*(\d+)\s.*mongos\.conf/ ) {
				my $pid = $1;
				print $dblog "mongos router is running on $dataManagerHostname.  Stopping process $pid\n";
				$cmdOut = `$dataManagerSshConnectString kill $pid`;
			}
		}
	}
	close $dblog;

	# If this is the last Mongodb service to be processed,
	# then clear the static variables for the next action
	if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
		$appInstance->clear_numShardsProcessed;
		$appInstance->clear_configDbString;
	}

}

sub stopReplicatedMongodb {

	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("stop ReplicatedMongodbService");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopReplicatedMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::stopReplicatedMongodb\n";

	# first make sure the db is running.  If so, stop it.
	if ( $self->isRunning($dblog) ) {
		print $dblog "mongod is running on $hostname.  Stopping\n";
		my $port = $self->internalPortMap->{'mongod'};
		`$sshConnectString mongod --shutdown -f /etc/mongod.conf`;

		my $cmdOut = `$sshConnectString \"ps x | grep mongo | grep -v grep\"`;
		if ( $cmdOut =~ /^\s*(\d+)\s.*mongod\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod shard is still running on $hostname.  Stopping\n";

			# Mongod can't be shutdown normally
			$cmdOut = `$sshConnectString kill -9 $pid`;
			print $dblog "$cmdOut\n";
		}

	}
	my $dir    = $self->getParamValue('mongodbDataDir');
	my $cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";

	close $dblog;

}

sub stopShardedReplicatedMongodb {

	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopShardedReplicatedMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::stopShardedReplicatedMongodb\n";

	my $cmdOut;
	close $dblog;

}

sub stopSingleMongodb {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("stop SingleMongodbService");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopSingleMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $dblog $self->meta->name . " In MongodbService::stopSingleMongodb\n";

	my $cmdOut;

	# first make sure the db is running.  If so, stop it.
	if ( $self->isRunning($dblog) ) {
		print $dblog "mongod is running on $hostname.  Stopping\n";
		my $port = $self->internalPortMap->{'mongod'};
		`$sshConnectString mongod --shutdown -f /etc/mongod.conf`;

		my $cmdOut = `$sshConnectString \"ps x | grep mongo | grep -v grep\"`;
		if ( $cmdOut =~ /^\s*(\d+)\s.*mongod\.conf/ ) {
			my $pid = $1;
			print $dblog "mongod shard is still running on $hostname.  Stopping\n";

			# Mongod can't be shutdown normally
			$cmdOut = `$sshConnectString kill -9 $pid`;
			print $dblog "$cmdOut\n";
		}

	}
	my $dir = $self->getParamValue('mongodbDataDir');
	$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
	print $dblog "$cmdOut\n";

	close $dblog;
}

sub start {
	my ( $self, $logPath ) = @_;
	my $logger      = get_logger("Weathervane::Services::MongodbService");
	my $appInstance = $self->appInstance;

	$self->portMap->{'mongod'}  = $self->internalPortMap->{'mongod'};
	$self->portMap->{'mongoc1'} = $self->internalPortMap->{'mongoc1'};
	$self->portMap->{'mongoc2'} = $self->internalPortMap->{'mongoc2'};
	$self->portMap->{'mongoc3'} = $self->internalPortMap->{'mongoc3'};
	$self->registerPortsWithHost();

	$logger->debug(
		"Internal mongodb port is ",   $self->internalPortMap->{'mongod'},
		", External mongodb port is ", $self->portMap->{'mongod'}
	);

	if ( ( $appInstance->numNosqlShards > 0 ) && ( $appInstance->numNosqlReplicas > 0 ) ) {
		$self->startShardedReplicatedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlShards > 0 ) {
		$self->startShardedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlReplicas > 0 ) {
		$self->startReplicatedMongodb($logPath);
	}
	else {
		$self->startSingleMongodb($logPath);
	}

	$self->host->startNscd();

}

sub startShardedMongodb {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");

	my $hostname    = $self->host->hostName;
	my $logName     = "$logPath/StartShardedMongodb-$hostname.log";
	my $appInstance = $self->appInstance;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::startShardedMongodb\n";
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	if ( !$self->isRunning($dblog) ) {
		$logger->debug( "MongoDB is not running on $hostname with shardNum "
			  . $self->shardNum
			  . " and replicaNum "
			  . $self->replicaNum );
		my $cmdOut;

		# If this is the first MongoDB service to run,
		# then configure the numShardsProcessed variable
		if ( !$appInstance->has_numShardsProcessed() ) {
			print $dblog "Setting numShardsProcessed to 1.\n";
			$appInstance->numShardsProcessed(1);
		}
		else {
			my $numShardsProcessed = $appInstance->numShardsProcessed;
			print $dblog "Incrementing numShardsProcessed from $numShardsProcessed \n";
			$appInstance->numShardsProcessed( $numShardsProcessed + 1 );
		}

		my $configdbString = "";

		# if this is the first mongodbService then start the config servers
		if ( $appInstance->numShardsProcessed == 1 ) {
			print $dblog "Processing first shard.  Starting config servers\n";
			$logger->debug("Processing first shard on $hostname");

			my $curCfgSvr = 1;
			while ( $curCfgSvr <= $self->numConfigServers ) {
				my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

				foreach my $nosqlServer (@$nosqlServersRef) {
					my $configPort = $self->portMap->{"mongoc$curCfgSvr"};

					my $mongoHostname    = $nosqlServer->host->hostName;
					my $sshConnectString = $nosqlServer->host->sshConnectString;

					# Start a config server on this host
					print $dblog "Starting configserver$curCfgSvr on $mongoHostname\n";
					$logger->debug("Starting configserver$curCfgSvr on $mongoHostname");
					$cmdOut = `$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf 2>&1`;
					print $dblog "$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf 2>&1\n";
					print $dblog $cmdOut;
					if ( !( $cmdOut =~ /success/ ) ) {
						die "Couldn't start configserver$curCfgSvr on $mongoHostname : $cmdOut\n";
					}
					if ( $configdbString ne "" ) {
						$configdbString .= ",";
					}
					$configdbString .= "$mongoHostname:$configPort";
					$curCfgSvr++;
					if ( $curCfgSvr > $self->numConfigServers ) {
						last;
					}
				}
			}

			$appInstance->configDbString($configdbString);
		}

		# start the shard on this host
		print $dblog "Starting mongod on $hostname\n";
		$logger->debug("Starting mongodb shard on $hostname");
		my $sshConnectString = $self->host->sshConnectString;

		$cmdOut = `$sshConnectString mongod -f /etc/mongod.conf 2>&1`;
		print $dblog "$sshConnectString mongod -f /etc/mongod.conf 2>&1\n";
		print $dblog $cmdOut;
		if ( !( $cmdOut =~ /success/ ) ) {
			print $dblog "Couldn't start mongod on $hostname : $cmdOut\n";
			die "Couldn't start mongod on $hostname : $cmdOut\n";
		}

		# If this is the last mongoService, start the mongos instances on the
		# app servers and primary driver.  Don't start multiple mongos on the same
		# host if multiple app served are running on the same host
		if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
			$logger->debug("Processing last shard on $hostname");

			$configdbString = $appInstance->configDbString;
			my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');

			my %hostsMongosStarted;

			foreach my $appServer (@$appServersRef) {
				my $appHostname = $appServer->host->hostName;
				my $appIpAddr   = $appServer->host->ipAddr;
				$appServer->internalPortMap->{'mongos'} = $self->internalPortMap->{ 'mongos-' . $appIpAddr };

				if ( exists $hostsMongosStarted{$appIpAddr} ) {

					# If a mongos has already been started on this host,
					# Don't start another one
					$logger->debug("A mongos is already started on $appHostname.  Not starting another");
					next;
				}

				$hostsMongosStarted{$appIpAddr} = 1;

				# Copy config files to app servers
				my $appSshConnectString = $appServer->host->sshConnectString;

				print $dblog "Starting mongos on app server host $appHostname\n";
				$logger->debug("Starting mongos on app server host $appHostname");
				print $dblog "$appSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1\n";
				$cmdOut = `$appSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1`;
				print $dblog $cmdOut;
				if ( !( $cmdOut =~ /success/ ) ) {
					print $dblog "Couldn't start mongos on $appHostname : $cmdOut\n";
					die "Couldn't start mongos on $appHostname : $cmdOut\n";
				}
			}

			# start a mongos on the dataManager
			my $dataManagerDriver   = $self->appInstance->dataManager;
			my $dataManagerHostname = $dataManagerDriver->host->hostName;
			my $dataManagerIpAddr   = $dataManagerDriver->host->ipAddr;
			my $localMongosPort     = $dataManagerDriver->portMap->{'mongos'} =
			  $self->internalPortMap->{"mongos-$dataManagerIpAddr"};
			my $dataManagerSshConnectString = $dataManagerDriver->host->sshConnectString;

			if ( !exists $hostsMongosStarted{$dataManagerIpAddr} ) {

				print $dblog "Starting mongos on $dataManagerHostname\n";
				$logger->debug("Starting mongos on dataManager host $dataManagerHostname");
				print $dblog
				  "$dataManagerSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1\n";
				$cmdOut = `$dataManagerSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1`;
				print $dblog $cmdOut;

				if ( !( $cmdOut =~ /success/ ) ) {
					print $dblog "Couldn't start mongos on $dataManagerHostname : $cmdOut\n";
					die "Couldn't start mongos on $dataManagerHostname : $cmdOut\n";
				}
			}

			# disable the balancer
			print $dblog "Disabling the balancer.\n";
			my $cmdString = "mongo --port $localMongosPort --eval 'sh.setBalancerState(false)'";
			$cmdOut = `$dataManagerSshConnectString "$cmdString"`;
			print $dblog "$dataManagerSshConnectString \"$cmdString\"\n";
			print $dblog $cmdOut;

			# If this is the last Mongodb service to be processed,
			# then clear the static variables for the next action
			$appInstance->clear_numShardsProcessed;
			$appInstance->clear_configDbString;
		}

		close $dblog;

	}
}

sub startReplicatedMongodb {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartReplicatedMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	my $replicaName      = "auction" . $self->shardNum;
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::startReplicatedMongodb\n";

	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	my $cmdOut;
	if ( !$self->isRunning($dblog) ) {

		# start the DB
		print $dblog "Starting mongod on $hostname\n";
		$cmdOut = `$sshConnectString mongod -f /etc/mongod.conf --replSet=$replicaName`;
		if ( !( $cmdOut =~ /success/ ) ) {
			print $dblog "Couldn't start mongod on $hostname : $cmdOut\n";
			die "Couldn't start mongod on $hostname : $cmdOut\n";
		}
	}
	close $dblog;
}

sub startShardedReplicatedMongodb {
	my ( $self, $logPath ) = @_;

	my $hostname = $self->host->hostName;
	my $logName  = "$logPath/StartShardedReplicatedMongodb-$hostname.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::startShardedReplicatedMongodb\n";
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	die "Need to implement startShardedReplicatedMongodb";

	close $dblog;
}

sub startSingleMongodb {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartSingleMongodb-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $dblog $self->meta->name . " In MongodbService::startSingleMongodb\n";
	my $cmdOut;
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	if ( !$self->isRunning($dblog) ) {

		# start the DB
		print $dblog "Starting mongod on $hostname\n";
		$cmdOut = `$sshConnectString mongod -f /etc/mongod.conf 2>&1`;
		if ( !( $cmdOut =~ /success/ ) ) {
			print $dblog "Couldn't start mongod on $hostname : $cmdOut\n";
			die "Couldn't start mongod on $hostname : $cmdOut\n";
		}
	}
	close $dblog;

}

sub clearDataAfterStart {
}

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/MongoDB-clearData-$hostname.log";
	my $mongodbDataDir   = $self->getParamValue('mongodbDataDir');
	my $mongodbC1DataDir = $self->getParamValue('mongodbC1DataDir');
	my $mongodbC2DataDir = $self->getParamValue('mongodbC2DataDir');
	my $mongodbC3DataDir = $self->getParamValue('mongodbC3DataDir');

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";

	my $sshConnectString = $self->host->sshConnectString;
	print $applog "Clearing old MongoDB data on " . $hostname . "\n";

	my $cmdout = `$sshConnectString \"find $mongodbDataDir/* -delete 2>&1\"`;
	print $applog $cmdout;
	$cmdout = `$sshConnectString \"ls -l $mongodbDataDir 2>&1\"`;
	print $applog "After clearing, MongoDB data dir has: $cmdout";

	$cmdout = `$sshConnectString \"find $mongodbC1DataDir/* -delete 2>&1\"`;
	print $applog $cmdout;
	$cmdout = `$sshConnectString \"ls -l $mongodbC1DataDir 2>&1\"`;
	print $applog "After clearing, $mongodbC1DataDir has: $cmdout";

	$cmdout = `$sshConnectString \"find $mongodbC2DataDir/* -delete 2>&1\"`;
	print $applog $cmdout;
	$cmdout = `$sshConnectString \"ls -l $mongodbC2DataDir 2>&1\"`;
	print $applog "After clearing, $mongodbC2DataDir has: $cmdout";

	$cmdout = `$sshConnectString \"find $mongodbC3DataDir/* -delete 2>&1\"`;
	print $applog $cmdout;
	$cmdout = `$sshConnectString \"ls -l $mongodbC3DataDir 2>&1\"`;
	print $applog "After clearing, $mongodbC3DataDir has: $cmdout";

	close $applog;

}

sub isUp {
	my ( $self, $fileout ) = @_;

	if ( !$self->isRunning($fileout) ) {
		return 0;
	}

	return 1;

}

sub isRunning {
	my ( $self, $fileout ) = @_;

	my $sshConnectString = $self->host->sshConnectString;

	my $cmdOut = `$sshConnectString \"ps x | grep mongo | grep -v grep\"`;
	print $fileout $cmdOut;
	if ( $cmdOut =~ /mongod\.conf/ ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub setPortNumbers {
	my ($self)          = @_;
	my $appInstance     = $self->appInstance;
	my $numNosqlServers = $appInstance->getNumActiveOfServiceType('nosqlServer');
	my $numShards       = $appInstance->numNosqlShards;
	my $numReplicas     = $appInstance->numNosqlReplicas;
	my $serviceType     = $self->getParamValue('serviceType');
	my $portMultiplier  = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset      = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	my $instanceNumber = $self->getParamValue('instanceNum');
	$self->internalPortMap->{'mongod'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongos'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongoc1'} = 27019;
	$self->internalPortMap->{'mongoc2'} = 27020;
	$self->internalPortMap->{'mongoc3'} = 27021;
	if ( ( $numShards > 0 ) && ( $numReplicas > 0 ) ) {
		$self->shardNum( ceil( $instanceNumber / ( 1.0 * $appInstance->numNosqlReplicas ) ) );
		$self->replicaNum( ( $instanceNumber % $appInstance->numNosqlReplicas ) + 1 );
		$self->internalPortMap->{'mongod'} = 27018 + $portOffset;
	}
	elsif ( $numShards > 0 ) {
		$self->shardNum($instanceNumber);
		$self->internalPortMap->{'mongod'} = 27018 + $portOffset;
	}
	elsif ( $numReplicas > 0 ) {
		$self->replicaNum($instanceNumber);
	}
	elsif ( $numNosqlServers > 1 ) {
		die "When not using sharding or replicas, the number of NoSQL servers must equal 1.";
	}
}

sub setExternalPortNumbers {
	my ($self)          = @_;
	$self->portMap->{'mongod'}  = $self->internalPortMap->{'mongod'};
	$self->portMap->{'mongoc1'} = $self->internalPortMap->{'mongoc1'};
	$self->portMap->{'mongoc2'} = $self->internalPortMap->{'mongoc2'};
	$self->portMap->{'mongoc3'} = $self->internalPortMap->{'mongoc3'};
}

override 'sanityCheck' => sub {
	my ($self, $cleanupLogDir) = @_;
	my $console_logger = get_logger("Console");
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $logName          = "$cleanupLogDir/SanityCheckMongoDB-$hostname.log";
	my $dir = $self->getParamValue('mongodbDataDir');

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my $cmdString = "$sshConnectString df -h $dir";
	my $cmdout = `$cmdString`;
	print $dblog "$cmdString\n";
	print $dblog "$cmdout\n";

	close $dblog;

	if ($cmdout =~ /100\%/) {
		$console_logger->error("Failed Sanity Check: MongoDB Data Directory $dir is full on $hostname.");
		return 0;
	} else {
		return 1;
	}
	
};

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("Configure mongodb");

	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/ConfigureMongodb-$hostname.log";
	my $appInstance      = $self->appInstance;

	my $numNosqlServers = $appInstance->getNumActiveOfServiceType('nosqlServer');
	my $numShards       = $appInstance->numNosqlShards;
	my $numReplicas     = $appInstance->numNosqlReplicas;
	my $serviceType     = $self->getParamValue('serviceType');
	my $portMultiplier  = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset      = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $dblog $self->meta->name . " In MongodbService::ConfigureMongodb\n";

	my $dir = $self->getParamValue('mongodbDataDir');
	`$sshConnectString mkdir -p $dir`;
	$dir = $self->getParamValue('mongodbC1DataDir');
	`$sshConnectString mkdir -p $dir`;
	$dir = $self->getParamValue('mongodbC2DataDir');
	`$sshConnectString mkdir -p $dir`;
	$dir = $self->getParamValue('mongodbC3DataDir');
	`$sshConnectString mkdir -p $dir`;

	if ( $self->getParamValue('mongodbUseTHP') ) {
		my $cmdOut = `$sshConnectString \"echo always > /sys/kernel/mm/transparent_hugepage/enabled\"`;
		$cmdOut = `$sshConnectString \"echo always > /sys/kernel/mm/transparent_hugepage/defrag\"`;
	}
	else {

		# Turn off transparent huge pages
		my $cmdOut = `$sshConnectString \"echo never > /sys/kernel/mm/transparent_hugepage/enabled\"`;
		$cmdOut = `$sshConnectString \"echo never > /sys/kernel/mm/transparent_hugepage/defrag\"`;
	}

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');

	if ( ( $numShards > 0 ) && ( $appInstance->numNosqlReplicas > 0 ) ) {
		open( FILEIN, "$configDir/mongodb/mongod-shardReplica.conf" )
		  or die "Error opening $configDir/mongodb/mongod-shardReplica.conf:$!";
		open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongod'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbDataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
	}

	if ( ( $numShards > 0 ) && ( $appInstance->numNosqlReplicas == 0 ) ) {
		open( FILEIN, "$configDir/mongodb/mongod-sharded.conf" )
		  or die "Error opening $configDir/mongodb/mongod-sharded.conf:$!";
		open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongod'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbDataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
	}

	if ( ( $numShards == 0 ) && ( $appInstance->numNosqlReplicas > 0 ) ) {
		open( FILEIN, "$configDir/mongodb/mongod-replica.conf" )
		  or die "Error opening $configDir/mongodb/mongod-replica.conf:$!";
		open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongod'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbDataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
	}

	if ( ( $numShards == 0 ) && ( $appInstance->numNosqlReplicas == 0 ) ) {
		open( FILEIN, "$configDir/mongodb/mongod-unsharded.conf" )
		  or die "Error opening $configDir/mongodb/mongod-unsharded.conf:$!";
		open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongod'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbDataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
	}

	if ( $numShards > 0 ) {

		# If this is the first MongoDB service to be configured,
		# then configure the numShardsProcessed variable
		if ( !$appInstance->has_numShardsProcessed() ) {
			print $dblog "Setting numShardsProcessed to 1\n";
			$appInstance->numShardsProcessed(1);
		}
		else {
			print $dblog "Incrementing numShardsProcessed from " . $appInstance->numShardsProcessed . "\n";
			$appInstance->numShardsProcessed( $appInstance->numShardsProcessed + 1 );
		}

		open( FILEIN, "$configDir/mongodb/mongoc1.conf" )
		  or die "Error opening $configDir/mongodb/mongod-mongoc1.conf:$!";
		open( FILEOUT, ">/tmp/mongoc1$suffix.conf" ) or die "Error opening /tmp/mongoc1$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongoc1'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbC1DataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongoc1$suffix.conf root\@$scpHostString:/etc/mongoc1.conf`;

		open( FILEIN, "$configDir/mongodb/mongoc2.conf" )
		  or die "Error opening $configDir/mongodb/mongod-mongoc2.conf:$!";
		open( FILEOUT, ">/tmp/mongoc2$suffix.conf" ) or die "Error opening /tmp/mongoc2$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongoc2'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbC2DataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongoc2$suffix.conf root\@$scpHostString:/etc/mongoc2.conf`;

		open( FILEIN, "$configDir/mongodb/mongoc3.conf" )
		  or die "Error opening $configDir/mongodb/mongod-mongoc3.conf:$!";
		open( FILEOUT, ">/tmp/mongoc3$suffix.conf" ) or die "Error opening /tmp/mongoc3$suffix.conf:$!";
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /port:/ ) {
				print FILEOUT "    port: " . $self->internalPortMap->{'mongoc3'} . "\n";
			}
			elsif ( $inline =~ /dbPath:/ ) {
				print FILEOUT "    dbPath: \"" . $self->getParamValue('mongodbC3DataDir') . "\"\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/mongoc3$suffix.conf root\@$scpHostString:/etc/mongoc3.conf`;

		# If this is the last Mongodb service to be processed,
		# then configure the mongos processes
		if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
			print $dblog "numShardsProcessed = numNosqlShards\n";
			my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
			my $numMongos     = 0;
			my %hostsMongosConfigured;
			foreach my $appServer (@$appServersRef) {
				my $appHostname = $appServer->host->hostName;
				my $appIpAddr   = $appServer->host->ipAddr;
				if ( exists $hostsMongosConfigured{$appIpAddr} ) {

					# If a mongos has already been configures on this host,
					# Don't configure another one
					next;
				}

				$hostsMongosConfigured{$appIpAddr} = 1;

				# Copy config files to app servers

				my $mongosPort =
				  $self->internalPortMap->{'mongos'} +
				  ( $self->getParamValue( $self->getParamValue('serviceType') . 'PortStep' ) * $numMongos );
				$numMongos++;

				# Save the mongos port for this hostname in the internalPortMap
				$self->internalPortMap->{ 'mongos-' . $appIpAddr } = $mongosPort;

				$scpConnectString = $appServer->host->scpConnectString;
				$scpHostString    = $appServer->host->scpHostString;
				open( FILEIN,  "$configDir/mongodb/mongos.conf" );
				open( FILEOUT, ">/tmp/mongos$suffix.conf" );
				while ( my $inline = <FILEIN> ) {
					if ( $inline =~ /port:/ ) {
						print FILEOUT "    port: " . $mongosPort . "\n";
					}
					else {
						print FILEOUT $inline;
					}
				}
				close FILEIN;
				close FILEOUT;
				`$scpConnectString /tmp/mongos$suffix.conf root\@$scpHostString:/etc/mongos.conf`;

			}

			# configure a mongos on the workload driver
			my $dataManagerDriver   = $self->appInstance->dataManager;
			my $dataManagerIpAddr   = $dataManagerDriver->host->ipAddr;
			my $dataManagerHostname = $dataManagerDriver->host->hostName;
			if ( !exists $hostsMongosConfigured{$dataManagerIpAddr} ) {
				my $mongosPort =
				  $self->internalPortMap->{'mongos'} +
				  ( $self->getParamValue( $self->getParamValue('serviceType') . 'PortStep' ) * $numMongos );
				$numMongos++;

				# Save the mongos port for this hostname in the internalPortMap
				$self->internalPortMap->{ 'mongos-' . $dataManagerIpAddr } = $mongosPort;
				$scpConnectString                                          = $dataManagerDriver->host->scpConnectString;
				$scpHostString                                             = $dataManagerDriver->host->scpHostString;
				open( FILEIN,  "$configDir/mongodb/mongos.conf" );
				open( FILEOUT, ">/tmp/mongos$suffix.conf" );
				while ( my $inline = <FILEIN> ) {
					if ( $inline =~ /port:/ ) {
						print FILEOUT "    port: " . $mongosPort . "\n";
					}
					else {
						print FILEOUT $inline;
					}
				}
				close FILEIN;
				close FILEOUT;
				`$scpConnectString /tmp/mongos$suffix.conf root\@$scpHostString:/etc/mongos.conf`;

			}

			$appInstance->clear_numShardsProcessed;
			$appInstance->clear_configDbString;
		}
	}

	close $dblog;

}

sub stopStatsCollection {
	my ($self) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $port             = $self->internalPortMap->{'mongod'};
	my $logger = get_logger("Weathervane::Services::MongodbService");

	my $pid = fork();
	if ( $pid == 0 ) {
		$logger->debug("Starting mongostat on $hostname, numInetervals = ", $numIntervals,", intervalLengthSec = ", $intervalLengthSec);
		my $out = `$sshConnectString \"mongostat --port $port -n $numIntervals $intervalLengthSec > /tmp/mongostat_${hostname}.txt\"`;
		$logger->debug("mongostat ran on $hostname, result : ",$out);
		exit;
	}

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;

	my $out = `$scpConnectString root\@$scpHostString:/tmp/mongostat_${hostname}.txt $destinationPath/. 2>&1`;
	$logger->debug("Collecting mongostat output on $hostname, result : ",$out);

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString \"rm -f /tmp/mongostat_${hostname}.txt 2>&1\"`;
	$logger->debug("Cleaning mongostat output on $hostname, result : ",$out);

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $maxLogLines = $self->getParamValue('maxLogLines');
	$self->checkSizeAndTruncate("/var/log/mongodb", "mongod.log", $maxLogLines);
	$self->checkSizeAndTruncate("/var/log/mongodb", "mongos.log", $maxLogLines);
	$self->checkSizeAndTruncate("/var/log/mongodb", "mongoc1.log", $maxLogLines);
	$self->checkSizeAndTruncate("/var/log/mongodb", "mongoc2.log", $maxLogLines);
	$self->checkSizeAndTruncate("/var/log/mongodb", "mongoc3.log", $maxLogLines);

	my $out              = `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongod.log $destinationPath/.  2>&1`;
   	$out              = `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongos.log $destinationPath/.  2>&1`;
    $out              = `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongoc1.log $destinationPath/.  2>&1`;
    $out              = `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongoc2.log $destinationPath/.  2>&1`;
    $out              = `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongoc3.log $destinationPath/.  2>&1`;

	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		$scpConnectString = $appServer->host->scpConnectString;
		$scpHostString    = $appServer->host->scpHostString;
		my $hostname = $appServer->host->hostName;
		$appServer->checkSizeAndTruncate("/var/log/mongodb", "mongos.log", $maxLogLines);

		$out =
`$scpConnectString root\@$scpHostString:/var/log/mongodb/mongos.log $destinationPath/mongos_$hostname.log 2>&1`;
	}

	my $dataManager = $self->appInstance->dataManager;
	$scpConnectString = $dataManager->host->scpConnectString;
	$scpHostString    = $dataManager->host->scpHostString;
	my $hostname = $dataManager->host->hostName;
	$out =
	  `$scpConnectString root\@$scpHostString:/var/log/mongodb/mongos.log $destinationPath/mongos_$hostname.log 2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("cleanLogFiles");

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString \"rm -f /var/log/mongodb/* 2>&1\"`;

	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		$sshConnectString = $appServer->host->sshConnectString;
		if (!$appServer->useDocker()) {
			$out              = `$sshConnectString \"rm -f /var/log/mongodb/* 2>&1\"`;
		}
	}

	my $dataManager = $self->appInstance->dataManager;
	$sshConnectString = $dataManager->host->sshConnectString;
	$out              = `$sshConnectString \"rm -f /var/log/mongodb/* 2>&1\"`;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:/etc/mongo*.conf $destinationPath/.`;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	my $appInstance = $self->appInstance;

	$csv{"numNosqlShards"}   = $appInstance->numNosqlShards;
	$csv{"numNosqlReplicas"} = $appInstance->numNosqlReplicas;

	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

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
package MongodbDockerService;

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

has '+version' => ( default => '2.6.x', );

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
# to be used in sharded mode. MongoDB requires
# this to be 3, but we don't want to hard-code
# the number in case it changes someday.
has 'numConfigServers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 3,
);

has 'configServersRef' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

has 'clearBeforeStart' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

override 'initialize' => sub {
	my ( $self, $numNosqlServers ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
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

override 'create' => sub {
	my ( $self, $logPath ) = @_;
	my $appInstance = $self->appInstance;

	if ( ( $appInstance->numNosqlShards > 0 ) && ( $appInstance->numNosqlReplicas > 0 ) ) {
		$self->createShardedReplicatedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlShards > 0 ) {
		$self->createShardedMongodb($logPath);
	}
	elsif ( $appInstance->numNosqlReplicas > 0 ) {
		$self->createReplicatedMongodb($logPath);
	}
	else {
		$self->createSingleMongodb($logPath);
	}
	
	$self->clearBeforeStart(0);
};

sub createSingleMongodb {
	my ( $self, $logPath ) = @_;
	my $name     = $self->getParamValue('dockerName');
	my $host = $self->host;
	my $hostname = $self->host->hostName;
	my $impl     = $self->getImpl();

	my $time = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/CreateSingleMongodbDocker-$hostname-$name-$time.log";
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my %volumeMap;
	my $dataDir = $self->getParamValue('mongodbDataDir');
	if ($host->getParamValue('dockerHostUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$dataDir = $self->getParamValue('mongodbDataVolume');
		# use named volumes.  Create volume if it doesn't exist
		if (!$host->dockerVolumeExists($dblog, $dataDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('mongodbDataVolumeSize');
			}
			$host->dockerVolumeCreate($dblog, $dataDir, $volumeSize);
		}
	}
	$volumeMap{"/mnt/mongoData"} = $dataDir;

	my %envVarMap;
	$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
	$envVarMap{"NUMSHARDS"} = $self->appInstance->numNosqlShards;
	$envVarMap{"NUMREPLICAS"} = $self->appInstance->numNosqlReplicas;
	$envVarMap{"ISCFGSVR"} = 0;
	$envVarMap{"ISMONGOS"} = 0;
	
	if ($self->clearBeforeStart) {
		$envVarMap{"CLEARBEFORESTART"} = 1;		
	} else {
		$envVarMap{"CLEARBEFORESTART"} = 0;		
	}
		
	my %portMap;
	my $directMap = 0;

	# when creating single only need to expose the mongod port 
	my $port = $self->internalPortMap->{'mongod'};
	$portMap{$port} = $port;

	my $entrypoint;
	my $cmd = "mongod -f /etc/mongod.conf";

	# Create the container
	$self->host->dockerRun( $dblog, $name, $impl, $directMap, \%portMap, \%volumeMap, \%envVarMap,
		$self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

	$self->setExternalPortNumbers();

	close $dblog;
}

sub createShardedMongodb {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");

	my $hostname = $self->host->hostName;
	my $host = $self->host;
	my $name     = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/CreateShardedMongodb-$hostname-$name-$time.log";
	my $impl        = $self->getImpl();
	my $appInstance = $self->appInstance;

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::CreateShardedMongodb\n";
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";
	my $cmdOut;

	$logger->debug( "CreateShardedMongodb for $name: ",
		"$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum );

	# If this is the first MongoDB service to run,
	# then configure the numShardsProcessed variable
	if ( !$appInstance->has_numShardsProcessed() ) {
		print $dblog "Setting numShardsProcessed to 1.\n";
		$logger->debug("Setting numShardsProcessed to 1.");
		$appInstance->numShardsProcessed(1);
	}
	else {
		my $numShardsProcessed = $appInstance->numShardsProcessed;
		print $dblog "Incrementing numShardsProcessed from $numShardsProcessed \n";
		$logger->debug("Incrementing numShardsProcessed from $numShardsProcessed");
		$appInstance->numShardsProcessed( $numShardsProcessed + 1 );
	}

	# if this is the first mongodbService then create the config servers
	if ( $appInstance->numShardsProcessed == 1 ) {
		print $dblog "Processing first shard.  Creating config servers\n";
		$logger->debug("Processing first shard.  Creating config servers");
		my $wkldNum    = $self->getWorkloadNum();
		my $appInstNum = $self->getAppInstanceNum();
		$self->configServersRef([]);
		my $curCfgSvr  = 1;
		while ( $curCfgSvr <= $self->numConfigServers ) {
			my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

			foreach my $nosqlServer (@$nosqlServersRef) {

				$logger->debug( "Creating config server $curCfgSvr on ", $nosqlServer->host->hostName );
				print $dblog "Creating config server $curCfgSvr on " . $nosqlServer->host->hostName . "\n";
				
				my %volumeMap;
				my $dataDir = $self->getParamValue("mongodbC${curCfgSvr}DataDir");
				if ($host->getParamValue('dockerHostUseNamedVolumes') || $host->getParamValue('vicHost')) {
					$dataDir = $self->getParamValue("mongodbC${curCfgSvr}DataVolume");
					# use named volumes.  Create volume if it doesn't exist
					if (!$host->dockerVolumeExists($dblog, $dataDir)) {
						# Create the volume
						my $volumeSize = 0;
						if ($host->getParamValue('vicHost')) {
							$volumeSize = $self->getParamValue("mongodbC${curCfgSvr}DataVolumeSize");
						}
						$host->dockerVolumeCreate($dblog, $dataDir, $volumeSize);
					}
				}
				$volumeMap{"/mnt/mongoC${curCfgSvr}data"} = $dataDir;

				my %envVarMap;
				$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
				$envVarMap{"MONGOCPORT"} = $self->internalPortMap->{'mongoc'.$curCfgSvr};
				$envVarMap{"CFGSVRNUM"} = $curCfgSvr;
				$envVarMap{"NUMSHARDS"} = $appInstance->numNosqlShards;
				$envVarMap{"NUMREPLICAS"} = $appInstance->numNosqlReplicas;
				$envVarMap{"ISCFGSVR"} = 1;
	  			$envVarMap{"ISMONGOS"} = 0;
				if ($self->clearBeforeStart) {
					$envVarMap{"CLEARBEFORESTART"} = 1;		
				} else {
					$envVarMap{"CLEARBEFORESTART"} = 0;		
				}
				
				my %portMap;
				my $directMap = 1;

				# Only need to expose the mongoc port
				my $configPort = $self->internalPortMap->{"mongoc$curCfgSvr"};
				$portMap{$configPort} = $configPort;
				my $entrypoint;
				my $cmd = "mongod -f /etc/mongoc$curCfgSvr.conf";

				my $host = $nosqlServer->host;

				# Create the container
				$host->dockerRun( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}",
					$impl, $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef, $entrypoint,
					$cmd, $self->needsTty );

				my $configServersRef = $self->configServersRef;
				push @$configServersRef, $nosqlServer;
				$curCfgSvr++;
				if ( $curCfgSvr > $self->numConfigServers ) {
					$logger->debug( "curCfgServer ($curCfgSvr) > self->numConfigServers (",
						$self->numConfigServers, ")" );
					last;
				}
			}
		}
	}

	# create the shard on this host
	print $dblog "Creating mongod on $hostname\n";
	$logger->debug("Creating mongod for $name on $hostname");
	my %volumeMap;
	my $dataDir = $self->getParamValue('mongodbDataDir');
	if ($host->getParamValue('dockerHostUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$dataDir = $self->getParamValue('mongodbDataVolume');
		# use named volumes.  Create volume if it doesn't exist
		if (!$host->dockerVolumeExists($dblog, $dataDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('mongodbDataVolumeSize');
			}
			$host->dockerVolumeCreate($dblog, $dataDir, $volumeSize);
		}
	}
	$volumeMap{"/mnt/mongoData"} = $dataDir;

	my %envVarMap;
	$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
	$envVarMap{"NUMSHARDS"} = $appInstance->numNosqlShards;
	$envVarMap{"NUMREPLICAS"} = $appInstance->numNosqlReplicas;
	$envVarMap{"ISCFGSVR"} = 0;
	$envVarMap{"ISMONGOS"} = 0;
	if ($self->clearBeforeStart) {
		$envVarMap{"CLEARBEFORESTART"} = 1;		
	} else {
		$envVarMap{"CLEARBEFORESTART"} = 0;		
	}
	
	my %portMap;
	my $directMap = 1;

	# Only need to expose the mongod port when creating the mongod
	my $port = $self->internalPortMap->{'mongod'};
	$portMap{$port} = $port;

	my $entrypoint;
	my $cmd = "mongod -f /etc/mongod.conf";

	# Create the container
	$self->host->dockerRun( $dblog, $name, $impl, $directMap, \%portMap, \%volumeMap, \%envVarMap,
		$self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

	if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
		$logger->debug("Clearing numShardsProcessed and configDbString");

		# If this is the last Mongodb service to be processed,
		# then clear the static variables for the next action
		$appInstance->clear_numShardsProcessed;
		$appInstance->clear_configDbString;
	}

	$self->setExternalPortNumbers();

	close $dblog;

}

sub createReplicatedMongodb {
	my ( $self, $logPath ) = @_;
	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $host = $self->host;
	my $impl     = $self->getImpl();
	my $replicaName      = "auction" . $self->shardNum;

	my $time = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/CreateReplicatedMongodbDocker-$hostname-$name-$time.log";
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my %volumeMap;
	my $dataDir = $self->getParamValue('mongodbDataDir');
	if ($host->getParamValue('dockerHostUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$dataDir = $self->getParamValue('mongodbDataVolume');
		# use named volumes.  Create volume if it doesn't exist
		if (!$host->dockerVolumeExists($dblog, $dataDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('mongodbDataVolumeSize');
			}
			$host->dockerVolumeCreate($dblog, $dataDir, $volumeSize);
		}
	}
	$volumeMap{"/mnt/mongoData"} = $dataDir;

	my %envVarMap;
	$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
	$envVarMap{"NUMSHARDS"} = $self->appInstance->numNosqlShards;
	$envVarMap{"NUMREPLICAS"} = $self->appInstance->numNosqlReplicas;
	$envVarMap{"ISCFGSVR"} = 0;
	$envVarMap{"ISMONGOS"} = 0;
	if ($self->clearBeforeStart) {
		$envVarMap{"CLEARBEFORESTART"} = 1;		
	} else {
		$envVarMap{"CLEARBEFORESTART"} = 0;		
	}
	
	my %portMap;
	my $directMap = 1;

	# when creating single only need to expose the mongod port 
	my $port = $self->internalPortMap->{'mongod'};
	$portMap{$port} = $port;

	my $entrypoint;
	my $cmd = "mongod -f /etc/mongod.conf --replSet=$replicaName";

	# Create the container
	$self->host->dockerRun( $dblog, $name, $impl, $directMap, \%portMap, \%volumeMap, \%envVarMap,
		$self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

	$self->setExternalPortNumbers();

	close $dblog;
}

sub createShardedReplicatedMongodb {
	my $console_logger = get_logger("Console");
	$console_logger->error("Dockerized sharded and replicated MongoDB is not yet implemented.");
	exit(-1);

}

sub setPortNumbers {
	my ($self) = @_;

	my $appInstance     = $self->appInstance;
	my $numNosqlServers = $appInstance->getNumActiveOfServiceType('nosqlServer');
	my $numShards       = $appInstance->numNosqlShards;
	my $numReplicas     = $appInstance->numNosqlReplicas;

	my $serviceType    = $self->getParamValue('serviceType');
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	my $instanceNumber = $self->getParamValue('instanceNum');
	$self->internalPortMap->{'mongod'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongos'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongoc1'} = 27019;
	$self->internalPortMap->{'mongoc2'} = 27020;
	$self->internalPortMap->{'mongoc3'} = 27021;
	if ( ( $numShards > 0 ) && ( $numReplicas > 0 ) ) {
		$self->shardNum( ceil( $instanceNumber / ( 1.0 * $numReplicas ) ) );
		$self->replicaNum( ( $instanceNumber % $numReplicas ) + 1 );
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
	my ($self) = @_;
	my $name = $self->getParamValue('dockerName');
	my $portMapRef = $self->host->dockerPort($name );

	if ( $self->getParamValue('dockerNet') eq "host" ) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{'mongod'} = $self->internalPortMap->{'mongod'};
		$self->portMap->{'mongoc1'} = $self->internalPortMap->{'mongoc1'};
		$self->portMap->{'mongoc2'} = $self->internalPortMap->{'mongoc2'};
		$self->portMap->{'mongoc3'} = $self->internalPortMap->{'mongoc3'};
	}
	else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{'mongod'} = $portMapRef->{ $self->internalPortMap->{'mongod'} };
		if ((exists $portMapRef->{ $self->internalPortMap->{'mongoc1'} }) 
				&& (defined $portMapRef->{ $self->internalPortMap->{'mongoc1'} } )) {
			$self->portMap->{'mongoc1'} = $portMapRef->{ $self->internalPortMap->{'mongoc1'} };
		}
		if ((exists $portMapRef->{ $self->internalPortMap->{'mongoc2'} }) 
				&& (defined $portMapRef->{ $self->internalPortMap->{'mongoc2'} } )) {
			$self->portMap->{'mongoc2'} = $portMapRef->{ $self->internalPortMap->{'mongoc2'} };
		}
		if ((exists $portMapRef->{ $self->internalPortMap->{'mongoc3'} }) 
				&& (defined $portMapRef->{ $self->internalPortMap->{'mongoc3'} } )) {
			$self->portMap->{'mongoc3'} = $portMapRef->{ $self->internalPortMap->{'mongoc3'} };
		}
	}

}

override 'sanityCheck' => sub {
	my ($self, $cleanupLogDir) = @_;
	my $console_logger = get_logger("Console");
	my $hostname         = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $logName          = "$cleanupLogDir/SanityCheckMongoDB-$hostname-$name.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	$self->host->dockerKill("USR2", $dblog, $name);
	
	my $logContents = $self->host->dockerGetLogs( $dblog, $name );
	my @lines = split /\n/, $logContents;
	
	foreach my $inline (@lines) {
		if ($inline =~ /Sanity\sChecks\sPassed/) {
			close $dblog;
			return 1;
		} elsif ($inline =~ /Sanity\sChecks\sFailed/) {
			$console_logger->error("Failed Sanity Check: MongoDB Data Directory is full on $hostname.");
			close $dblog;
			return 0;
		} 
	}
	close $dblog;

	$console_logger->error("Failed Sanity Check: Did not find sanity check results.");
	return 0;
};

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;

}

sub start {
	my ( $self, $logPath ) = @_;
	my $appInstance = $self->appInstance;

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

	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $configDir   = $self->getParamValue('configDir');
	my $appInstance = $self->appInstance;
	my $logger      = get_logger("Weathervane::Services::MongodbDockerService");

	my $time = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StartShardedMongodb-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::startShardedMongodbDocker\n";
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

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

		# Configure the config servers
		my $configPort;
		my $configServersRef = $self->configServersRef;
		my $curCfgSvr        = 1;
		my $wkldNum          = $self->getWorkloadNum();
		my $appInstNum       = $self->getAppInstanceNum();
		foreach my $configServer (@$configServersRef) {
			my $configServerHost = $configServer->host;
			$logger->debug( "Getting ports for config server $curCfgSvr on host ", $configServerHost->hostName, 
				", dockerName = ", "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}");
			my $portMapRef = $configServer->host->dockerPort("mongoc$curCfgSvr-W${wkldNum}I${appInstNum}");
			$logger->debug("Keys from docker port of mongoc$curCfgSvr-W${wkldNum}I${appInstNum} = ", keys %$portMapRef);
			if ( $self->getParamValue('dockerNet') eq "host" ) {

				# For docker host networking, external ports are same as internal ports
				$configPort = $configServer->portMap->{"mongoc$curCfgSvr"} =
				  $configServer->internalPortMap->{"mongoc$curCfgSvr"};
			}
			else {

				# For bridged networking, ports get assigned at start time
				$logger->debug("Looking up port from portMapRef for mongoc$curCfgSvr-W${wkldNum}I${appInstNum} for port "
					 . $configServer->internalPortMap->{"mongoc$curCfgSvr"});
				$configPort = $portMapRef->{ $configServer->internalPortMap->{"mongoc$curCfgSvr"} };
				$logger->debug("Found external port number $configPort for internal port " . $configServer->internalPortMap->{"mongoc$curCfgSvr"});
				$configServer->portMap->{"mongoc$curCfgSvr"} = $configPort;
			}
			$logger->debug( "Port number for config server $curCfgSvr on host ",
				$configServerHost->hostName, " is ", $configPort );

			$configServerHost->registerPortNumber( $configPort, $configServer );

			my $hostname = $configServerHost->hostName;
			if ( $configdbString ne "" ) {
				$configdbString .= ",";
			}
			$configdbString .= "$hostname:$configPort";
			$curCfgSvr++;
		}
		$logger->debug( "Started all config servers.  configdbString = ", $configdbString );
		$appInstance->configDbString($configdbString);
	}

	# configure ports for the shard on this host
	print $dblog "Starting mongod on $hostname\n";
	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->getParamValue('dockerNet') eq "host" ) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{'mongod'} = $self->internalPortMap->{'mongod'};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{'mongod'} = $portMapRef->{ $self->internalPortMap->{'mongod'} };
	}

	$self->host->registerPortNumber( $self->portMap->{'mongod'}, $self );

	# If this is the last mongoService, create, configure, and start
	# the mongos instances on the
	# app servers and primary driver.  Don't start multiple mongos on the same
	# host if multiple app servers are running on the same host
	if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
		$configdbString = $appInstance->configDbString;
		$logger->debug( "Creating, configuring, and starting mongos on appServers and dataManager.  configDbString = ",
			$configdbString );

		my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
		my %hostsMongosCreated;
		my $numMongos = 0;
		foreach my $appServer (@$appServersRef) {
			my $appIpAddr  = $appServer->host->ipAddr;
			my $wkldNum    = $appServer->getWorkloadNum();
			my $appInstNum = $appServer->getAppInstanceNum();
			my $dockerName = "mongos" . "-W${wkldNum}I${appInstNum}-" . $appIpAddr;

			if ( exists $hostsMongosCreated{$appIpAddr} ) {

				# If a mongos has already been created on this host,
				# Don't start another one
				if ( exists( $self->dockerConfigHashRef->{"net"} )
					&& ( $self->dockerConfigHashRef->{"net"} eq "host" ) )
				{

					# For docker host networking, external ports are same as internal ports
					$appServer->setMongosDocker($hostname);
				}
				elsif ( $appServer->useDocker()
					&& ( $appServer->dockerConfigHashRef->{"net"} eq $self->dockerConfigHashRef->{"net"} ) )
				{

					# Also use the internal port if the appServer is also using docker and is on
					# the same (non-host) network as the mongos, but use the docker name rather than the hostname
					my $mongosDocker = $appServer->host->dockerGetIp($dockerName);
					$appServer->setMongosDocker($mongosDocker);
				}
				else {

					# Mongos is using bridged networking and the app server is either not
					# dockerized or is on a different Docker network.  Use external port number
					# and full hostname
					$appServer->setMongosDocker($hostname);
				}
				$appServer->internalPortMap->{'mongos'} = $hostsMongosCreated{$appIpAddr};
				next;
			}
			$logger->debug( "Creating mongos on ", $appServer->host->hostName );
			my $mongosPort =
			  $self->internalPortMap->{'mongos'} +
			  ( $self->getParamValue( $self->getParamValue('serviceType') . 'PortStep' ) * $numMongos );
			$numMongos++;

			my %volumeMap;
			my %envVarMap;
			$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
			$envVarMap{"MONGOSPORT"} = $mongosPort;
			$envVarMap{"NUMSHARDS"} = $appInstance->numNosqlShards;
			$envVarMap{"NUMREPLICAS"} = $appInstance->numNosqlReplicas;
			$envVarMap{"ISCFGSVR"} = 0;
			$envVarMap{"ISMONGOS"} = 1;
			$envVarMap{"CLEARBEFORESTART"} = 0;		
			
			my %portMap;
			my $directMap = 1;

			# Save the mongos port for this host in the internalPortMap
			$portMap{$mongosPort} = $mongosPort;

			my $entrypoint;
			my $cmd = "mongos -f /etc/mongos.conf --configdb $configdbString ";

			# Create the container
			$appServer->host->dockerRun( $dblog, $dockerName, $self->getImpl(), $directMap, \%portMap, \%volumeMap,
				\%envVarMap, $self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

			# set up the ports
			my $portMapRef = $appServer->host->dockerPort($dockerName);

			if ( exists( $self->dockerConfigHashRef->{"net"} ) && ( $self->dockerConfigHashRef->{"net"} eq "host" ) ) {
				$logger->debug("mongos $dockerName uses host networking, setting app server to use external name and port");
				# For docker host networking, external ports are same as internal ports
				$appServer->internalPortMap->{'mongos'} = $mongosPort;
				$appServer->setMongosDocker($hostname);
				$hostsMongosCreated{$appIpAddr} = $mongosPort;

			}
			elsif ( $appServer->useDocker()
				&& ( $appServer->dockerConfigHashRef->{"net"} eq $self->dockerConfigHashRef->{"net"} ) )
			{

				# Also use the internal port if the appServer is also using docker and is on
				# the same (non-host) network as the mongos, but use the docker name rather than the hostname
				$logger->debug("app server and mongos are both dockerized on the same host and network, setting app server to use internal name and port");
				$appServer->internalPortMap->{'mongos'} = $mongosPort;
				my $mongosDocker = $appServer->host->dockerGetIp($dockerName);
				$appServer->setMongosDocker($mongosDocker);
				$hostsMongosCreated{$appIpAddr} = $mongosPort;

			}
			else {

				# Mongos is using bridged networking and the app server is either not
				# dockerized or is on a different Docker network.  Use external port number
				# and full hostname
				$logger->debug("app server is not dockerized or on different network, setting app server to use external name and port");
				$appServer->internalPortMap->{'mongos'} = $portMapRef->{$mongosPort};
				$appServer->setMongosDocker($hostname);
				$hostsMongosCreated{$appIpAddr} = $portMapRef->{$mongosPort};

			}
			$logger->debug(
				"Started mongos on ", $appServer->host->hostName,
				".  Port number is ", $appServer->internalPortMap->{'mongos'}
			);

			# Make sure this port is open, but don't register it with the host
			# since the appServer will do that when it starts
			$appServer->host->openPortNumber( $appServer->internalPortMap->{'mongos'} );
		}

		# create a mongos on the data manager
		my $dataManagerDriver           = $self->appInstance->dataManager;
		my $dataManagerSshConnectString = $dataManagerDriver->host->sshConnectString;
		my $dataManagerIpAddr           = $dataManagerDriver->host->ipAddr;
		my $localMongosPort;
		if ( !exists $hostsMongosCreated{$dataManagerIpAddr} ) {

			my $mongosPort =
			  $self->internalPortMap->{'mongos'} +
			  ( $self->getParamValue( $self->getParamValue('serviceType') . 'PortStep' ) * $numMongos );
			$numMongos++;

			my %volumeMap;
			my %envVarMap;
			$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
			$envVarMap{"MONGOSPORT"} = $mongosPort;
			$envVarMap{"NUMSHARDS"} = $appInstance->numNosqlShards;
			$envVarMap{"NUMREPLICAS"} = $appInstance->numNosqlReplicas;
			$envVarMap{"ISCFGSVR"} = 0;
			$envVarMap{"ISMONGOS"} = 1;
			$envVarMap{"CLEARBEFORESTART"} = 0;		
			
			my %portMap;
			my $directMap = 1;

			my $wkldNum    = $dataManagerDriver->getWorkloadNum();
			my $appInstNum = $dataManagerDriver->getAppInstanceNum();

			# Save the mongos port for this hostname in the internalPortMap
			$hostsMongosCreated{$dataManagerIpAddr} = $mongosPort;
			$portMap{$mongosPort}                   = $mongosPort;

			my $entrypoint;
			my $cmd = "mongos -f /etc/mongos.conf --configdb $configdbString ";

			# Create the container
			my $dockerName = "mongos" . "-W${wkldNum}I${appInstNum}-" . $dataManagerIpAddr;
			$dataManagerDriver->host->dockerRun( $dblog, $dockerName, $self->getImpl(), $directMap, \%portMap,
				\%volumeMap, \%envVarMap, $self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

			my $hostname = $dataManagerDriver->host->hostName;

			# get the ports
			my $portMapRef = $dataManagerDriver->host->dockerPort($dockerName );

			if ( $self->getParamValue('dockerNet') eq "host" ) {

				# For docker host networking, external ports are same as internal ports
				$localMongosPort = $dataManagerDriver->portMap->{'mongos'} = $mongosPort;
			}
			else {

				# For bridged networking, ports get assigned at start time
				$localMongosPort = $dataManagerDriver->portMap->{'mongos'} = $portMapRef->{$mongosPort};
			}
			$dataManagerDriver->host->registerPortNumber( $dataManagerDriver->portMap->{'mongos'}, $dataManagerDriver );

		}
		else {
			$localMongosPort = $dataManagerDriver->portMap->{'mongos'} = $hostsMongosCreated{$dataManagerIpAddr};
		}

		# If this is the last Mongodb service to be processed,
		# then clear the static variables for the next action
		$appInstance->clear_numShardsProcessed;
	}

	close $dblog;
}

sub startReplicatedMongodb {
	my ( $self, $logPath ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time             = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StartReplicatedMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $dblog $self->meta->name . " In MongodbService::startReplicatedMongodb\n";
	my $cmdOut;
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->getParamValue('dockerNet') eq "host" ) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{'mongod'} = $self->internalPortMap->{'mongod'};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{'mongod'} = $portMapRef->{ $self->internalPortMap->{'mongod'} };
	}
	$self->registerPortsWithHost();

	close $dblog;
}

sub startShardedReplicatedMongodb {
	my ( $self, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	$console_logger->error("Dockerized sharded and replicated MongoDB is not yet implemented.");
	exit(-1);
}

sub startSingleMongodb {
	my ( $self, $logPath ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time             = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StartSingleMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $dblog $self->meta->name . " In MongodbService::startSingleMongodb\n";
	my $cmdOut;
	print $dblog "$hostname has shardNum " . $self->shardNum . " and replicaNum " . $self->replicaNum . "\n";

	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->getParamValue('dockerNet') eq "host" ) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{'mongod'} = $self->internalPortMap->{'mongod'};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{'mongod'} = $portMapRef->{ $self->internalPortMap->{'mongod'} };
	}
	$self->registerPortsWithHost();

	close $dblog;
}

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
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	$logger->debug("stop ShardedMongodbDockerService");

	my $appInstance = $self->appInstance;

	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StopShardedMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::stopShardedMongodbDocker\n";

	my $cmdOut;

	# If this is the first MongoDB service to run,
	# then configure the numShardsProcessed variable
	if ( !$appInstance->has_numShardsProcessed() ) {
		print $dblog "Setting numShardsProcessed to 1.\n";
		$appInstance->numShardsProcessed(1);

		# Stop the mongos
		my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
		my %hostsMongosCreated;
		my $numMongos = 0;
		foreach my $appServer (@$appServersRef) {
			my $appIpAddr = $appServer->host->ipAddr;

			if ( exists $hostsMongosCreated{$appIpAddr} ) {
				next;
			}
			$hostsMongosCreated{$appIpAddr} = 1;

			$appServer->host->dockerStop( $dblog, 'mongos' );

		}
		my $dataManagerDriver = $self->appInstance->dataManager;
		my $dataManagerIpAddr = $dataManagerDriver->host->ipAddr;
		my $localMongoPort;
		if ( !exists $hostsMongosCreated{$dataManagerIpAddr} ) {
			$dataManagerDriver->host->dockerStop( $dblog, 'mongos' );
		}

	}
	else {
		my $numShardsProcessed = $appInstance->numShardsProcessed;
		print $dblog "Incrementing numShardsProcessed from $numShardsProcessed \n";
		$appInstance->numShardsProcessed( $numShardsProcessed + 1 );
	}

	# Stop the shard on this node
	$self->host->dockerStop( $dblog, $name );

	# If this is the last Mongodb service to be processed,
	# then clear the static variables for the next action
	if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {

		# stop the config servers
		my $configServersRef = $self->configServersRef;
		my $curCfgSvr        = 1;
		my $wkldNum          = $self->getWorkloadNum();
		my $appInstNum       = $self->getAppInstanceNum();

		if ( $#{$configServersRef} > -1 ) {

			# Still have the config servers hosts hash, use
			# it to stop the config servers
			foreach my $configServer (@$configServersRef) {
				my $configServerHost = $configServer->host;
				$configServerHost->dockerStop( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );
				$curCfgSvr++;
			}
		}
		else {

			# figure out where the config servers should be
			while ( $curCfgSvr <= $self->numConfigServers ) {
				my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

				foreach my $nosqlServer (@$nosqlServersRef) {
					$nosqlServer->host->dockerStop( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );

					$curCfgSvr++;
					if ( $curCfgSvr > $self->numConfigServers ) {
						last;
					}
				}
			}
		}

		$appInstance->clear_numShardsProcessed;
		$appInstance->clear_configDbString;
	}
	close $dblog;

}

sub stopReplicatedMongodb {

	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	$logger->debug("stop ReplicatedMongodbDockerService");

	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StopReplicatedMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $dblog, $name );

	close $dblog;

}

sub stopShardedReplicatedMongodb {

	my ( $self, $logPath ) = @_;

	my $hostname = $self->host->hostName;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StopShardedReplicatedMongodb-$hostname-$time.log";
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
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	$logger->debug("stop SingleMongodbDockerService");

	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/StopSingleMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $dblog, $name );

	close $dblog;
}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/RemoveMongodbDocker-$hostname-$name-$time.log";
	my $appInstance = $self->appInstance;
	my $wkldNum     = $self->getWorkloadNum();
	my $appInstNum  = $self->getAppInstanceNum();

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$logger->debug("remove for $name");

	$self->host->dockerStopAndRemove( $dblog, $name );

	if ( $appInstance->numNosqlShards > 0 ) {

		# If this is the first MongoDB service to be configured,
		# then configure the numShardsProcessed variable
		if ( !$appInstance->has_numShardsProcessed() ) {
			$logger->debug("Setting numShardsProcessed to 1");
			print $dblog "Setting numShardsProcessed to 1\n";
			$appInstance->numShardsProcessed(1);

			# remove the config servers
			my $configServersRef = $self->configServersRef;
			my $curCfgSvr        = 1;

			if ( $#{$configServersRef} > -1 ) {
				$logger->debug("Removing config servers using configServersRef");

				# Still have the config servers hosts hash, use
				# it to stop the config servers
				foreach my $configServer (@$configServersRef) {
					my $configServerHost = $configServer->host;
					$configServerHost->dockerStopAndRemove( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );
					$curCfgSvr++;
				}
			}
			else {

				# figure out where the config servers should be
				$logger->debug("Removing config servers by figuring it out");
				while ( $curCfgSvr <= $self->numConfigServers ) {
					my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');

					foreach my $nosqlServer (@$nosqlServersRef) {
						$logger->debug( "Removing config server $curCfgSvr from host ", $nosqlServer->host->hostName );

						$nosqlServer->host->dockerStopAndRemove( $dblog,
							"mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );

						$curCfgSvr++;
						if ( $curCfgSvr > $self->numConfigServers ) {
							last;
						}
					}
				}
			}
		}
		else {
			$logger->debug( "Incrementing numShardsProcessed from " . $appInstance->numShardsProcessed );
			print $dblog "Incrementing numShardsProcessed from " . $appInstance->numShardsProcessed . "\n";
			$appInstance->numShardsProcessed( $appInstance->numShardsProcessed + 1 );
		}

		if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
			$appInstance->clear_numShardsProcessed;
			$logger->debug("Removing the mongos and clearing the configServersRef");
			$self->configServersRef( [] );
			my $configServersRef = $self->configServersRef;
			if ( $#{$configServersRef} > -1 ) {
				$logger->warn("Even after clear, the self->configServersRef is not empty: @$configServersRef");
			}

			# Remove the mongos
			my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
			my %hostsMongosCreated;
			my $numMongos = 0;
			foreach my $appServer (@$appServersRef) {
				my $appIpAddr = $appServer->host->ipAddr;

				if ( exists $hostsMongosCreated{$appIpAddr} ) {
					next;
				}
				$hostsMongosCreated{$appIpAddr} = 1;
				my $dockerName = "mongos" . "-W${wkldNum}I${appInstNum}-" . $appIpAddr;

				$appServer->host->dockerStopAndRemove( $dblog, $dockerName );

			}
			my $dataManagerDriver = $self->appInstance->dataManager;
			my $dataManagerIpAddr = $dataManagerDriver->host->ipAddr;
			my $dockerName        = "mongos" . "-W${wkldNum}I${appInstNum}-" . $dataManagerIpAddr;
			my $localMongoPort;
			if ( !exists $hostsMongosCreated{$dataManagerIpAddr} ) {
				$dataManagerDriver->host->dockerStopAndRemove( $dblog, $dockerName );
			}
		}
	}

	close $dblog;
};

sub clearDataAfterStart {
}

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->hostName;
	
	$self->clearBeforeStart(1);
	
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

	return $self->host->dockerIsRunning( $fileout, $self->getParamValue('dockerName') );

}

sub isBackupAvailable {
	my ( $self, $backupDirPath, $applog ) = @_;
	my $name        = $self->getParamValue('dockerName');

	# Backups are not supported when running with docker
	return 0;

}

sub stopStatsCollection {
	my ($self) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname                    = $self->host->hostName;
	my $port                        = $self->portMap->{'mongod'};
	my $name                        = $self->getParamValue('dockerName');
	my $dataManager                 = $self->appInstance->dataManager;
	my $dataManagerSshConnectString = $dataManager->host->sshConnectString;

	my $pid = fork();
	if ( $pid == 0 ) {
`$dataManagerSshConnectString \"mongostat --port $port --host $hostname -n $numIntervals $intervalLengthSec > /tmp/mongostat_${hostname}_$name.txt\"`;
		exit;
	}

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $dataManager      = $self->appInstance->dataManager;
	my $scpConnectString = $dataManager->host->scpConnectString;
	my $scpHostString    = $dataManager->host->scpHostString;

	my $out = `$scpConnectString root\@$scpHostString:/tmp/mongostat_${hostname}_$name.txt $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ($self)   = @_;
	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;

	my $out = `rm -f /tmp/mongostat_${hostname}-$name.txt 2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name        = $self->getParamValue('dockerName');
	my $hostname    = $self->host->hostName;
	my $appInstance = $self->appInstance;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $time = `date +%H:%M`;
	chomp($time);
	my $logName = "$logpath/GetLogFilesMongodbDocker-$hostname-$name-$time.log";

	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $logContents = $self->host->dockerGetLogs( $dblog, $name );

	my $logfile;
	open( $logfile, ">$logpath/mongod-$hostname-$name.log" )
	  or die "Error opening $logpath/mongod-$hostname-$name.log: $!\n";

	print $logfile $logContents;

	close $logfile;

	if ( $appInstance->numNosqlShards > 0 ) {

		# If this is the first MongoDB service to be configured,
		# then configure the numShardsProcessed variable
		if ( !$appInstance->has_numShardsProcessed() ) {
			print $dblog "Setting numShardsProcessed to 1\n";
			$appInstance->numShardsProcessed(1);

			# get the logs from the config servers
			my $wkldNum          = $self->getWorkloadNum();
			my $appInstNum       = $self->getAppInstanceNum();
			my $configServersRef = $self->configServersRef;
			my $curCfgSvr        = 1;
			foreach my $configServer (@$configServersRef) {
				my $configServerHost = $configServer->host;
				my $logContents =
				  $configServerHost->dockerGetLogs( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );
				$hostname = $configServerHost->hostName;

				open( $logfile, ">$logpath/mongoc$curCfgSvr-$hostname.log" )
				  or die "Error opening $logpath/mongoc$curCfgSvr-$hostname.log: $!\n";

				print $logfile $logContents;

				close $logfile;
				$curCfgSvr++;
			}
		}
		else {
			print $dblog "Incrementing numShardsProcessed from " . $appInstance->numShardsProcessed . "\n";
			$appInstance->numShardsProcessed( $appInstance->numShardsProcessed + 1 );
		}

		if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
			$appInstance->clear_numShardsProcessed;

			# Get the log files from the mongos nodes
			my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
			my %hostsMongosCreated;
			my $numMongos = 0;
			foreach my $appServer (@$appServersRef) {
				my $appIpAddr = $appServer->host->ipAddr;

				if ( exists $hostsMongosCreated{$appIpAddr} ) {
					next;
				}
				$hostsMongosCreated{$appIpAddr} = 1;

				my $logContents = $appServer->host->dockerGetLogs( $dblog, "mongos" );
				$hostname = $appServer->host->hostName;
				open( $logfile, ">$logpath/mongos-$hostname.log" )
				  or die "Error opening $logpath/mongos-$hostname.log: $!\n";

				print $logfile $logContents;

				close $logfile;

			}
			my $dataManagerDriver = $self->appInstance->dataManager;
			my $dataManagerIpAddr = $dataManagerDriver->host->ipAddr;
			my $localMongoPort;
			if ( !exists $hostsMongosCreated{$dataManagerIpAddr} ) {
				my $logContents = $dataManagerDriver->host->dockerGetLogs( $dblog, "mongos" );
				$hostname = $dataManagerDriver->host->hostName;
				open( $logfile, ">$logpath/mongos-$hostname.log" )
				  or die "Error opening $logpath/mongos-$hostname.log: $!\n";

				print $logfile $logContents;

				close $logfile;

			}

		}
	}

	close $dblog;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $appInstance = $self->appInstance;
	`mkdir -p $destinationPath`;

	`cp /tmp/$hostname-$name-mongod*.conf $destinationPath/. 2>&1`;

	if ( $appInstance->numNosqlShards > 0 ) {

		# If this is the first MongoDB service to be configured,
		if ( !$appInstance->has_numShardsProcessed() ) {
			$appInstance->numShardsProcessed(1);

			# get the config files for the config servers
			`cp /tmp/*-mongoc*.conf $destinationPath/. 2>&1`;
		}
		else {
			$appInstance->numShardsProcessed( $appInstance->numShardsProcessed + 1 );
		}

		if ( $appInstance->numShardsProcessed == $appInstance->numNosqlShards ) {
			$appInstance->clear_numShardsProcessed;
			`cp /tmp/*-mongos.conf $destinationPath/.`;

		}
	}
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

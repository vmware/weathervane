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

has '+version' => ( default => '3.4.x', );

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

has 'numNosqlShards' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

has 'numNosqlReplicas' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

has 'clearBeforeStart' => (
	is      => 'rw',
	isa     => 'Bool',
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

class_has 'configuredAfterStart' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

override 'initialize' => sub {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	my $numNosqlServers = $self->appInstance->getTotalNumOfServiceType('nosqlServer');
	$logger->debug("initialize called with numNosqlServers = $numNosqlServers");
	my $console_logger = get_logger("Console");
	my $appInstance    = $self->appInstance;

	# Figure out how many shards, and how many replicas per shard.
	my $replicasPerShard = $self->getParamValue('nosqlReplicasPerShard');
	my $sharded          = $self->getParamValue('nosqlSharded');
	my $replicated       = $self->getParamValue('nosqlReplicated');
	
	my $numNosqlShards = 0;
	my $numNosqlReplicas = 0;
	# Determine the number of shards and replicas-per-shard
	if ($sharded) {
		if ($replicated) {
			$console_logger->error("Configuring MongoDB as both sharded and replicated is not yet supported.");
			exit(-1);
		} else {
			if ( $numNosqlServers < 2 ) {
				$console_logger->error("When sharding MongoDB, the number of servers must be greater than 1.");
				exit(-1);
			}
			$numNosqlShards = $numNosqlServers;
			$self->numNosqlShards($numNosqlServers);
			$logger->debug("MongoDB .  MongoDB is sharded with $numNosqlShards shards");
		}
	}
	elsif ($replicated) {
		if ( ( $numNosqlServers % $replicasPerShard ) > 0 ) {
			$console_logger->error(
"When replicating MongoDB, the number of servers must be an even multiple of the number of replicas-per-shard ($replicasPerShard)."
			);
			exit(-1);
		}
		$numNosqlReplicas = $numNosqlServers / $replicasPerShard ;
		$self->numNosqlReplicas($numNosqlReplicas);
		$logger->debug("MongoDB .  MongoDB is replicated with $numNosqlReplicas replicas");
	}
	else {
		if ( $numNosqlServers > 1 ) {
			$console_logger->error(
"When the number of MongoDB servers is greater than 1, the deployment must be sharded or replicated."
			);
			exit(-1);
		}
		$logger->debug("MongoDB .  MongoDB is not sharded or replicated.");
	}
	
	my $instanceNumber = $self->instanceNum;
	if ( ( $self->numNosqlShards > 0 ) && ( $self->numNosqlReplicas > 0 ) ) {
		$self->shardNum( ceil( $instanceNumber / ( 1.0 * $self->numNosqlReplicas ) ) );
		$self->replicaNum( ( $instanceNumber % $self->numNosqlReplicas ) + 1 );
	}
	elsif ( $self->numNosqlShards > 0 ) {
		$self->shardNum($instanceNumber);
	}
	elsif (  $self->numNosqlReplicas > 0 ) {
		$self->replicaNum($instanceNumber);
	}
	elsif ( $numNosqlServers > 1 ) {
		die "When not using sharding or replicas, the number of NoSQL servers must equal 1.";
	}
	
	super();
};

sub setPortNumbers {
	my ($self) = @_;

	my $appInstance     = $self->appInstance;
	my $numNosqlServers = $appInstance->getTotalNumOfServiceType('nosqlServer');
	my $numShards       = $self->numNosqlShards;
	my $numReplicas     = $self->numNosqlReplicas;

	my $serviceType    = $self->getParamValue('serviceType');
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	my $instanceNumber = $self->instanceNum;
	$self->internalPortMap->{'mongod'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongos'}  = 27017;
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
	my $name = $self->name;
	my $portMapRef = $self->host->dockerPort($name );

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
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

sub configureAfterStart {
	my ($self, $logPath, $mongosHostPortListRef)            = @_;
	my $console_logger   = get_logger("Console");
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $name     = $self->name;
	my $host = $self->host;
	my $hostname = $self->host->name;
	my $impl     = $self->getImpl();

	my $logName = "$logPath/ConfigureAfterStartMongodbDocker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	if ($self->configuredAfterStart) {
		return;
	}
	$self->configuredAfterStart(1);
	my $appInstance = $self->appInstance;

	my $nosqlServersRef = $appInstance->getAllServicesByType('nosqlServer');
	my $cmdout;
	my $replicaMasterHostname = "";
	my $replicaMasterPort = "";
	if (   ( $self->numNosqlShards > 0 )
		&& ( $self->numNosqlReplicas > 0 ) )
	{
		$console_logger->( "Loading data in sharded and replicated mongo is not supported yet" );
		return 0;
	}
	elsif ( $self->numNosqlShards > 0 ) {
		print $applog "Sharding MongoDB\n";
		my $mongosHostname = $mongosHostPortListRef->[0];
		my $localPort = $mongosHostPortListRef->[1];
		my $cmdString;

		# Add the shards to the database
		foreach my $nosqlServer (@$nosqlServersRef) {
			my $hostname = $nosqlServer->getIpAddr();
			my $port   = $nosqlServer->portMap->{'mongod'};
			print $applog "Add $hostname as shard.\n";
			$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.addShard(\\\"$hostname:$port\\\"))' 2>&1";
			my $cmdout = `$cmdString`;	
			print $applog "$cmdString\n";
			print $applog $cmdout;
		}

		# enable sharding for the databases

		print $applog "Enabling sharding for auction database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"auction\\\"))' 2>&1";
		my $cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for bid database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"bid\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for attendanceRecord database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"attendanceRecord\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for imageInfo database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"imageInfo\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionFullImages database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"auctionFullImages\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionPreviewImages database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"auctionPreviewImages\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Enabling sharding for auctionThumbnailImages database.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.enableSharding(\\\"auctionThumbnailImages\\\"))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;

		# Create indexes for collections
		print $applog "Adding hashed index for userId in attendanceRecord Collection.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname attendanceRecord --eval 'printjson(db.attendanceRecord.ensureIndex({userId : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for bidderId in bid Collection.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname bid --eval 'printjson(db.bid.ensureIndex({bidderId : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for entityid in imageInfo Collection.\n";
		$cmdString =
		  "mongo --port $localPort --host $mongosHostname imageInfo --eval 'printjson(db.imageInfo.ensureIndex({entityid : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imageFull Collection.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname auctionFullImages --eval 'printjson(db.imageFull.ensureIndex({imageid : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imagePreview Collection.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname auctionPreviewImages --eval 'printjson(db.imagePreview.ensureIndex({imageid : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Adding hashed index for imageid in imageThumbnail Collection.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname auctionThumbnailImages --eval 'printjson(db.imageThumbnail.ensureIndex({imageid : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;

		# shard the collections
		print $applog "Sharding attendanceRecord collection on hashed userId.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"attendanceRecord.attendanceRecord\\\", {\\\"userId\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Sharding bid collection on hashed bidderId.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"bid.bid\\\",{\\\"bidderId\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Sharding imageInfo collection on hashed entityid.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"imageInfo.imageInfo\\\",{\\\"entityid\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Sharding imageFull collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"auctionFullImages.imageFull\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Sharding imagePreview collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"auctionPreviewImages.imagePreview\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
		print $applog "Sharding imageThumbnail collection on hashed imageid.\n";
		$cmdString =
"mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.shardCollection(\\\"auctionThumbnailImages.imageThumbnail\\\",{\\\"imageid\\\" : \\\"hashed\\\"}))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;

		# disable the balancer
		print $applog "Disabling the balancer.\n";
		$cmdString = "mongo --port $localPort --host $mongosHostname --eval 'printjson(sh.setBalancerState(false))' 2>&1";
		$cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;

	}
	elsif ( $self->numNosqlReplicas > 0 ) {
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
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.initiate($replicaConfig))' 2>&1";				
				$logger->debug("Add $hostname as replica primary: $cmdString");
				$cmdout = `$cmdString`;
				$logger->debug("Add $hostname as replica primary result : $cmdout");
				print $applog $cmdout;

				print $applog "rs.status() : \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())' 2>&1";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() : \n$cmdout");
				print $applog $cmdout;

				sleep(30);

				print $applog "rs.status() after 30s: \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())' 2>&1";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() after 30s : \n$cmdout");
				print $applog $cmdout;

				sleep(30);

				print $applog "rs.status() after 60s: \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $port --eval 'printjson(rs.status())' 2>&1";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() after 60s : \n$cmdout");
				print $applog $cmdout;

			}
			else {
				print $applog "Add $hostname as replica secondary.\n";
				$cmdString = "mongo --host $replicaMasterHostname --port $replicaMasterPort --eval 'printjson(rs.add(\"$hostname:$port\"))' 2>&1";
				$logger->debug("Add $hostname as replica secondary: $cmdString");
				$cmdout = `$cmdString`;
				$logger->debug("Add $hostname as replica secondary result : $cmdout");
				print $applog $cmdout;

				print $applog "rs.status() : \n";
				$cmdString = "mongo --host $replicaMasterHostname --port $replicaMasterPort --eval 'printjson(rs.status())' 2>&1";
				$cmdout = `$cmdString`;
				$logger->debug("rs.status() : \n$cmdout");
				print $applog $cmdout;

			}
		}

	}
	
	close $applog;

}

# Configure and Start all of the services needed for the 
# MongoDB service
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	my $console_logger   = get_logger("Console");
	my $time = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/StartMongodb-$time.log";
	my $appInstance = $self->appInstance;
	
	$logger->debug("MongoDB Start");
	
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbDockerService::start\n";
			
	my $isReplicated = 0;
	my $mongosHostPortListRef;
	if ( ( $self->numNosqlShards > 0 ) && ( $self->numNosqlReplicas > 0 ) ) {
		die "Need to implement startShardedReplicatedMongodbDocker";
	}
	elsif ( $self->numNosqlShards > 0 ) {
		# start config servers
		my $configdbString = $self->startMongocServers($dblog);

		# start shards
		$self->startMongodServers($isReplicated, $dblog);
		
		# start mongos servers
		$mongosHostPortListRef = $self->startMongosServers($configdbString, $dblog);
		my $mongosHostname = $mongosHostPortListRef->[0];
		my $mongosPort = $mongosHostPortListRef->[1];
		
	}
	elsif ( $self->numNosqlReplicas > 0 ) {
		$isReplicated = 1;
		$self->startMongodServers($isReplicated, $dblog);
	}
	else {
		$self->startMongodServers($isReplicated, $dblog);
	}

	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		$nosqlServer->setExternalPortNumbers();
	}

	$self->configureAfterStart($logPath, $mongosHostPortListRef);

};


sub startMongodServers {
	my ( $self, $isReplicated, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	
	print $dblog "Starting mongod servers\n";
	$logger->debug("Starting mongod servers");

	#  start all of the mongod servers
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {
		my $host = $nosqlServer->host;
		my $hostname = $host->name;
		my $impl     = $nosqlServer->getImpl();
		my $name        = $nosqlServer->name;
		
		my %volumeMap;
		if ($self->getParamValue('mongodbUseNamedVolumes') || $host->getParamValue('vicHost')) {
			$volumeMap{"/mnt/mongoData"} = $nosqlServer->getParamValue('mongodbDataVolume');
		}

		my %envVarMap;
		$envVarMap{"MONGODPORT"} = $nosqlServer->internalPortMap->{'mongod'};
		$envVarMap{"NUMSHARDS"} = $self->numNosqlShards;
		$envVarMap{"NUMREPLICAS"} = $self->numNosqlReplicas;
		$envVarMap{"ISCFGSVR"} = 0;
		$envVarMap{"ISMONGOS"} = 0;
	
		if ($nosqlServer->clearBeforeStart) {
			$envVarMap{"CLEARBEFORESTART"} = 1;		
		} else {
			$envVarMap{"CLEARBEFORESTART"} = 0;		
		}
		
		my %portMap;
		my $directMap = 0;

		# when creating single only need to expose the mongod port 
		my $port = $nosqlServer->internalPortMap->{'mongod'};
		$portMap{$port} = $port;

		my $entrypoint = "";
		my $cmd = "";

		# Create the container
		$nosqlServer->host->dockerRun( $dblog, $name, $impl, $directMap, \%portMap, \%volumeMap, \%envVarMap,
			$nosqlServer->dockerConfigHashRef, $entrypoint, $cmd, $nosqlServer->needsTty );		# start the mongod on this host
	
		# Set the ports		
		my $portMapRef = $self->host->dockerPort($name);
		if ( $nosqlServer->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
			# For docker host networking, external ports are same as internal ports
			$nosqlServer->portMap->{'mongod'} = $nosqlServer->internalPortMap->{'mongod'};
		}
		else {
			# For bridged networking, ports get assigned at start time
			$nosqlServer->portMap->{'mongod'} = $portMapRef->{ $nosqlServer->internalPortMap->{'mongod'} };
		}
		
	}
}

sub startMongocServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $workloadNum = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $suffix = "W${workloadNum}I${appInstanceNum}";

	print $dblog "Starting config servers\n";
	$logger->debug("Starting config servers");
	my @configSvrHostnames;
	my @configSvrPorts;

	my $curCfgSvr = 1;
	my $configdbString = "";
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	while ( $curCfgSvr <= $self->numConfigServers ) {

		foreach my $nosqlServer (@$nosqlServersRef) {
			$logger->debug( "Creating config server $curCfgSvr on ", $nosqlServer->host->name );
			print $dblog "Creating config server $curCfgSvr on " . $nosqlServer->host->name . "\n";
		
			my $host = $nosqlServer->host;
			my %volumeMap;
			if ($self->appInstance->getParamValue('mongodbUseNamedVolumes') || $host->getParamValue('vicHost')) {
				$volumeMap{"/mnt/mongoC${curCfgSvr}data"} = $nosqlServer->getParamValue("mongodbC${curCfgSvr}DataVolume");;
			}

			my %envVarMap;
			$envVarMap{"MONGODPORT"} = $nosqlServer->internalPortMap->{'mongod'};
			$envVarMap{"MONGOCPORT"} = $nosqlServer->internalPortMap->{'mongoc'.$curCfgSvr};
			$envVarMap{"CFGSVRNUM"} = $curCfgSvr;
			$envVarMap{"NUMSHARDS"} = $self->numNosqlShards;
			$envVarMap{"NUMREPLICAS"} = $self->numNosqlReplicas;
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
			my $entrypoint = "";
			my $cmd = "";

			# Create the container
			$host->dockerRun( $dblog, "mongoc$curCfgSvr-W${workloadNum}I${appInstanceNum}",
				$nosqlServer->getImpl(), $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef, $entrypoint,
				$cmd, $self->needsTty );

			# Determine the externally visible configPort
			if ( $host->dockerNetIsHostOrExternal($nosqlServer->getParamValue('dockerNet') )) {
				# For docker host networking, external ports are same as internal ports
				$configPort = $nosqlServer->portMap->{"mongoc$curCfgSvr"} =
				  $nosqlServer->internalPortMap->{"mongoc$curCfgSvr"};
			}
			else {
				# For bridged networking, ports get assigned at start time
				my $portMapRef = $host->dockerPort("mongoc$curCfgSvr-W${workloadNum}I${appInstanceNum}");
				$logger->debug("Keys from docker port of mongoc$curCfgSvr-W${workloadNum}I${appInstanceNum} = ", keys %$portMapRef);
				$logger->debug("Looking up port from portMapRef for mongoc$curCfgSvr-W${workloadNum}I${appInstanceNum} for port "
					 . $nosqlServer->internalPortMap->{"mongoc$curCfgSvr"});
				$configPort = $portMapRef->{ $nosqlServer->internalPortMap->{"mongoc$curCfgSvr"} };
				$logger->debug("Found external port number $configPort for internal port " . $nosqlServer->internalPortMap->{"mongoc$curCfgSvr"});
				$nosqlServer->portMap->{"mongoc$curCfgSvr"} = $configPort;
			}

			my $mongoHostname    = $nosqlServer->host->name;
			if ( $configdbString ne "" ) {
				$configdbString .= ",";
			} else {
				$configdbString = "auction$suffix-config/";
			}

			
			$configdbString .= "$mongoHostname:$configPort";
			push @configSvrHostnames, $mongoHostname;
			push @configSvrPorts, $configPort;
			
			$curCfgSvr++;
			if ( $curCfgSvr > $self->numConfigServers ) {
				last;
			}
		}
	}

	# Initialize config server replica set
	# There is always a config server running on the host of the first shard
	print $dblog "Initialize configServer replica set.\n";
	my $cmdString = "mongo --host $configSvrHostnames[0] --port $configSvrPorts[0] --eval 'printjson(rs.initiate(
		{
			_id: \"auction$suffix-config\",
			configsvr: true,
			members: [
			  { _id : 0, host : \"$configSvrHostnames[0]:$configSvrPorts[0]\" },
      		  { _id : 1, host : \"$configSvrHostnames[1]:$configSvrPorts[1]\" },
      		  { _id : 2, host : \"$configSvrHostnames[2]:$configSvrPorts[2]\" }
    			]
		}))'";
	my $cmdout = `$cmdString`;
	print $dblog "$cmdString\n";
	print $dblog $cmdout;

	# Wait for the config server replica set to be in sync
	$self->waitForMongodbReplicaSync($configSvrHostnames[0], $configSvrPorts[0], $dblog);
	
	$logger->debug("startMongocServers returning configdbString $configdbString");	
	return $configdbString;

}

sub waitForMongodbReplicaSync {
	my ( $self, $nosqlHostname, $port, $runLog) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");

	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	$logger->debug( "waitForMongodbReplicaSync for workload $workloadNum, appInstance $appInstanceNum" );

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

sub startMongosServers {
	my ( $self, $configdbString, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $wkldNum     = $self->appInstance->workload->instanceNum;
	my $appInstNum  = $self->appInstance->instanceNum;

	print $dblog "Starting mongos servers\n";
	$logger->debug("Starting mongos servers");
	my @mongosSvrHostnames;
	my @mongosSvrPorts;

	my $serversRef = $self->appInstance->getAllServicesByType('appServer');
	push @$serversRef, @{$self->appInstance->getAllServicesByType('auctionBidServer')};
	push @$serversRef, $self->appInstance->dataManager;
	my %hostsMongosCreated;
	my $numMongos = 0;
	foreach my $appServer (@$serversRef) {
		my $appHostname = $appServer->host->name;
		my $appIpAddr   = $appServer->host->ipAddr;
		my $dockerName = "mongos" . "-W${wkldNum}I${appInstNum}-" . $appIpAddr;

		if ( exists $hostsMongosCreated{$appIpAddr} ) {
			$logger->debug("Not creating mongos on $appHostname, already exists with dockerName $dockerName");
			# If a mongos has already been created on this host,
			# Don't start another one
			if ( exists( $self->dockerConfigHashRef->{"net"} ) &&
				 ( $self->host->dockerNetIsHostOrExternal($self->dockerConfigHashRef->{"net"}))) 
			{
				# For docker host networking, external ports are same as internal ports
				$logger->debug("For $dockerName, isHostOrExternal so setting mongosDocker on $appHostname to $appHostname");
				$appServer->setMongosDocker($appHostname);
			}
			elsif ( $appServer->dockerConfigHashRef->{"net"} eq $self->dockerConfigHashRef->{"net"} )
			{
				# Also use the internal port if the appServer is also using docker and is on
				# the same (non-host) network as the mongos, but use the docker name rather than the hostname
				my $mongosDocker = $appServer->host->dockerGetIp($dockerName);
				$appServer->setMongosDocker($mongosDocker);
				$logger->debug("For $dockerName, on same docker net so setting mongosDocker on $appHostname to $mongosDocker");
			}
			else {
				# Mongos is using bridged networking and the app server is either not
				# dockerized or is on a different Docker network.  Use external port number
				# and full hostname
				$appServer->setMongosDocker($appHostname);
				$logger->debug("For $dockerName, on different net so setting mongosDocker on $appHostname to $appHostname");
			}
			$logger->debug("For $dockerName, setting internal mongos port to " . $hostsMongosCreated{$appIpAddr});
			$appServer->internalPortMap->{'mongos'} = $hostsMongosCreated{$appIpAddr};
			next;
		}
		
		my $mongosPort =
		  $self->internalPortMap->{'mongos'} +
		  ( $self->getParamValue( $self->getParamValue('serviceType') . 'PortStep' ) * $numMongos );
		$logger->debug("Creating mongos on $appHostname with dockerName $dockerName and mongosPort $mongosPort");
		$numMongos++;

		my %volumeMap;
		my %envVarMap;
		$envVarMap{"MONGODPORT"} = $self->internalPortMap->{'mongod'};
		$envVarMap{"MONGOSPORT"} = $mongosPort;
		$envVarMap{"NUMSHARDS"} = $self->numNosqlShards;
		$envVarMap{"NUMREPLICAS"} = $self->numNosqlReplicas;
		$envVarMap{"ISCFGSVR"} = 0;
		$envVarMap{"ISMONGOS"} = 1;
		$envVarMap{"CONFIGDBSTRING"} = $configdbString;
		$envVarMap{"CLEARBEFORESTART"} = 0;		
			
		my %portMap;
		my $directMap = 1;

		# Save the mongos port for this host in the internalPortMap
		$portMap{$mongosPort} = $mongosPort;

		my $entrypoint = "";
		my $cmd = "";

		# Create the container
		$appServer->host->dockerRun( $dblog, $dockerName, $self->getImpl(), $directMap, \%portMap, \%volumeMap,
			\%envVarMap, $self->dockerConfigHashRef, $entrypoint, $cmd, $self->needsTty );

		# set up the ports
		my $portMapRef = $appServer->host->dockerPort($dockerName);
		if ( exists( $self->dockerConfigHashRef->{"net"} ) &&
			 ( $self->host->dockerNetIsHostOrExternal($self->dockerConfigHashRef->{"net"}))) {
			$logger->debug("mongos $dockerName uses host networking, setting app server to use $appHostname and port $mongosPort");
			# For docker host networking, external ports are same as internal ports
			$appServer->internalPortMap->{'mongos'} = $mongosPort;
			$appServer->setMongosDocker($appHostname);
			$hostsMongosCreated{$appIpAddr} = $mongosPort;
		}
		elsif ( $appServer->dockerConfigHashRef->{"net"} eq $self->dockerConfigHashRef->{"net"} )
		{
			# Also use the internal port if the appServer is also using docker and is on
			# the same (non-host) network as the mongos, but use the docker name rather than the hostname
			$appServer->internalPortMap->{'mongos'} = $mongosPort;
			my $mongosDocker = $appServer->host->dockerGetIp($dockerName);
			$appServer->setMongosDocker($mongosDocker);
			$hostsMongosCreated{$appIpAddr} = $mongosPort;
			$logger->debug("app server and mongos are both dockerized on the same host and network, setting app server to use internal name $mongosDocker and port $mongosPort");
		}
		else {
			# Mongos is using bridged networking and the app server is either not
			# dockerized or is on a different Docker network.  Use external port number
			# and full hostname
			$appServer->internalPortMap->{'mongos'} = $portMapRef->{$mongosPort};
			$appServer->setMongosDocker($appHostname);
			$logger->debug("app server is not dockerized or on different network, setting app server to use $appHostname and port $mongosPort");
			$hostsMongosCreated{$appIpAddr} = $portMapRef->{$mongosPort};
		}
		push @mongosSvrHostnames, $appHostname;
		push @mongosSvrPorts, $appServer->internalPortMap->{'mongos'};
		$logger->debug(
			"Started mongos on ", $appServer->host->name,
			".  Port number is ", $appServer->internalPortMap->{'mongos'}
		);

	}

	return [$mongosSvrHostnames[0], $mongosSvrPorts[0]];
}

# Stop all of the services needed for the MongoDB service
override 'stop' => sub {
	my ($self, $serviceType, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $console_logger   = get_logger("Console");
	my $time = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/StopMongodb-$time.log";
	
	$logger->debug("MongoDB Stop");
	
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::stop\n";
		
	if ( ( $self->numNosqlShards > 0 ) && ( $self->numNosqlReplicas > 0 ) ) {
		die "Need to implement stopShardedReplicatedMongodb";
	}
	elsif ( $self->numNosqlShards > 0 ) {
		# stop mongos servers
		$self->stopMongosServers($dblog);

		# stop config servers
		$self->stopMongocServers($dblog);
	}

	# stop mongod servers
	$self->stopMongodServers($dblog);
		
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		$nosqlServer->cleanLogFiles();
		$nosqlServer->cleanStatsFiles();
	}
};

sub stopMongodServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	
	print $dblog "stopping mongod servers\n";
	$logger->debug("stopping mongod servers");

	#  stop all of the mongod servers
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		my $name     = $nosqlServer->name;
		my $host = $nosqlServer->host;
		$host->dockerStopAndRemove($dblog, $name );
	}
	
}

sub stopMongocServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $wkldNum     = $self->appInstance->workload->instanceNum;
	my $appInstNum  = $self->appInstance->instanceNum;

	print $dblog "Stopping config servers\n";
	$logger->debug("Stopping config servers");

	my $curCfgSvr = 1;
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	while ( $curCfgSvr <= $self->numConfigServers ) {
		foreach my $nosqlServer (@$nosqlServersRef) {
			$nosqlServer->host->dockerStopAndRemove( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );

			$curCfgSvr++;
			if ( $curCfgSvr > $self->numConfigServers ) {
				last;
			}
		}
	}
}

sub stopMongosServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $wkldNum     = $self->appInstance->workload->instanceNum;
	my $appInstNum  = $self->appInstance->instanceNum;

	print $dblog "Stopping mongos servers\n";
	$logger->debug("Stopping mongos servers");

	my %hostsMongosStopped;
	my $serversRef = $self->appInstance->getAllServicesByType('appServer');
	push @$serversRef, @{$self->appInstance->getAllServicesByType('auctionBidServer')};
	push @$serversRef, $self->appInstance->dataManager;
	foreach my $server (@$serversRef) {
		my $ipAddr = $server->host->ipAddr;
		my $dockerName = "mongos" . "-W${wkldNum}I${appInstNum}-" . $ipAddr;
		if ( exists $hostsMongosStopped{$ipAddr} ) {
			next;
		}
		$logger->debug("Stopping mongos on " . $server->host->name);
		$hostsMongosStopped{$ipAddr} = 1;
		$server->host->dockerStopAndRemove( $dblog, $dockerName );
	}
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	my $name        = $self->name;
	$logger->debug("clearDataAfterStart for $name");
}

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->name;
	my $name        = $self->name;
	my $logger = get_logger("Weathervane::Services::MongodbDockerService");
	$logger->debug("clearDataBeforeStart for $name");
	
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

	return $self->host->dockerIsRunning( $fileout, $self->name );

}

sub stopStatsCollection {
	my ($self) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->name;
}

sub cleanStatsFiles {
	my ($self)   = @_;
	my $name     = $self->name;
	my $hostname = $self->host->name;

	my $out = `rm -f /tmp/mongostat_${hostname}-$name.txt 2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name        = $self->name;
	my $hostname    = $self->host->name;
	my $appInstance = $self->appInstance;
	
	
	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	# Need to fix the rest of this
	return;
	
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

	if ( $self->numNosqlShards > 0 ) {

		# If this is the first MongoDB service to be configured,
		# then configure the numShardsProcessed variable
		if ( !$appInstance->has_numShardsProcessed() ) {
			print $dblog "Setting numShardsProcessed to 1\n";
			$appInstance->numShardsProcessed(1);

			# get the logs from the config servers
			my $wkldNum          = $self->appInstance->workload->instanceNum;
			my $appInstNum       = $self->appInstance->instanceNum;
			my $configServersRef = $self->configServersRef;
			my $curCfgSvr        = 1;
			foreach my $configServer (@$configServersRef) {
				my $configServerHost = $configServer->host;
				my $logContents =
				  $configServerHost->dockerGetLogs( $dblog, "mongoc$curCfgSvr-W${wkldNum}I${appInstNum}" );
				$hostname = $configServerHost->name;

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
			my $appServersRef = $self->appInstance->getAllServicesByType('appServer');
			my %hostsMongosCreated;
			my $numMongos = 0;
			foreach my $appServer (@$appServersRef) {
				my $appIpAddr = $appServer->host->ipAddr;

				if ( exists $hostsMongosCreated{$appIpAddr} ) {
					next;
				}
				$hostsMongosCreated{$appIpAddr} = 1;

				my $logContents = $appServer->host->dockerGetLogs( $dblog, "mongos" );
				$hostname = $appServer->host->name;
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
				$hostname = $dataManagerDriver->host->name;
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
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname    = $self->host->name;
	my $name        = $self->name;
	my $appInstance = $self->appInstance;
	`mkdir -p $destinationPath`;

	`cp /tmp/$hostname-$name-mongod*.conf $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	my $appInstance = $self->appInstance;
	$csv{"numNosqlShards"}   = $self->numNosqlShards;
	$csv{"numNosqlReplicas"} = $self->numNosqlReplicas;

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

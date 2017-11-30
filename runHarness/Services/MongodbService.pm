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

# This holds the total number of config servers
# to be used in sharded mode MongoDB requires
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
	my ( $self, $numNosqlServers ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
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
	
	my $instanceNumber = $self->getParamValue('instanceNum');
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

# Stop all of the services needed for the MongoDB service
override 'stop' => sub {
	my ($self, $serviceType, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $console_logger   = get_logger("Console");
	my $time = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/StopMongodb-$time.log";
	my $appInstance = $self->appInstance;
	
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
		
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
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
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		my $hostname = $nosqlServer->host->hostName;

		# stop the mongod on this host
		print $dblog "stopping mongod on $hostname\n";
		$logger->debug("stopping mongod on $hostname");
		my $sshConnectString = $nosqlServer->host->sshConnectString;

		my $cmdString = "$sshConnectString mongod -f /etc/mongod.conf --shutdown";
		my $cmdOut = `$cmdString 2>&1`;
		print $dblog "$cmdString 2>&1\n";
		print $dblog $cmdOut;

		my $dir = $self->getParamValue('mongodbDataDir');
		$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
		print $dblog "$sshConnectString rm -f $dir/mongod.lock\n";
		print $dblog "$cmdOut\n";

	}
	
}

sub stopMongocServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");

	print $dblog "Stopping config servers\n";
	$logger->debug("Stopping config servers");

	my $curCfgSvr = 1;
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	while ( $curCfgSvr <= $self->numConfigServers ) {

		foreach my $nosqlServer (@$nosqlServersRef) {
			my $mongoHostname    = $nosqlServer->host->hostName;
			my $sshConnectString = $nosqlServer->host->sshConnectString;

			# Stop config server on this host
			print $dblog "Stopping configserver$curCfgSvr on $mongoHostname\n";
			$logger->debug("Stopping configserver$curCfgSvr on $mongoHostname");
			my $cmdOut = `$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf --shutdown 2>&1`;
			print $dblog "$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf --shutdown 2>&1\n";
			print $dblog $cmdOut;
			
			my $dir    = $self->getParamValue("mongodbC${curCfgSvr}DataDir");
			$cmdOut = `$sshConnectString rm -f $dir/mongod.lock`;
			print $dblog "$sshConnectString rm -f $dir/mongod.lock\n";
			print $dblog "$cmdOut\n";

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

	print $dblog "Stopping mongos servers\n";
	$logger->debug("Stopping mongos servers");

	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	my %hostsMongosStarted;
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $appServer->host->hostName;
		my $appSshConnectString = $appServer->host->sshConnectString;

		print $dblog "Checking whether mongos is running on $appHostname\n";
		$logger->debug("Checking whether mongos is running on $appHostname");

		# first make sure the mongos is running.  If so, stop it.
		my $cmdOut = `$appSshConnectString \"ps x | grep mongo | grep -v grep\"`;
		print $dblog "ps output on $appHostname: $cmdOut\n";
		$logger->debug("ps output on $appHostname: $cmdOut");
		my @lines = split /\n/, $cmdOut;
		foreach my $line (@lines) {
			if ( $line =~ /\s*(\d+)\s.*mongos\.conf/ ) {
				my $pid = $1;
	    		    $logger->debug("mongos router is running on $appHostname.  Stopping process $pid");
				print $dblog "mongos router is running on $appHostname.  Stopping process $pid\n";
				$cmdOut = `$appSshConnectString kill $pid`;
			}
		}
	}

}

# Configure and Start all of the services needed for the 
# MongoDB service
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $console_logger   = get_logger("Console");
	my $time = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/StartMongodb-$time.log";
	my $appInstance = $self->appInstance;
	
	$logger->debug("MongoDB Start");
	
	my $dblog;
	open( $dblog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $dblog $self->meta->name . " In MongodbService::start\n";
		
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		$nosqlServer->setExternalPortNumbers();
		$nosqlServer->registerPortsWithHost();
	}
	
	# Set up the configuration files for all of the hosts to be part of the service
	$self->configure($dblog, $serviceType, $users, $self->numNosqlShards, $self->numNosqlReplicas);

	my $isReplicated = 0;
	if ( ( $self->numNosqlShards > 0 ) && ( $self->numNosqlReplicas > 0 ) ) {
		die "Need to implement startShardedReplicatedMongodb";
	}
	elsif ( $self->numNosqlShards > 0 ) {
		# start config servers
		my $configdbString = $self->startMongocServers($dblog);

		# start shards
		$self->startMongodServers($isReplicated, $dblog);
		
		# start mongos servers
		my $mongosHostPortListRef = $self->startMongosServers($configdbString, $dblog);
		my $mongosHostname = $mongosHostPortListRef->[0];
		my $mongosPort = $mongosHostPortListRef->[1];
		
		# add the shards and shard the collections		
		$self->configureSharding($mongosHostname, $mongosPort, $dblog);
	}
	elsif ( $self->numNosqlReplicas > 0 ) {
		$isReplicated = 1;
		$self->startMongodServers($isReplicated, $dblog);
	}
	else {
		$self->startMongodServers($isReplicated, $dblog);
	}

	$self->host->startNscd();

};

sub startMongodServers {
	my ( $self, $isReplicated, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	
	print $dblog "Starting mongod servers\n";
	$logger->debug("Starting mongod servers");

	#  start all of the mongod servers
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {	
		my $hostname = $nosqlServer->host->hostName;
		
		# start the mongod on this host
		print $dblog "Starting mongod on $hostname, isReplicated = $isReplicated\n";
		$logger->debug("Starting mongod on $hostname, isReplicated = $isReplicated");
		my $sshConnectString = $nosqlServer->host->sshConnectString;

		my $cmdString = "$sshConnectString mongod -f /etc/mongod.conf ";
		if ($isReplicated) {
			my $replicaName      = "auction" . $self->shardNum;
			$cmdString .= " --replSet=$replicaName ";
		}
		my $cmdOut = `$cmdString 2>&1`;
		print $dblog "$cmdString 2>&1\n";
		print $dblog $cmdOut;
		if ( !( $cmdOut =~ /success/ ) ) {
			print $dblog "Couldn't start mongod on $hostname : $cmdOut\n";
			die "Couldn't start mongod on $hostname : $cmdOut\n";
		}
	}
	
}

sub startMongocServers {
	my ( $self, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $workloadNum = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $suffix = "W${workloadNum}I${appInstanceNum}";

	print $dblog "Starting config servers\n";
	$logger->debug("Starting config servers");
	my @configSvrHostnames;
	my @configSvrPorts;

	my $curCfgSvr = 1;
	my $configdbString = "";
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	while ( $curCfgSvr <= $self->numConfigServers ) {

		foreach my $nosqlServer (@$nosqlServersRef) {
			my $configPort = $self->portMap->{"mongoc$curCfgSvr"};
			my $mongoHostname    = $nosqlServer->host->hostName;
			my $sshConnectString = $nosqlServer->host->sshConnectString;

			# Start a config server on this host
			print $dblog "Starting configserver$curCfgSvr on $mongoHostname, port $configPort\n";
			$logger->debug("Starting configserver$curCfgSvr on $mongoHostname, port $configPort");
			my $cmdOut = `$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf 2>&1`;
			print $dblog "$sshConnectString mongod -f /etc/mongoc$curCfgSvr.conf 2>&1\n";
			print $dblog $cmdOut;
			if ( !( $cmdOut =~ /success/ ) ) {
				die "Couldn't start configserver$curCfgSvr on $mongoHostname : $cmdOut\n";
			}
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

sub startMongosServers {
	my ( $self, $configdbString, $dblog ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");

	print $dblog "Starting mongos servers\n";
	$logger->debug("Starting mongos servers");
	my @mongosSvrHostnames;
	my @mongosSvrPorts;

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
		push @mongosSvrHostnames, $appHostname;
		push @mongosSvrPorts, $self->internalPortMap->{ 'mongos-' . $appIpAddr };

		$hostsMongosStarted{$appIpAddr} = 1;

		my $appSshConnectString = $appServer->host->sshConnectString;
		print $dblog "Starting mongos on app server host $appHostname, configdb = $configdbString\n";
		$logger->debug("Starting mongos on app server host $appHostname, configdb = $configdbString");
		print $dblog "$appSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1\n";
		my $cmdOut = `$appSshConnectString mongos -f /etc/mongos.conf --configdb $configdbString 2>&1`;
		print $dblog $cmdOut;
		if ( !( $cmdOut =~ /success/ ) ) {
			print $dblog "Couldn't start mongos on $appHostname : $cmdOut\n";
			$logger->debug("Couldn't start mongos on $appHostname : $cmdOut\n");
			die "Couldn't start mongos on $appHostname : $cmdOut\n";
		}
		$logger->debug("Started mongos on app server host $appHostname, configdb = $configdbString");
		
		$appServer->portMap->{'mongos'} = $appServer->internalPortMap->{'mongos'};
	}

	return [$mongosSvrHostnames[0], $mongosSvrPorts[0]];
}

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("Configure mongodb");
	print $dblog "Configure MongoDB\n";

	my $workloadNum = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $suffix = "W${workloadNum}I${appInstanceNum}";
	
	my $hostname         = $self->host->hostName;
	my $configDir        = $self->getParamValue('configDir');
	my $appInstance      = $self->appInstance;	

	# Set up configuration files for the config servers if needed
	if (( $numShards > 0 ) && ($numReplicas == 0)) {
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
			elsif ( $inline =~ /replSetName:/ ) {
				print FILEOUT "    replSetName: auction$suffix-config\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;

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
			elsif ( $inline =~ /replSetName:/ ) {
				print FILEOUT "    replSetName: auction$suffix-config\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;

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
			elsif ( $inline =~ /replSetName:/ ) {
				print FILEOUT "    replSetName: auction$suffix-config\n";
			}
			else {
				print FILEOUT $inline;
			}
		}
		close FILEIN;
		close FILEOUT;
	}

	# Configure all of the hosts running a mongod	
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {
		my $sshConnectString = $nosqlServer->host->sshConnectString;
		my $scpConnectString = $nosqlServer->host->scpConnectString;
		my $scpHostString    = $nosqlServer->host->scpHostString;
		
		my $dir = $self->getParamValue('mongodbDataDir');
		`$sshConnectString mkdir -p $dir`;
		$dir = $self->getParamValue('mongodbC1DataDir');
		`$sshConnectString mkdir -p $dir`;
		$dir = $self->getParamValue('mongodbC2DataDir');
		`$sshConnectString mkdir -p $dir`;
		$dir = $self->getParamValue('mongodbC3DataDir');
		`$sshConnectString mkdir -p $dir`;
		
		if ( $nosqlServer->getParamValue('mongodbUseTHP') ) {
			my $cmdOut = `$sshConnectString \"echo always > /sys/kernel/mm/transparent_hugepage/enabled\"`;
			$cmdOut = `$sshConnectString \"echo always > /sys/kernel/mm/transparent_hugepage/defrag\"`;
		}
		else {

			# Turn off transparent huge pages
			my $cmdOut = `$sshConnectString \"echo never > /sys/kernel/mm/transparent_hugepage/enabled\"`;
			$cmdOut = `$sshConnectString \"echo never > /sys/kernel/mm/transparent_hugepage/defrag\"`;
		}
		
		if ( ( $numShards > 0 ) && ( $numReplicas > 0 ) ) {
			open( FILEIN, "$configDir/mongodb/mongod-shardReplica.conf" )
			  or die "Error opening $configDir/mongodb/mongod-shardReplica.conf:$!";
			open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /port:/ ) {
					print FILEOUT "    port: " . $nosqlServer->internalPortMap->{'mongod'} . "\n";
				}
				elsif ( $inline =~ /dbPath:/ ) {
					print FILEOUT "    dbPath: \"" . $nosqlServer->getParamValue('mongodbDataDir') . "\"\n";
				}
				else {
					print FILEOUT $inline;
				}
			}
			close FILEIN;
			close FILEOUT;
			`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
		}

		if ( ( $numShards > 0 ) && ( $numReplicas == 0 ) ) {
			open( FILEIN, "$configDir/mongodb/mongod-sharded.conf" )
			  or die "Error opening $configDir/mongodb/mongod-sharded.conf:$!";
			open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /port:/ ) {
					print FILEOUT "    port: " . $nosqlServer->internalPortMap->{'mongod'} . "\n";
				}
				elsif ( $inline =~ /dbPath:/ ) {
					print FILEOUT "    dbPath: \"" . $nosqlServer->getParamValue('mongodbDataDir') . "\"\n";
				}
				else {
					print FILEOUT $inline;
				}
			}
			close FILEIN;
			close FILEOUT;
			`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
			`$scpConnectString /tmp/mongoc1$suffix.conf root\@$scpHostString:/etc/mongoc1.conf`;
			`$scpConnectString /tmp/mongoc2$suffix.conf root\@$scpHostString:/etc/mongoc2.conf`;
			`$scpConnectString /tmp/mongoc3$suffix.conf root\@$scpHostString:/etc/mongoc3.conf`;
		}

		if ( ( $numShards == 0 ) && ( $numReplicas > 0 ) ) {
			open( FILEIN, "$configDir/mongodb/mongod-replica.conf" )
			  or die "Error opening $configDir/mongodb/mongod-replica.conf:$!";
			open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /port:/ ) {
					print FILEOUT "    port: " . $nosqlServer->internalPortMap->{'mongod'} . "\n";
				}
				elsif ( $inline =~ /dbPath:/ ) {
					print FILEOUT "    dbPath: \"" . $nosqlServer->getParamValue('mongodbDataDir') . "\"\n";
				}
				elsif ( $inline =~ /replSetName:/ ) {
					print FILEOUT "    replSetName: auction$suffix\n";
				}
				else {
					print FILEOUT $inline;
				}
			}
			close FILEIN;
			close FILEOUT;
			`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
		}

		if ( ( $numShards == 0 ) && ( $numReplicas == 0 ) ) {
			open( FILEIN, "$configDir/mongodb/mongod-unsharded.conf" )
			  or die "Error opening $configDir/mongodb/mongod-unsharded.conf:$!";
			open( FILEOUT, ">/tmp/mongod$suffix.conf" ) or die "Error opening /tmp/mongod$suffix.conf:$!";
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /port:/ ) {
					print FILEOUT "    port: " . $nosqlServer->internalPortMap->{'mongod'} . "\n";
				}
				elsif ( $inline =~ /dbPath:/ ) {
					print FILEOUT "    dbPath: \"" . $nosqlServer->getParamValue('mongodbDataDir') . "\"\n";
				}
				else {
					print FILEOUT $inline;
				}
			}
			close FILEIN;
			close FILEOUT;
			`$scpConnectString /tmp/mongod$suffix.conf root\@$scpHostString:/etc/mongod.conf`;
		}
		
	}

	if (( $numShards > 0 ) && ($numReplicas == 0)) {

		# configure the mongos processes
		my $appServersRef = $appInstance->getActiveServicesByType('appServer');
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

			my $scpConnectString = $appServer->host->scpConnectString;
			my $scpHostString    = $appServer->host->scpHostString;
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

	}

}

sub configureSharding {
	my ($self, $mongosHostname, $mongosPort, $applog)            = @_;
	my $console_logger   = get_logger("Console");
	my $logger = get_logger("Weathervane::Services::MongodbService");

	print $applog "Sharding MongoDB using mongos host $mongosHostname and port $mongosPort\n";
	$logger->debug("configureSharding Sharding MongoDB using mongos host $mongosHostname and port $mongosPort");	
	
	my $cmdString;
	my $cmdout;

	# Add the shards to the database
	my $nosqlServersRef = $self->appInstance->getActiveServicesByType('nosqlServer');
	foreach my $nosqlServer (@$nosqlServersRef) {
		my $hostname = $nosqlServer->getIpAddr();
		my $port     = $nosqlServer->portMap->{'mongod'};
		print $applog "Add $hostname as shard.\n";
		$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.addShard(\"$hostname:$port\"))'";
		my $cmdout = `$cmdString`;	
		print $applog "$cmdString\n";
		print $applog $cmdout;
	}

	# enable sharding for the databases
	print $applog "Enabling sharding for auction database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"auction\"))'";
	$cmdout = `$cmdString`;
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for bid database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"bid\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for attendanceRecord database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"attendanceRecord\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for imageInfo database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"imageInfo\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for auctionFullImages database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"auctionFullImages\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for auctionPreviewImages database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"auctionPreviewImages\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Enabling sharding for auctionThumbnailImages database.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.enableSharding(\"auctionThumbnailImages\"))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;

	# Create indexes for collections
	print $applog "Adding hashed index for userId in attendanceRecord Collection.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort attendanceRecord --eval 'printjson(db.attendanceRecord.ensureIndex({userId : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Adding hashed index for bidderId in bid Collection.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort bid --eval 'printjson(db.bid.ensureIndex({bidderId : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Adding hashed index for entityid in imageInfo Collection.\n";
	$cmdString =
	  "mongo --host $mongosHostname --port $mongosPort imageInfo --eval 'printjson(db.imageInfo.ensureIndex({entityid : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Adding hashed index for imageid in imageFull Collection.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort auctionFullImages --eval 'printjson(db.imageFull.ensureIndex({imageid : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Adding hashed index for imageid in imagePreview Collection.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort auctionPreviewImages --eval 'printjson(db.imagePreview.ensureIndex({imageid : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Adding hashed index for imageid in imageThumbnail Collection.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort auctionThumbnailImages --eval 'printjson(db.imageThumbnail.ensureIndex({imageid : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;

	# shard the collections
	print $applog "Sharding attendanceRecord collection on hashed userId.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"attendanceRecord.attendanceRecord\", {\"userId\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Sharding bid collection on hashed bidderId.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"bid.bid\",{\"bidderId\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Sharding imageInfo collection on hashed entityid.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"imageInfo.imageInfo\",{\"entityid\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Sharding imageFull collection on hashed imageid.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"auctionFullImages.imageFull\",{\"imageid\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Sharding imagePreview collection on hashed imageid.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"auctionPreviewImages.imagePreview\",{\"imageid\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;
	print $applog "Sharding imageThumbnail collection on hashed imageid.\n";
	$cmdString =
"mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.shardCollection(\"auctionThumbnailImages.imageThumbnail\",{\"imageid\" : \"hashed\"}))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;

	# disable the balancer
	print $applog "Disabling the balancer.\n";
	$cmdString = "mongo --host $mongosHostname --port $mongosPort --eval 'printjson(sh.setBalancerState(false))'";
	$cmdout = `$cmdString`;	
	print $applog "$cmdString\n";
	print $applog $cmdout;

}

sub configureReplicasAfterStart {
	my ($self, $applog)            = @_;
	my $console_logger   = get_logger("Console");

}

sub configureAfterStart {
	my ($self, $applog)            = @_;
	my $console_logger   = get_logger("Console");
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $name     = $self->getParamValue('dockerName');
	my $host = $self->host;
	my $hostname = $self->host->hostName;

	my $appInstance = $self->appInstance;

	my $nosqlServersRef = $appInstance->getActiveServicesByType('nosqlServer');
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

sub waitForMongodbReplicaSync {
	my ( $self, $nosqlHostname, $port, $runLog) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Services::MongodbService");

	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
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
	my $logger = get_logger("Weathervane::Services::MongodbService");
	my $serviceType     = $self->getParamValue('serviceType');
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	$logger->debug("setPortNumbers");
	$self->internalPortMap->{'mongod'}  = 27017 + $portOffset;
	$self->internalPortMap->{'mongos'}  = 27017;
	$self->internalPortMap->{'mongoc1'} = 27019;
	$self->internalPortMap->{'mongoc2'} = 27020;
	$self->internalPortMap->{'mongoc3'} = 27021;
	if ( ( $self->numNosqlShards > 0 ) && ( $self->numNosqlReplicas > 0 ) ) {
		$self->internalPortMap->{'mongod'} = 27018 + $portOffset;
	}
	elsif ( $self->numNosqlShards > 0 ) {
		$self->internalPortMap->{'mongod'} = 27018 + $portOffset;
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

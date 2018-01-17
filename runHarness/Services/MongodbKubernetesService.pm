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
package MongodbKubernetesService;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'MongoDB', );

has '+version' => ( default => '3.0.x', );

has '+description' => ( default => '', );

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
	
	super();
};

sub configure {
	my ( $self, $dblog, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::MongodbService");
	$logger->debug("Configure mongodb kubernetes");
	print $dblog "Configure MongoDB Kubernetes\n";

	my $namespace = $self->namespace;
	my $numShards = $self->numNosqlShards;
	my $numReplicas = $self->numNosqlReplicas;
	
	my $configDir        = $self->getParamValue('configDir');

	open( FILEIN,  "$configDir/kubernetes/mongodb.yaml" ) or die "$configDir/kubernetes/mongodb.yaml: $!\n";
	open( FILEOUT, ">/tmp/mongodb-$namespace.yaml" )             or die "Can't open file /tmp/mongodb-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /CLEARBEFORESTART:/ ) {
			print FILEOUT "  CLEARBEFORESTART: \"" . $self->clearBeforeStart . "\"\n";
		}
		elsif ( $inline =~ /NUMSHARDS:/ ) {
			print FILEOUT "  NUMSHARDS: \"$numShards\"\n";
		}
		elsif ( $inline =~ /NUMREPLICAS:/ ) {
			print FILEOUT "  NUMREPLICAS: \"$numReplicas\"\n";
		}
		elsif ( $inline =~ /ISCFGSVR:/ ) {
			print FILEOUT "  ISCFGSVR: \"0\"\n";
		}
		elsif ( $inline =~ /ISMONGOS:/ ) {
			print FILEOUT "  ISMONGOS: \"0\"\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;
}

sub clearDataAfterStart {
}


sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $name        = $self->getParamValue('dockerName');
	my $logger = get_logger("Weathervane::Services::MongodbKubernetesService");
	$logger->debug("clearDataBeforeStart for $name");
	
	$self->clearBeforeStart(1);
	
}

override 'sanityCheck' => sub {
	my ($self, $cleanupLogDir) = @_;
	my $console_logger = get_logger("Console");

	return 1;	
};

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;


}

sub cleanLogFiles {
	my ($self) = @_;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;


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

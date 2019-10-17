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
package CassandraKubernetesService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::KubernetesService;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has 'clearBeforeStart' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	my $name        = $self->name;
	$logger->debug("clearDataBeforeStart for $name");
	$self->clearBeforeStart(1);
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	my $cluster    = $self->host;
	my $name        = $self->name;

	$logger->debug("clearDataAfterStart for $name");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataCassandra-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From Cassandra\n";

	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne($self->getImpl(), "/clearAfterStart.sh", $self->namespace);
	if ($cmdFailed) {
		$logger->error("Error clearing old data as part of the data loading process.  Error = $cmdFailed");
	}
	close $applog;

}

sub configure {
	my ( $self, $dblog, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("Configure Cassandra kubernetes");
	print $dblog "Configure Cassandra Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');
	my $dataVolumeSize = $self->getParamValue("cassandraDataVolumeSize");
	my $numServers = $self->appInstance->getTotalNumOfServiceType('nosqlServer');

	open( FILEIN,  "$configDir/kubernetes/cassandra.yaml" ) or die "$configDir/kubernetes/cassandra.yaml: $!\n";
	open( FILEOUT, ">/tmp/cassandra-$namespace.yaml" )             or die "Can't open file /tmp/cassandra-$namespace.yaml: $!\n";	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /CLEARBEFORESTART:/ ) {
			print FILEOUT "  CLEARBEFORESTART: \"" . $self->clearBeforeStart . "\"\n";
		}
		elsif ( $inline =~ /CASSANDRA_SEEDS:/ ) {
			print FILEOUT "  CASSANDRA_SEEDS: \"cassandra-0.cassandra.${namespace}.svc.cluster.local\"\n";
		}
		elsif ( $inline =~ /CASSANDRA_CLUSTER_NAME:/ ) {
			print FILEOUT "  CASSANDRA_CLUSTER_NAME: \"$namespace\"\n";
		}
		elsif ( $inline =~ /CASSANDRA_MEMORY:/ ) {
			print FILEOUT "  CASSANDRA_MEMORY: \"" . $self->getParamValue('nosqlServerMem') ."\"\n";
		}
		elsif ( $inline =~ /CASSANDRA_CPUS:/ ) {
			print FILEOUT "  CASSANDRA_CPUS: \"" . $self->getParamValue('nosqlServerCpus') ."\"\n";
		}
		elsif ( $inline =~ /CASSANDRA_NUM_NODES:/ ) {
			print FILEOUT "  CASSANDRA_NUM_NODES: \"$numServers\"\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numServers\n";
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT $inline;
			}
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('nosqlServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('nosqlServerMem') . "\n";
			}
			if ($self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  limits:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('nosqlServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('nosqlServerMem') . "\n";						
			}

			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /lifecycle/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /(\s+)volumeClaimTemplates:/ ) {
			print FILEOUT $inline;
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /(\s+)name:\scassandra\-data/ ) {
					print FILEOUT $inline;
					while ( my $inline = <FILEIN> ) {
						if ( $inline =~ /(\s+)storageClassName:/ ) {
							my $storageClass = $self->getParamValue("cassandraDataStorageClass");
							print FILEOUT "${1}storageClassName: $storageClass\n";
							last;
						} elsif ($inline =~ /^(\s+)storage:/ ) {
							print FILEOUT "${1}storage: $dataVolumeSize\n";
						} else {
							print FILEOUT $inline;
						}	
					}
				} elsif ( $inline =~ /\-\-\-/ ) {
					print FILEOUT $inline;
					last;
				} else {
					print FILEOUT $inline;					
				}
			}
		}
		elsif ( $inline =~ /(\s+)\-\skey\:\swvw1i1/ ) {
			my $workloadNum    = $self->appInstance->workload->instanceNum;
			my $appInstanceNum = $self->appInstance->instanceNum;
			print FILEOUT "${1}- key: wvw${workloadNum}i${appInstanceNum}\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;
	
	# Delete the pvcs for postgresqlDataVolume  and postregresqlLogVolume
	# if the size doesn't match the requested size.  
	# This is to make sure that we are running the
	# correct configuration size
	my $cluster = $self->host;
	my $curPvcSize = $cluster->kubernetesGetSizeForPVC("cassandra-data-cassandra-0", $self->namespace);
	if (($curPvcSize ne "") && ($curPvcSize ne $dataVolumeSize)) {
		$cluster->kubernetesDeleteAllWithLabelAndResourceType("impl=cassandra,type=nosqlServer", "pvc", $self->namespace);
	}

}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne ($self->getImpl(), "perl /isUp.pl", $self->namespace );
	if ($cmdFailed) {
		return 0;
	} else {
		return 1;
	}
};

sub cleanData {
	my ($self, $users, $logHandle)   = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("cleanData");
	my $cluster = $self->host;
	my ($cmdFailed, $outString) = $cluster->kubernetesExecAll($self->getImpl(), "nodetool compact auction_event", $self->namespace );
	if ($cmdFailed) {
		$logger->warn("Compacting Cassandra nodes failed: $cmdFailed");
		return 0;
	} else {
		return 1;
	}	
}

sub waitForReady {
	my ($self)   = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("waitForReady");
	my $cluster = $self->host;
	my $iterations = 120;
	my $finished = 0;
	while (!$finished) {
		my ($cmdFailed, $outString) = $cluster->kubernetesExecOne($self->getImpl(), "nodetool compactionstats", $self->namespace );
		if ($cmdFailed) {
			$logger->warn("Getting compaction stats failed: $cmdFailed");
			return 0;
		} 
		if (!($outString =~ /progress/)) {
			$finished = 1;
			$logger->debug("compaction finished");
		} else {
			$iterations--;
			if ($iterations == 0) {
				$logger->warn("Compaction didn't finish in allocated time for workload "
				. $self->appInstance->workload->instanceNum . " appInstance " . $self->appInstance->instanceNum);
				return 0;
			}
			sleep 30;
		}
	}
	return 1;
}

sub cleanLogFiles {
	my ($self)            = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/cassandra-$namespace.yaml $destinationPath/. 2>&1`;

}


override 'startStatsCollection' => sub {
	my ( $self ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("startStatsCollection");

	my $cluster = $self->host;

};

override 'stopStatsCollection' => sub {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraKubernetesService");
	$logger->debug("stopStatsCollection");
	# Get interesting views on the pg_stats table
	my $hostname         = $self->host->name;
	my $cluster = $self->host;
	
};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("getStatsFiles");

	my $out = `cp /tmp/postgresql_stats_$hostname.txt $destinationPath/. 2>&1`;
	$out = `cp /tmp/postgresql_itemsSold_$hostname.txt $destinationPath/. 2>&1`;

};

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
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

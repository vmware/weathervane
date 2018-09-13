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
package PostgresqlKubernetesService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::KubernetesService;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'PostgreSQL 9.3', );

has '+version' => ( default => '9.3.5', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $name        = $self->getParamValue('dockerName');
	$logger->debug("clearDataBeforeStart for $name");
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $cluster    = $self->host;
	my $name        = $self->getParamValue('dockerName');

	$logger->debug("clearDataAfterStart for $name");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataPostgresql-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PostgreSQL\n";

	$cluster->kubernetesExecOne($self->getImpl(), "/clearAfterStart.sh", $self->namespace);
	close $applog;

}

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("Configure Postgresql kubernetes");
	print $dblog "Configure Postgresql Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $totalMemory;
	my $totalMemoryUnit;
	if (   ( exists $self->dockerConfigHashRef->{'memory'} )
		&&  $self->dockerConfigHashRef->{'memory'}  )
	{
		my $memString = $self->dockerConfigHashRef->{'memory'};
		$logger->debug("docker memory is set to $memString, using this to tune postgres.");
		$memString =~ /(\d+)\s*(\w)/;
		$totalMemory = $1;
		$totalMemoryUnit = $2;
	} else {
		$totalMemory = 0;
		$totalMemoryUnit = 0;		
	}
		

	open( FILEIN,  "$configDir/kubernetes/postgresql.yaml" ) or die "$configDir/kubernetes/postgresql.yaml: $!\n";
	open( FILEOUT, ">/tmp/postgresql-$namespace.yaml" )             or die "Can't open file /tmp/postgresql-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /POSTGRESTOTALMEM:/ ) {
			print FILEOUT "  POSTGRESTOTALMEM: \"$totalMemory\"\n";
		}
		elsif ( $inline =~ /POSTGRESTOTALMEMUNIT:/ ) {
			print FILEOUT "  POSTGRESTOTALMEMUNIT: \"$totalMemoryUnit\"\n";
		}
		elsif ( $inline =~ /POSTGRESSHAREDBUFFERS:/ ) {
			print FILEOUT "  POSTGRESSHAREDBUFFERS: \"" . $self->getParamValue('postgresqlSharedBuffers') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESSHAREDBUFFERSPCT:/ ) {
			print FILEOUT "  POSTGRESSHAREDBUFFERSPCT: \"" . $self->getParamValue('postgresqlSharedBuffersPct') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESEFFECTIVECACHESIZE:/ ) {
			print FILEOUT "  POSTGRESEFFECTIVECACHESIZE: \"" . $self->getParamValue('postgresqlEffectiveCacheSize') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESEFFECTIVECACHESIZEPCT:/ ) {
			print FILEOUT "  POSTGRESEFFECTIVECACHESIZEPCT: \"" . $self->getParamValue('postgresqlEffectiveCacheSizePct') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESMAXCONNECTIONS:\s+\"(\d+)\"/ ) {
			my $maxConn = $1;
			if ( $self->getParamValue('postgresqlMaxConnections') ) {
				$maxConn = $self->getParamValue('postgresqlMaxConnections');
			}
			print FILEOUT "  POSTGRESMAXCONNECTIONS: \"$maxConn\"\n";
		}
		elsif ( $inline =~ /\s\s\s\s\s\s\s\s\s\s\s\scpu:/ ) {
			print FILEOUT "            cpu: " . $self->getParamValue('dbServerCpus') . "\n";
		}
		elsif ( $inline =~ /\s\s\s\s\s\s\s\s\s\s\s\smemory:/ ) {
			print FILEOUT "            memory: " . $self->getParamValue('dbServerMem') . "\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			print FILEOUT "${1}$version\n";
		}
		elsif ( $inline =~ /(\s+)volumeClaimTemplates:/ ) {
			print FILEOUT $inline;
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /(\s+)name:\spostgresql\-data/ ) {
					print FILEOUT $inline;
					while ( my $inline = <FILEIN> ) {
						if ( $inline =~ /(\s+)storageClassName:/ ) {
							my $storageClass = $self->getParamValue("postgresqlDataStorageClass");
							print FILEOUT "${1}storageClassName: $storageClass\n";
							last;
						} else {
							print FILEOUT $inline;
						}	
					}
				} elsif ( $inline =~ /(\s+)name:\spostgresql\-logs/ ) {
					print FILEOUT $inline;
					while ( my $inline = <FILEIN> ) {
						if ( $inline =~ /(\s+)storageClassName:/ ) {
							my $storageClass = $self->getParamValue("postgresqlLogStorageClass");
							print FILEOUT "${1}storageClassName: $storageClass\n";
							last;
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
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;
	
		

}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	$cluster->kubernetesExecOne ($self->getImpl(), "/usr/pgsql-9.3/bin/pg_isready -h 127.0.0.1 -p 5432", $self->namespace );
	my $exitValue=$? >> 8;
	if ($exitValue) {
		return 0;
	} else {
		return 1;
	}
};

sub cleanLogFiles {
	my ($self)            = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/postgresql-$namespace.yaml $destinationPath/. 2>&1`;

}


override 'startStatsCollection' => sub {
	my ( $self ) = @_;
	my $hostname         = $self->host->hostName;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("startStatsCollection");

	my $cluster = $self->host;
	# Reset the stats tables
	$cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select pg_stat_reset();'", $self->namespace );
	$cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\"select pg_stat_reset_shared('bgwriter');'\\\"", $self->namespace );

	open( STATS, ">/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	my $cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, max items sold per auction = $cmdout";
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, min items sold per auction = $cmdout";
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, avg items sold per auction = $cmdout";
	close STATS;

};

override 'stopStatsCollection' => sub {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("stopStatsCollection");
	# Get interesting views on the pg_stats table
	my $hostname         = $self->host->hostName;
	my $cluster = $self->host;
	
	open( STATS, ">/tmp/postgresql_stats_$hostname.txt" ) or die "Error opening /tmp/postgresql_stats_$hostname.txt:$!";
	
	my $cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_activity;'", $self->namespace );
	print STATS "$cmdout\n";
	
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_bgwriter;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_database;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_database_conflicts;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_user_tables;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_statio_user_tables;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_user_indexes;'", $self->namespace );
	print STATS "$cmdout\n";

	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_statio_user_indexes;'", $self->namespace );
	print STATS "$cmdout\n";

	close STATS;

	open( STATS, ">>/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, max items sold per auction = $cmdout";
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, min items sold per auction = $cmdout";
	$cmdout = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	print STATS "After rampUp, avg items sold per auction = $cmdout";
	close STATS;

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("getStatsFiles");

	my $out = `cp /tmp/postgresql_stats_$hostname.txt $destinationPath/. 2>&1`;
	$out = `cp /tmp/postgresql_itemsSold_$hostname.txt $destinationPath/. 2>&1`;

};

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"postgresqlEffectiveCacheSize"} = $self->getParamValue('postgresqlEffectiveCacheSize');
	$csv{"postgresqlSharedBuffers"}      = $self->getParamValue('postgresqlSharedBuffers');
	$csv{"postgresqlMaxConnections"}     = $self->getParamValue('postgresqlMaxConnections');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();
	return \%csv;
}

# Get the max number of users loaded in the database
sub getMaxLoadedUsers {
	my ($self) = @_;
	
	my $cluster = $self->host;
	my $impl = $self->getImpl();
	my $maxUsers = $cluster->kubernetesExecOne($impl, "sudo -u postgres psql -U auction  -t -q --command=\"select maxusers from dbbenchmarkinfo;\"", $self->namespace);
	chomp($maxUsers);
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

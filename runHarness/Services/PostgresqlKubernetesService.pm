# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $name        = $self->name;
	$logger->debug("clearDataBeforeStart for $name");
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $cluster    = $self->host;
	my $name        = $self->name;

	$logger->debug("clearDataAfterStart for $name");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataPostgresql-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PostgreSQL\n";

	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne($self->getImpl(), "/clearAfterStart.sh", $self->namespace);
	if ($cmdFailed) {
		$logger->error("Error clearing old data as part of the data loading process.  Error = $cmdFailed");
	}
	close $applog;

}

sub configure {
	my ( $self, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("Configure Postgresql kubernetes");

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $memString = $self->getParamValue('dbServerMem');
	$logger->debug("dbServerMem is set to $memString, using this to tune postgres.");
	$memString =~ /(\d+)\s*(\w+)/;
	my $totalMemory = $1;
	my $totalMemoryUnit = $2;
	if (lc($totalMemoryUnit) eq "gi") {
		$totalMemoryUnit = "GB";
	} elsif (lc($totalMemoryUnit) eq "mi") {
		$totalMemoryUnit = "MB";
	} elsif (lc($totalMemoryUnit) eq "ki") {
		$totalMemoryUnit = "kB";
	}

	my $volumeSize = $self->getParamValue('postgresqlVolumeSize');
	my $numReplicas = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));

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
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT $inline;
			}
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('dbServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('dbServerMem') . "\n";
			}
			if ($self->getParamValue('useKubernetesLimits')) {
				my $limitsExpansion = 1 + (0.01 *  $self->getParamValue('limitsExpansionPct'));
				my $cpuLimit = $self->expandK8sCpu($self->getParamValue('dbServerCpus'), $limitsExpansion);
				my $memLimit = $self->expandK8sMem($self->getParamValue('dbServerMem'), $limitsExpansion);
				print FILEOUT "$indent  limits:\n";
				print FILEOUT "$indent    cpu: " . $cpuLimit . "\n";
				print FILEOUT "$indent    memory: " . $memLimit . "\n";	
			}
			
			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /readinessProbe/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+)initialDelaySeconds:/ ) {
	        # Randomize the initialDelaySeconds on the readiness probes
			my $indent = $1;
			my $delay = int(rand(60)) + 1;
			print FILEOUT "${indent}initialDelaySeconds: $delay\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numReplicas\n";
		}
		elsif ( $inline =~ /^(\s+)affinity\:/ )  {
			print FILEOUT $inline;
			# Add any pod affinity rules controlled by parameters
			print FILEOUT $serviceParamsHashRef->{"affinityRuleText"};
			do {
				$inline = <FILEIN>;
				if ( $inline =~ /^(\s+)requiredDuringScheduling/ ) {
					my $indent = $1;
					print FILEOUT $inline;
					do {
						$inline = <FILEIN>;
						print FILEOUT $inline;			
					} while(!($inline =~ /matchExpressions/));
					if ($self->getParamValue('instanceNodeLabels')) {
						my $workloadNum    = $self->appInstance->workload->instanceNum;
						my $appInstanceNum = $self->appInstance->instanceNum;
    	        	    print FILEOUT "${indent}    - key: wvauctionw${workloadNum}i${appInstanceNum}\n";
        	        	print FILEOUT "${indent}      operator: Exists\n";
					} 
					if ($self->getParamValue('serviceTypeNodeLabels')) {
    	        	    print FILEOUT "${indent}    - key: wv${serviceType}\n";
        	        	print FILEOUT "${indent}      operator: Exists\n";
					} 
				} else {
					print FILEOUT $inline;					
				}
			} while(!($inline =~ /containers/));
		}
		elsif ( $inline =~ /(\s+)volumeClaimTemplates:/ ) {
			print FILEOUT $inline;
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /(\s+)name:\spostgresql/ ) {
					print FILEOUT $inline;
					while ( my $inline = <FILEIN> ) {
						if ( $inline =~ /(\s+)storageClassName:/ ) {
							my $storageClass = $self->getParamValue("postgresqlStorageClass");
							print FILEOUT "${1}storageClassName: $storageClass\n";
							last;
						} elsif ($inline =~ /^(\s+)storage:/ ) {
							print FILEOUT "${1}storage: $volumeSize\n";
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
	
	# Delete the pvcs for postgresql
	# if the size doesn't match the requested size.  
	# This is to make sure that we are running the
	# correct configuration size
	my $cluster = $self->host;
	my $curPvcSize = $cluster->kubernetesGetSizeForPVC("postgresql-postgresql-0", $self->namespace);
	if (($curPvcSize ne "") && ($curPvcSize ne $volumeSize)) {
		$cluster->kubernetesDelete("pvc", "postgresql-postgresql-0", $self->namespace);
	}	
}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	my $numServers = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	if ($cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "/usr/bin/pg_isready -h postgresql-0 -p 5432", $self->namespace, '', $numServers)) {
		return 1;
	}
	return 0;
};

sub cleanData {
	my ($self, $users, $logHandle)   = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("cleanData");
	my $cluster = $self->host;
	my ($cmdFailed, $outString) = $cluster->kubernetesExecAll($self->getImpl(), "/cleanup.sh", $self->namespace );
	if ($cmdFailed) {
		$logger->warn("Cleanup of Postgresql nodes failed: $cmdFailed");
		return 0;
	} else {
		return 1;
	}	
}

sub cleanLogFiles {
	my ($self)            = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/postgresql-$namespace.yaml $destinationPath/. 2>&1`;

}


override 'startStatsCollection' => sub {
	my ( $self ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("startStatsCollection");

	my $cluster = $self->host;
	# Reset the stats tables
	my ($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select pg_stat_reset();'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	}
	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\"select pg_stat_reset_shared('bgwriter');'\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error resetting PostgreSQL stats.  Error = $cmdFailed");
	}

	open( STATS, ">/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	}
	print STATS "After rampUp, max items sold per auction = $cmdout";

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	}
	print STATS "After rampUp, min items sold per auction = $cmdout";

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	}
	print STATS "After rampUp, avg items sold per auction = $cmdout";
	close STATS;

};

override 'stopStatsCollection' => sub {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("stopStatsCollection");
	# Get interesting views on the pg_stats table
	my $hostname         = $self->host->name;
	my $cluster = $self->host;
	
	open( STATS, ">/tmp/postgresql_stats_$hostname.txt" ) or die "Error opening /tmp/postgresql_stats_$hostname.txt:$!";
	
	my ($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_activity;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}
	
	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_bgwriter;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_database;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_database_conflicts;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_user_tables;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_statio_user_tables;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_stat_user_indexes;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command='select * from pg_statio_user_indexes;'", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "$cmdout\n";
	}

	close STATS;

	open( STATS, ">>/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "After rampUp, max items sold per auction = $cmdout";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "After rampUp, max items sold per auction = $cmdout";
	}

	($cmdFailed, $cmdout) = $cluster->kubernetesExecOne ($self->getImpl(), "psql -U auction --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"", $self->namespace );
	if ($cmdFailed) {
		$logger->error("Error collecting PostgreSQL stats.  Error = $cmdFailed");
	} else {
		print STATS "After rampUp, avg items sold per auction = $cmdout";
	}
	close STATS;

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
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	
	my $cluster = $self->host;
	my $impl = $self->getImpl();
	my ($cmdFailed, $maxUsers) = $cluster->kubernetesExecOne($impl, "sudo -u postgres psql -U auction  -t -q --command=\"select maxusers from dbbenchmarkinfo;\"", $self->namespace);
	if ($cmdFailed) {
		$logger->error("Error Getting maxLoadedUsers from PostgreSQL.  Error = $cmdFailed");
	}
	chomp($maxUsers);
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

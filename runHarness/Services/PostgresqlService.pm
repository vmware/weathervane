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
package PostgresqlService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::Service;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'PostgreSQL 9', );

has '+version' => ( default => '9.4', );

has '+description' => ( default => '', );
override 'initialize' => sub {
	my ( $self, $numDbServers ) = @_;

	super();
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	$logger->debug("stop PostgresqlService");

	my $hostname              = $self->host->hostName;
	my $logName               = "$logPath/StopPostgresql-$hostname.log";
	my $sshConnectString      = $self->host->sshConnectString;
	my $postgresqlServiceName = $self->getParamValue('postgresqlServiceName');
	my $postgresqlHome        = $self->getParamValue('postgresqlHome');

	my $dblog;
	open( $dblog, ">$logName" ) or die "Error opening $logName:$!";

	# first make sure the db is running.  If so, stop it.
	if ( $self->isRunning($dblog) ) {
		print $dblog " DB is running . Stopping DB \n ";
		my $cmdOut = `$sshConnectString service $postgresqlServiceName stop 2>&1`;
	}

	# Clean up the logs
	my $dataDir = $self->getParamValue('postgresqlDataDir');
	print $dblog "Reseting the log files after shutdown\n";
	my $cmdout = `$sshConnectString \"rm -f $dataDir/postmaster.pid 2>&1\"`;
	print $dblog $cmdout;
	$cmdout = `$sshConnectString \"runuser -l postgres -c \'$postgresqlHome/bin/pg_resetxlog -f $dataDir\' 2>&1\"`;
	print $dblog $cmdout;

	close $dblog;
}

sub start {
	my ( $self, $logPath ) = @_;
	my $logger      = get_logger("Weathervane::Services::PostgresqlService");
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	$logger->debug( "Starting postgresql on host ", $self->host->hostName, ", port is ", $self->internalPortMap->{$impl} );

	my $hostname              = $self->host->hostName;
	my $logName               = "$logPath/StartPostgresql-$hostname.log";
	my $sshConnectString      = $self->host->sshConnectString;
	my $postgresqlServiceName = $self->getParamValue('postgresqlServiceName');

	my $dblog;
	open( $dblog, " > $logName " ) or die " Error opening $logName: $!";
	if ( !$self->isRunning($dblog) ) {
		print $dblog "Starting DB\n";
		my $cmdOut = `$sshConnectString service $postgresqlServiceName start 2>&1`;
	}
	
	$self->portMap->{$impl} = $self->internalPortMap->{$impl};

	
	# Force a vacuum and a checkpoint
	$self->doVacuum($dblog);

	
	# Force a vacuum and a checkpoint
	$self->doVacuum($dblog);

	$self->registerPortsWithHost();
	$self->host->startNscd();

	close $dblog;
}

sub clearDataBeforeStart {
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $hostname    = $self->host->hostName;
	my $logName     = "$logPath/ClearDataPostgresql-$hostname.log";
	my $dbScriptDir = $self->getParamValue('dbScriptDir');

	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->portMap->{$impl};

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PortgreSQL\n";

	# Make sure the database exists
	my $cmdout =
`PGPASSWORD=\"auction\" psql -p $port -U auction -d postgres -h $hostname -f $dbScriptDir/auction_postgresql_database.sql`;
	print $applog $cmdout;

	# Make sure the tables exist and are empty
	$cmdout =
`PGPASSWORD=\"auction\" psql -p $port -U auction -d auction -h $hostname -f $dbScriptDir/auction_postgresql_tables.sql`;
	print $applog $cmdout;

	# Add the foreign key constraints
	$cmdout =
`PGPASSWORD=\"auction\" psql -p $port -U auction -d auction -h $hostname -f $dbScriptDir/auction_postgresql_constraints.sql`;
	print $applog $cmdout;

	# Add the indices
	$cmdout =
`PGPASSWORD=\"auction\" psql -p $port -U auction -d auction -h $hostname -f $dbScriptDir/auction_postgresql_indices.sql`;
	print $applog $cmdout;
	close $applog;

}

sub doVacuum {
	my ( $self, $fileout ) = @_;
	my $hostname    = $self->host->hostName;
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->portMap->{$impl};

	my $cmdout =
	  `PGPASSWORD=\"auction\"  psql -p $port -U auction -d auction -h $hostname -c \"vacuum analyze;\"`;
	print $fileout
	  "PGPASSWORD=\"auction\"  psql -p $port -U auction -d auction -h $hostname -c \"vacuum analyze;\"\n";
	print $fileout $cmdout;
	$cmdout = `PGPASSWORD=\"auction\"  psql -p $port -U auction -d auction -h $hostname -c \"checkpoint;\"`;
	print $fileout
	  "PGPASSWORD=\"postgres\"  psql -p $port -U postgres -d auction -h $hostname -c \"checkpoint;\"\n";
	print $fileout $cmdout;

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

	my $sshConnectString      = $self->host->sshConnectString;
	my $postgresqlServiceName = $self->getParamValue('postgresqlServiceName');
	my $cmdOut                = `$sshConnectString service $postgresqlServiceName status 2>&1`;
	print $fileout $cmdOut;
	if ( ( $cmdOut =~ /is running/ ) || ( $cmdOut =~ /\sactive\s+\(/ ) ) {
		return 1;
	}
	else {
		return 0;
	}

}

sub setPortNumbers {
	my ($self) = @_;
	
	my $logger = get_logger("Weathervane::Services::PostgresqlService");

	my $serviceType    = $self->getParamValue('serviceType');
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;
	my $impl           = $self->getParamValue( $serviceType . "Impl" );
	$self->internalPortMap->{$impl} = $self->getParamValue('postgresqlPort') + $portOffset;

	$logger->debug(
		"Setting postgresql port to ", $self->internalPortMap->{$impl},
		" for postgresql on host ",   $self->host->hostName
	);
}

sub setExternalPortNumbers {
	my ($self) = @_;
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	$self->portMap->{$impl} = $self->internalPortMap->{$impl}
	
}
	
sub isBackupAvailable {
	my ( $self, $backupDirPath, $applog ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");

	my $sshConnectString = $self->host->sshConnectString;

	my $chkOut = `$sshConnectString \"[ -d $backupDirPath ] && echo 'found'\"`;
	if ( !( $chkOut =~ /found/ ) ) {
		return 0;
	}
	$chkOut = `$sshConnectString \"[ \\\"$(ls -A $backupDirPath)\\\" ] && echo \\\"Full\\\" || echo \\\"Empty\\\"\"`;
	if ( $chkOut =~ /Empty/ ) {
		return 0;
	}

	return 1;

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $logger           = get_logger("Weathervane::Services::PostgresqlService");
	my $server           = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');

	# make sure the directory structure is correct.  It may have been modified when running dockerized
	my $dataDir = $self->getParamValue('postgresqlDataDir');
	my $logDir  = $self->getParamValue('postgresqlLogDir');
	$logger->debug("$sshConnectString chown -R postgres:postgres $dataDir");
	my $out = `$sshConnectString chown -R postgres:postgres $dataDir`;
	$logger->debug($out);
	$logger->debug("$sshConnectString chown -R postgres:postgres $logDir");
	$out = `$sshConnectString chown -R postgres:postgres $logDir`;
	$logger->debug($out);
	$logger->debug("$sshConnectString rm -f $dataDir/pg_xlog");
	$out = `$sshConnectString rm -f $dataDir/pg_xlog`;
	$logger->debug($out);
	$logger->debug("$sshConnectString ln -s $logDir $dataDir/pg_xlog");
	$out = `$sshConnectString ln -s $logDir $dataDir/pg_xlog`;
	$logger->debug($out);
	$logger->debug("$sshConnectString rm -f /var/lib/pgsql/9.3/data");
	$out = `$sshConnectString rm -f /var/lib/pgsql/9.3/data`;
	$logger->debug($out);
	$logger->debug("$sshConnectString ln -s $dataDir /var/lib/pgsql/9.3/data");
	$out = `$sshConnectString ln -s $dataDir /var/lib/pgsql/9.3/data`;
	$logger->debug($out);


	

	# Modify the postgresql.conf and
	# then copy the new version to the DB
	open( FILEIN,  "$configDir/postgresql/postgresql.conf" );
	open( FILEOUT, ">/tmp/postgresql$suffix.conf" );
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^\s*shared_buffers\s*=\s*(.*)/ ) {
			my $origValue = $1;

			# If postgresqlSharedBuffers was set, then use it
			# as the value. Otherwise, if postgresqlSharedBuffersPct
			# was set, use that percentage of total memory,
			# otherwise use what was in the original file
			if ( $self->getParamValue('postgresqlSharedBuffers') ) {

				#					print $self->meta->name
				#					  . " In postgresqlService::configure setting shared_buffers to "
				#					  . $self->postgresqlSharedBuffers . "\n";
				print FILEOUT "shared_buffers = " . $self->getParamValue('postgresqlSharedBuffers') . "\n";

			}
			elsif ( $self->getParamValue('postgresqlSharedBuffersPct') ) {

				# Find the total amount of memory on the host
				my $out = `$sshConnectString cat /proc/meminfo`;
				$out =~ /MemTotal:\s+(\d+)\s+(\w)/;
				my $totalMem     = $1;
				my $totalMemUnit = $2;

				if ( uc($totalMemUnit) eq "K" ) {
					$totalMemUnit = "kB";
				}
				elsif ( uc($totalMemUnit) eq "M" ) {
					$totalMemUnit = "MB";
				}
				elsif ( uc($totalMemUnit) eq "G" ) {
					$totalMemUnit = "GB";
				}

				my $bufferMem = floor( $totalMem * $self->getParamValue('postgresqlSharedBuffersPct') );

				if ( $bufferMem > $totalMem ) {
					die "postgresqlSharedBuffersPct must be less than 1";
				}

				#					print $self->meta->name
				#					  . " In postgresqlService::configure setting shared_buffers to $bufferMem$totalMemUnit\n";
				print FILEOUT "shared_buffers = $bufferMem$totalMemUnit\n";

				$self->setParamValue( 'postgresqlSharedBuffers', $bufferMem . $totalMemUnit );
			}
			else {
				print FILEOUT $inline;
				$self->setParamValue( 'postgresqlSharedBuffers', $origValue );
			}
		}
		elsif ( $inline =~ /^\s*effective_cache_size\s*=\s*(.*)/ ) {
			my $origValue = $1;

			# If postgresqlEffectiveCacheSize was set, then use it
			# as the value. Otherwise, if postgresqlEffectiveCacheSizePct
			# was set, use that percentage of total memory,
			# otherwise use what was in the original file
			if ( $self->getParamValue('postgresqlEffectiveCacheSize') ) {

				#					print $self->meta->name
				#					  . " In postgresqlService::configure setting effective_cache_size to "
				#					  . $self->postgresqlEffectiveCacheSize . "\n";
				print FILEOUT "effective_cache_size = " . $self->getParamValue('postgresqlEffectiveCacheSize') . "\n";

			}
			elsif ( $self->getParamValue('postgresqlEffectiveCacheSizePct') ) {

				# Find the total amount of memory on the host
				my $out = `$sshConnectString cat /proc/meminfo`;
				$out =~ /MemTotal:\s+(\d+)\s+(\w)/;
				my $totalMem     = $1;
				my $totalMemUnit = $2;

				if ( uc($totalMemUnit) eq "K" ) {
					$totalMemUnit = "kB";
				}
				elsif ( uc($totalMemUnit) eq "M" ) {
					$totalMemUnit = "MB";
				}
				elsif ( uc($totalMemUnit) eq "G" ) {
					$totalMemUnit = "GB";
				}

				my $bufferMem = floor( $totalMem * $self->getParamValue('postgresqlEffectiveCacheSizePct') );

				if ( $bufferMem > $totalMem ) {
					die "postgresqlEffectiveCacheSizePct must be less than 1";
				}

				#					print $self->meta->name
				#					  . " In postgresqlService::configure setting effective_cache_size to $bufferMem$totalMemUnit\n";
				print FILEOUT "effective_cache_size = $bufferMem$totalMemUnit\n";
				$self->setParamValue( 'postgresqlEffectiveCacheSize', $bufferMem . $totalMemUnit );

			}
			else {
				print FILEOUT $inline;
				$self->setParamValue( 'postgresqlEffectiveCacheSize', $origValue );
			}
		}
		elsif ( $inline =~ /^\s*max_connections\s*=\s*(\d*)/ ) {
			my $origValue = $1;
			if ( $self->getParamValue('postgresqlMaxConnections') ) {
				print FILEOUT "max_connections = " . $self->getParamValue('postgresqlMaxConnections') . "\n";

			}
			else {
				print FILEOUT $inline;
				$self->setParamValue( 'postgresqlMaxConnections', $origValue );
			}
		}
		elsif ( $inline =~ /^\s*port\s*=\s*(\d*)/ ) {
			my $serviceType = $self->getParamValue('serviceType');
			my $impl        = $self->getParamValue( $serviceType . "Impl" );
			$logger->debug( "Configuring postgresql port on host ",
				$self->host->hostName, " to be ", $self->internalPortMap->{$impl} );
			print FILEOUT "port = '" . $self->internalPortMap->{$impl} . "'\n";
		}
		elsif ( $inline =~ /data_directory/ ) {
			print FILEOUT "data_directory = '" . $self->getParamValue('postgresqlDataDir') . "'\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	close FILEIN;
	close FILEOUT;

	my $postgresqlConfDir = $self->getParamValue('postgresqlConfDir');
	`$scpConnectString /tmp/postgresql$suffix.conf root\@$scpHostString:$postgresqlConfDir/postgresql.conf`;

}

sub stopStatsCollection {
	my ($self)           = @_;
	my $console_logger = get_logger("Console");
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $serviceType      = $self->getParamValue('serviceType');
	my $impl             = $self->getParamValue( $serviceType . "Impl" );
	my $port             = $self->portMap->{$impl};

	# Get interesting views on the pg_stats table
	open( STATS, ">/tmp/postgresql_stats_$hostname.txt" ) or die "Error opening /tmp/postgresql_stats_$hostname.txt:$!";
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_activity;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_bgwriter;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_database;'\"`;
	print STATS
	  `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_database_conflicts;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_user_tables;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_statio_user_tables;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_stat_user_indexes;'\"`;
	print STATS `$sshConnectString \" psql -p $port -U auction --command='select * from pg_statio_user_indexes;'\"`;
	close STATS;

	open( STATS, ">>/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	my $cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After steady-state, max items sold per auction = $cmdout";
	$cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After steady-state, min items sold per auction = $cmdout";
	$cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After steady-state, avg items sold per auction = $cmdout";
	close STATS;


}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $console_logger = get_logger("Console");
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $serviceType      = $self->getParamValue('serviceType');
	my $impl             = $self->getParamValue( $serviceType . "Impl" );
	my $port             = $self->portMap->{$impl};

	# Reset the stats tables
	`$sshConnectString \" psql -p $port -U auction --command='select pg_stat_reset();'\"`;
	`$sshConnectString \" psql -p $port -U auction --command=\\\"select pg_stat_reset_shared('bgwriter');\\\"\"`;

	open( STATS, ">/tmp/postgresql_itemsSold_$hostname.txt" ) or die "Error opening /tmp/postgresql_itemsSold_$hostname.txt:$!";
	my $cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select max(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After rampUp, max items sold per auction = $cmdout";
	$cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select min(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After rampUp, min items sold per auction = $cmdout";
	$cmdout = `$sshConnectString \" psql -p $port -U auction -t --command=\\\" select avg(cnt) from (select count(i.id) as cnt from auction a join item i on a.id=i.auction_id where a.activated=true and i.state='SOLD' group by a.id) as cnt;\\\"\"`;
	print STATS "After rampUp, avg items sold per auction = $cmdout";
	close STATS;
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

	my $out = `cp /tmp/postgresql_stats_$hostname.txt $destinationPath/. 2>&1`;
	$out = `cp /tmp/postgresql_itemsSold_$hostname.txt $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

	my $out = `rm -f /tmp/postgresql_stats_$hostname.txt 2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $postgresqlDataDir = $self->getParamValue('postgresqlDataDir');
	my $sshConnectString = $self->host->sshConnectString;

	my $date = `$sshConnectString date +%a`;
	chomp($date);

	my $maxLogLines = $self->getParamValue('maxLogLines');
	$self->checkSizeAndTruncate("$postgresqlDataDir/pg_log", "postgresql-$date.csv", $maxLogLines);

	`$scpConnectString root\@$scpHostString:$postgresqlDataDir/pg_log/postgresql-$date.csv $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	$logger->debug("cleanLogFiles");

	my $sshConnectString  = $self->host->sshConnectString;
	my $postgresqlDataDir = $self->getParamValue('postgresqlDataDir');

	my $cmdOut = `$sshConnectString \"rm -f $postgresqlDataDir/serverlog 2>&1\"`;
	$cmdOut = `$sshConnectString \"rm -f $postgresqlDataDir/pg_log/* 2>&1\"`;
}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $postgresqlDataDir = $self->getParamValue('postgresqlDataDir');
	`mkdir -p $destinationPath`;

	`$scpConnectString root\@$scpHostString:$postgresqlDataDir/postgresql.conf $destinationPath/.`;

}

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
	
	my $hostname = $self->host->hostName;
	my $impl = $self->getImpl() ;
	my $port             = $self->portMap->{$impl};
	my $maxUsers = `psql --host $hostname --port $port -U auction  -t -q --command="select maxusers from dbbenchmarkinfo;"`;
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

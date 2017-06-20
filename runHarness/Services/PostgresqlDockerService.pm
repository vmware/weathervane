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
package PostgresqlDockerService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::Service;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'PostgreSQL 9.3', );

has '+version' => ( default => '9.3.5', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub stop {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StopPostgresqlDocker-$hostname-$name-$time.log";
	my $logger = get_logger("Weathervane::Services::PostgresqlDockerService");
	$logger->debug("stop PostgresqlDockerService");

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $applog, $name );

	close $applog;
}

override 'create' => sub {
	my ( $self, $logPath ) = @_;

	my $name             = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $impl             = $self->getImpl();
	my $logDir           = $self->getParamValue('postgresqlLogDir');
	my $sshConnectString = $self->host->sshConnectString;

	#	`$sshConnectString chmod -R 777 $logDir`;

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name-$time.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Map the log and data volumes to the appropriate host directories
	my %volumeMap;
	$volumeMap{"/mnt/dbData/postgresql"} = $self->getParamValue('postgresqlDataDir');
	$volumeMap{$logDir} = $logDir;

	my %envVarMap;
	$envVarMap{"POSTGRES_USER"}     = "auction";
	$envVarMap{"POSTGRES_PASSWORD"} = "auction";

	# Create the container
	my %portMap;
	my $directMap = 0;

	my $cmd        = "";
	my $entryPoint = "";

	foreach my $key ( keys %{ $self->internalPortMap } ) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	$self->host->dockerRun( $applog, $name, $impl, $directMap, \%portMap, \%volumeMap, \%envVarMap,
		$self->dockerConfigHashRef, $entryPoint, $cmd, $self->needsTty );

	close $applog;
};

sub start {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StartPostgresqlDocker-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my $portMapRef = $self->host->dockerReload( $applog, $name );

	if ( $self->getParamValue('dockerNet') eq "host" ) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{ $self->getImpl() } = $self->internalPortMap->{ $self->getImpl() };
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{ $self->getImpl() } = $portMapRef->{ $self->internalPortMap->{ $self->getImpl() } };
	}
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName  = "$logPath/RemovePostgresqlDocker-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove( $applog, $name );

	close $applog;
};

sub clearDataBeforeStart {
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->internalPortMap->{$impl};

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataPostgresql-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PortgreSQL\n";

	# Make sure the database exists and is empty
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction -d postgres -f /dbScripts/auction_postgresql_database.sql" );

	# Make sure the tables exist and are empty
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction -d auction -f /dbScripts/auction_postgresql_tables.sql" );

	# Add the foreign key constraints
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction -d auction -f /dbScripts/auction_postgresql_constraints.sql" );

	# Add the indices
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql" );

	close $applog;

}

sub doVacuum {
	my ( $self, $fileout ) = @_;
	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->internalPortMap->{$impl};

	$self->host->dockerExec( $fileout, $name, "psql -p $port -U auction -d auction -c \"vacuum analyze;\"" );
	$self->host->dockerExec( $fileout, $name, "psql -p $port -U auction -d auction -c \"checkpoint;\"" );

}

sub isUp {
	my ( $self, $fileout ) = @_;
	return $self->isRunning($fileout);

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->getParamValue('dockerName');

	return $self->host->dockerIsRunning( $fileout, $name );

}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType    = $self->getParamValue('serviceType');
	my $impl           = $self->getParamValue( $serviceType . "Impl" );
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;
	$self->internalPortMap->{$impl} = $self->getParamValue('postgresqlPort') + $portOffset;
}

sub setExternalPortNumbers {
	my ($self) = @_;
	
	my $name = $self->getParamValue('dockerName');
	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->getParamValue('dockerNet') eq "host" ) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{ $self->getImpl() } = $self->internalPortMap->{ $self->getImpl() };
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{ $self->getImpl() } = $portMapRef->{ $self->internalPortMap->{ $self->getImpl() } };
	}
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $configDir        = $self->getParamValue('configDir');
	my $name             = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/ConfigurePostgresDocker-$hostname-$name-$time.log";
	my $logger           = get_logger("Weathervane::Services::PostgresqlDockerService");

	# Need to start and stop postgres before configuring to make sure that
	# the database files are populated on the first use.
	#		$self->start($logPath);
	#		sleep 15;
	#		$self->stop($logPath);

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $totalMem;
	my $totalMemUnit;
	if (   ( exists $self->dockerConfigHashRef->{'memory'} )
		&&  $self->dockerConfigHashRef->{'memory'}  )
	{
		my $memString = $self->dockerConfigHashRef->{'memory'};
		$logger->debug("docker memory is set to $memString, using this to tune postgres.");
		$memString =~ /(\d+)\s*(\w)/;
		$totalMem     = $1;
		$totalMemUnit = $2;
		$logger->debug("docker memory is set to $memString, using this to tune postgres. total=$totalMem, unit=$totalMemUnit");
	}
	else {

		# Find the total amount of memory on the host
		my $out = `$sshConnectString cat /proc/meminfo`;
		$out =~ /MemTotal:\s+(\d+)\s+(\w)/;
		$totalMem     = $1;
		$totalMemUnit = $2;
		$logger->debug("Host memory is set to $out, using this to tune postgres. total=$totalMem, unit=$totalMemUnit");
	}
	if ( uc($totalMemUnit) eq "K" ) {
		$totalMemUnit = "kB";
	}
	elsif ( uc($totalMemUnit) eq "M" ) {
		$totalMemUnit = "MB";
	}
	elsif ( uc($totalMemUnit) eq "G" ) {
		$totalMemUnit = "GB";
	}
	
	# Modify the postgresql.conf and
	# then copy the new version to the DB
	open( FILEIN,  "$configDir/postgresql/postgresqlDocker.conf" );
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
			print FILEOUT "port = '" . $self->internalPortMap->{$impl} . "'\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container
	$self->host->dockerScpFileTo( $applog, $name, "/tmp/postgresql$suffix.conf",
		"/mnt/dbData/postgresql/postgresql.conf" );
	$self->host->dockerExec( $applog, $name, "chown postgres:postgres /mnt/dbData/postgresql/postgresql.conf" );

	close $applog;

}

sub isBackupAvailable {
	my ( $self, $backupDirPath, $applog ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $name        = $self->getParamValue('dockerName');

	my $sshConnectString = $self->host->sshConnectString;

	my $chkOut =  $self->host->dockerExec( $applog, $name, "sh -c \"[ -d $backupDirPath ] && echo 'found'\"" );
	if ( !( $chkOut =~ /found/ ) ) {
		return 0;
	}
	$chkOut =  $self->host->dockerExec( $applog, $name, "sh -c \"[ \\\"$(ls -A $backupDirPath)\\\" ] && echo \\\"Full\\\" || echo \\\"Empty\\\"\"" );
	if ( $chkOut =~ /Empty/ ) {
		return 0;
	}

	return 1;

}

sub stopStatsCollection {
	my ($self)      = @_;
	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->internalPortMap->{$impl};

	my $logName = "/tmp/PostgresqlStatsEndOfSteadyState-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Getting end of steady-state stats from PortgreSQL\n";

	# Get interesting views on the pg_stats table
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_activity;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_bgwriter;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_database;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_database_conflicts;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_user_tables;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_statio_user_tables;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_stat_user_indexes;'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command='select * from pg_statio_user_indexes;'" );

	close $applog;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname    = $self->host->hostName;
	my $name        = $self->getParamValue('dockerName');
	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $port        = $self->internalPortMap->{$impl};

	my $logName = "/tmp/PostgresqlStartStatsCollection-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";

	# Reset the stats tables
	$self->host->dockerExec( $applog, $name, "psql -p $port -U auction --command='select pg_stat_reset();'" );
	$self->host->dockerExec( $applog, $name,
		"psql -p $port -U auction --command=\"select pg_stat_reset_shared('bgwriter');\"" );

	close $applog;
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');

	my $logName = "/tmp/PostgresqlStatsEndOfSteadyState-$hostname-$name.log";

	my $out = `cp $logName $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ($self)   = @_;
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');

	my $logName = "/tmp/PostgresqlStatsEndOfSteadyState-$hostname-$name.log";

	my $out = `rm -f $logName 2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/PostgresqlDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $logContents = $self->host->dockerGetLogs( $applog, $name );

	print $applog $logContents;

	close $applog;

}

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

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/GetConfigFilesPostgresqlDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerScpFileFrom( $applog, $name, "/mnt/dbData/postgresql/postgresql.conf", "$logpath/." );

	close $applog;

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

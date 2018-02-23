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
	my $host         = $self->host;
	my $impl             = $self->getImpl();
	my $logDir           = $self->getParamValue('postgresqlLogDir');
	my $sshConnectString = $self->host->sshConnectString;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");

	#	`$sshConnectString chmod -R 777 $logDir`;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name-$time.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Map the log and data volumes to the appropriate host directories
	my %volumeMap;
	my $hostDataDir = $self->getParamValue('postgresqlDataDir');
	if ($host->getParamValue('postgresqlUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$hostDataDir = $self->getParamValue('postgresqlDataVolume');
		# use named volumes.  Create volume if it doesn't exist
		if (!$host->dockerVolumeExists($applog, $hostDataDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('postgresqlDataVolumeSize');
			}
			$host->dockerVolumeCreate($applog, $hostDataDir, $volumeSize);
		}

		$logDir           = $self->getParamValue('postgresqlLogVolume');
		if (!$host->dockerVolumeExists($applog, $logDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('postgresqlLogVolumeSize');
			}
			$host->dockerVolumeCreate($applog, $logDir, $volumeSize);
		}
	}
	$volumeMap{"/mnt/dbData/postgresql"} = $hostDataDir;
	$volumeMap{"/mnt/dbLogs/postgresql"} = $logDir;

	my %envVarMap;
	$envVarMap{"POSTGRES_USER"}     = "auction";
	$envVarMap{"POSTGRES_PASSWORD"} = "auction";
	
	$envVarMap{"POSTGRESPORT"} = $self->internalPortMap->{$impl};

	if (   ( exists $self->dockerConfigHashRef->{'memory'} )
		&&  $self->dockerConfigHashRef->{'memory'}  )
	{
		my $memString = $self->dockerConfigHashRef->{'memory'};
		$logger->debug("docker memory is set to $memString, using this to tune postgres.");
		$memString =~ /(\d+)\s*(\w)/;
		$envVarMap{"POSTGRESTOTALMEM"} = $1;
		$envVarMap{"POSTGRESTOTALMEMUNIT"} = $2;
	} else {
		$envVarMap{"POSTGRESTOTALMEM"} = 0;
		$envVarMap{"POSTGRESTOTALMEMUNIT"} = 0;		
	}
	$envVarMap{"POSTGRESSHAREDBUFFERS"} = $self->getParamValue('postgresqlSharedBuffers');		
	$envVarMap{"POSTGRESSHAREDBUFFERSPCT"} = $self->getParamValue('postgresqlSharedBuffersPct');		
 	$envVarMap{"POSTGRESEFFECTIVECACHESIZE"} = $self->getParamValue('postgresqlEffectiveCacheSize');
 	$envVarMap{"POSTGRESEFFECTIVECACHESIZEPCT"} = $self->getParamValue('postgresqlEffectiveCacheSizePct');
 	$envVarMap{"POSTGRESMAXCONNECTIONS"} = $self->getParamValue('postgresqlMaxConnections');
 	
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

	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

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

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataPostgresql-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PortgreSQL\n";

	$self->host->dockerExec($applog, $name, "/clearAfterStart.sh");

	close $applog;

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

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

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

}

sub isBackupAvailable {
	my ( $self, $backupDirPath, $applog ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $name        = $self->getParamValue('dockerName');

	# The postgresqlDocker does not currently support backups
	return 0;
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
	$self->host->dockerExec($applog, $name, "perl /dumpStats.pl");

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

	print $applog "Getting start of steady-state stats from PortgreSQL\n";
	$self->host->dockerExec($applog, $name, "perl /dumpStats.pl");

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

#	my $logName = "$logpath/GetConfigFilesPostgresqlDocker-$hostname-$name.log";

#	my $applog;
#	open( $applog, ">$logName" )
#	  || die "Error opening /$logName:$!";

#	$self->host->dockerScpFileFrom( $applog, $name, "/mnt/dbData/postgresql/postgresql.conf", "$logpath/." );

#	close $applog;

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
	
	my $hostname = $self->getIpAddr();
	my $impl = $self->getImpl() ;
	my $port             = $self->portMap->{$impl};
	my $maxUsers = `psql --host $hostname --port $port -U auction  -t -q --command="select maxusers from dbbenchmarkinfo;"`;
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

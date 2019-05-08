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
package CassandraDockerService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::Service;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has 'clearBeforeStart' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub stopInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->name;
	my $name             = $self->name;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StopCassandraDocker-$hostname-$name-$time.log";
	my $logger = get_logger("Weathervane::Services::CassandraDockerService");
	$logger->debug("stop CassandraDockerService");

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $applog, $name );

	close $applog;
}

# Need to override start so that we can set CASSANDRA_SEEDS 
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::CassandraDockerServer");
	$logger->debug(
		"start serviceType $serviceType, Workload ",
		$self->appInstance->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $servicesRef = $self->appInstance->getAllServicesByType($serviceType);
	foreach my $service (@$servicesRef) {
		$logger->debug( "Start " . $service->name . "\n" );
		$service->create($logPath);
	}
	
};

sub create {
	my ( $self, $logPath ) = @_;

	my $name             = $self->name;
	my $hostname         = $self->host->name;
	my $host         = $self->host;
	my $impl             = $self->getImpl();
	my $logger = get_logger("Weathervane::Services::CassandraService");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/CreateCassandraDockerService-$hostname-$name-$time.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Map the log and data volumes to the appropriate host directories
	my %volumeMap;
	if ($self->getParamValue('cassandraUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$volumeMap{"/data"} = $self->getParamValue('cassandraDataVolume');
	}

	my $servicesRef = $self->appInstance->getAllServicesByType("nosqlServer");

	my $seeds = "";
	foreach my $service (@$servicesRef) {
		my $serviceHostname = $service->host->name;
		if (!($serviceHostname eq $hostname)) {
			$seeds .= $serviceHostname . ",";
		}
	}
	chop($seeds);

	my %envVarMap;
	$envVarMap{"CASSANDRA_USE_IP"}     = 1;
	$envVarMap{"CLEARBEFORESTART"}     = $self->clearBeforeStart;
	$envVarMap{"CASSANDRA_DOCKER_SEEDS"} = $seeds;
	$envVarMap{"CASSANDRA_CLUSTER_NAME"} = "auctionw" . $self->appInstance->workload->instanceNum 
													. "i" . $self->appInstance->instanceNum;
	# Create the container
	my %portMap;
	my $directMap = 1;

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

override 'remove' => sub {
	my ( $self, $logPath ) = @_;

	my $name     = $self->name;
	my $hostname = $self->host->name;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName  = "$logPath/RemoveCassandraDocker-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove( $applog, $name );

	close $applog;
};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraDockerService");
	my $name        = $self->name;
	$logger->debug("clearDataBeforeStart for $name");
	$self->clearBeforeStart(1);
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::CassandraDockerService");
	my $hostname    = $self->host->name;
	my $name        = $self->name;

	$logger->debug("clearDataAfterStart for $name");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataCassandra-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From Cassandra\n";

	$self->host->dockerExec($applog, $name, "/clearAfterStart.sh");

	close $applog;

}

sub isUp {
	my ( $self, $fileout ) = @_;
	return $self->isRunning($fileout);

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return $self->host->dockerIsRunning( $fileout, $name );

}

sub isStopped {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return !$self->host->dockerExists( $fileout, $name );
}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType    = $self->getParamValue('serviceType');
	my $impl           = $self->getParamValue( $serviceType . "Impl" );
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;
	$self->internalPortMap->{$impl} = $self->getParamValue('cassandraPort') + $portOffset;
}

sub setExternalPortNumbers {
	my ($self) = @_;
	
	my $name = $self->name;
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

sub stopStatsCollection {
	my ($self)      = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
}

sub cleanStatsFiles {
	my ($self)   = @_;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name     = $self->name;
	my $hostname = $self->host->name;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/CassandraDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $logContents = $self->host->dockerGetLogs( $applog, $name );

	print $applog $logContents;

	close $applog;

}

sub cleanLogFiles {
	my ($self)            = @_;
	my $logger = get_logger("Weathervane::Services::CassandraDockerService");
}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();
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

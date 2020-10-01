# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package Service;

use Moose;
use MooseX::Storage;
use Tie::IxHash;
use Parameters qw(getParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use POSIX qw(floor);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;
use Log::Log4perl qw(get_logger);
use ComputeResources::ComputeResource;
use WeathervaneTypes;
use Instance;

extends 'Instance';

has 'appInstance' => (
	is      => 'rw',
	isa     => 'AppInstance',
);

# Attributes for a specific instance
has 'host' => (
	is  => 'rw',
	isa => 'ComputeResource',
);

has 'dockerConfigHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

# internalPortMap: A map from a name for a port (e.g. http) to
# the port used by this service.  This represents the view from
# inside a docker container
has 'internalPortMap' => (
	is      => 'rw',
	isa     => 'HashRef',
	writer => '_set_internalPortMap',
	default => sub { {} },
);

# portMap: A map from a name for a port (e.g. http) to
# the port used by this service
has 'portMap' => (
	is      => 'rw',
	isa     => 'HashRef',
	writer => '_set_portMap',
	default => sub { {} },
);

# Used for Docker services that need a tty when started
has 'needsTty' => (
	is => 'rw',
	isa => 'Bool',
	default => 0,
);

# Hold the id assigned by the configuration manager
has 'id' => (
	is => 'rw',
	isa => 'Int',
);

# Hold the url for removing the service that was received from the 
# configuration manager
has 'removeUrl' => (
	is => 'rw',
	isa => 'Str',
	default => "",
);

override 'initialize' => sub {
	my ( $self ) = @_;

	# Assign a name to this service
	my $serviceType = $self->getParamValue('serviceType');
	my $workloadNum = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $instanceNum = $self->instanceNum;
	$self->name("${serviceType}W${workloadNum}A${appInstanceNum}I${instanceNum}");

	my $cpus = $self->getParamValue( $serviceType . "Cpus" );
	my $mem = $self->getParamValue( $serviceType . "Mem" );
	if ($self->getParamValue('dockerNet')) {
		$self->dockerConfigHashRef->{'net'} = $self->getParamValue('dockerNet');
	}
	if ($cpus) {
		$self->dockerConfigHashRef->{'cpus'} = $cpus;
	}
	if ($self->getParamValue('dockerCpuShares')) {
		$self->dockerConfigHashRef->{'cpu-shares'} = $self->getParamValue('dockerCpuShares');
	} 
	if ($self->getParamValue('dockerCpuSetCpus') ne "unset") {
		$self->dockerConfigHashRef->{'cpuset-cpus'} = $self->getParamValue('dockerCpuSetCpus');
	}
	if ($self->getParamValue('dockerCpuSetMems') ne "unset") {
		$self->dockerConfigHashRef->{'cpuset-mems'} = $self->getParamValue('dockerCpuSetMems');
	}
	if ($mem) {
		$self->dockerConfigHashRef->{'memory'} = $mem;
	}
	if ($self->getParamValue('dockerMemorySwap')) {
		$self->dockerConfigHashRef->{'memory-swap'} = $self->getParamValue('dockerMemorySwap');
	}

	$self->dockerConfigHashRef->{'useDockerLimits'} = $self->getParamValue('useDockerLimits');
	$self->dockerConfigHashRef->{'useAppServerLimits'} = $self->getParamValue('useAppServerLimits');
	
	super();

};

sub setHost {
	my ($self, $host) = @_;
	
	$self->host($host);
	$host->registerService($self);
	
}

sub registerPortsWithHost {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For service ", $self->name, ", registering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->registerPortNumber($portNumber, $self);
		}				
	}
}

sub unRegisterPortsWithHost {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For service ", $self->name, ", unregistering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->unRegisterPortNumber($portNumber);
		}				
	}
}

sub setAppInstance {
	my ($self, $appInstance) = @_;
	$self->appInstance($appInstance);
}

sub isEdgeService {
	my ($self) = @_;
	if ($self->getParamValue( 'serviceType' ) eq $self->appInstance->getEdgeService()) {
		return 1;
	} else {
		return 0;
	}
}

sub create {
	my ($self, $logPath)            = @_;
	
	my $name = $self->name;
	my $hostname         = $self->host->name;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	# The default create doesn't map any volumes
	my %volumeMap;
	
	# The default create doesn't create any environment variables
	my %envVarMap;
	
	# Create the container
	my %portMap;
	my $directMap = 0;

	foreach my $key (keys %{$self->internalPortMap}) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	
	my $cmd = "";
	my $entryPoint = "";
	
	$self->host->dockerRun($applog, $self->name, $impl, $directMap, 
		\%portMap, \%volumeMap, \%envVarMap,$self->dockerConfigHashRef,	
		$entryPoint, $cmd, $self->needsTty);
		
	$self->setExternalPortNumbers();
	
	close $applog;
}

sub start {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Service::Service");
	$logger->debug(
		"start serviceType $serviceType, Workload ",
		$self->appInstance->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $impl   = $self->appInstance->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->appInstance->workload->instanceNum . "I" . $self->appInstance->instanceNum;

	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	my $servicesRef = $self->appInstance->getAllServicesByType($serviceType);

	if ( $serviceType ~~ @$dockerServiceTypesRef ) {
		foreach my $service (@$servicesRef) {
			$logger->debug( "Create " . $service->name . "\n" );
			$service->create($logPath);
		}
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "Configure " . $service->name . "\n" );
		$service->configure( $logPath, $users, $suffix );
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "Start " . $service->name . "\n" );
		$service->startInstance($logPath);
	}
		
}


sub stop {
	my ($self, $serviceType, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Service::Service");
	$logger->debug(
		"stop serviceType $serviceType, Workload ",
		$self->appInstance->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $impl   = $self->appInstance->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->appInstance->workload->instanceNum . "I" . $self->appInstance->instanceNum;

	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	my $servicesRef = $self->appInstance->getAllServicesByType($serviceType);

	foreach my $service (@$servicesRef) {
		$logger->debug( "Stop " . $service->name . "\n" );
		$service->stopInstance( $logPath );
	}

	if ( $serviceType ~~ @$dockerServiceTypesRef ) {
		foreach my $service (@$servicesRef) {
			$logger->debug( "Remove " . $service->name . "\n" );
			$service->remove($logPath);
		}
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "CleanLogFiles " . $service->name . "\n" );
		$service->cleanLogFiles();
		$logger->debug( "CleanStatsFiles " . $service->name . "\n" );
		$service->cleanStatsFiles();
	}
	
}

sub remove {
	my ($self)            = @_;

}

sub pullDockerImage {
	my ($self, $logfile)            = @_;
	my $logger = get_logger("Weathervane::Services::Service");
	
	my $impl = $self->getImpl();
	$logger->debug("Calling dockerPull for service ", $self->meta->name," instanceNum ", $self->instanceNum);
	$self->host->dockerPull($logfile, $impl);
}

sub workloadRunning {
	my ($self) = @_;
	# Default workloadRunning is no-op
}

sub sanityCheck {
	my ($self, $cleanupLogDir) = @_;
	
	return 1;
}

sub isReachable {
	my ($self, $fileout) = @_;
	my $hostname = $self->host->name;
	
	my $pingResult = `ping -c 1 $hostname`;
	
	if ($pingResult =~ /100\% packet loss/) {
		return 0;
	} else {
		return 1;		
	}
}

sub isUp {
	my ($self, $fileout) = @_;
	
	return 1;
}

sub isRunning {
	my ($self, $fileout) = @_;
	
	return 1;
}

sub isStopped {
	my ($self, $fileout) = @_;
	
	return 1;
}

sub getPort {
	my ($self, $key) = @_;
	return $self->portMap->{$key};
}

sub getImpl {
	my ($self) = @_;
	
	my $serviceType = $self->getParamValue('serviceType');
	return $self->getParamValue($serviceType . 'Impl');
}

# This method returns true if both this and the other service are
# running dockerized on the same Docker host and network but are not
# using docker host networking
sub corunningDockerized {
	my ($self, $other) = @_;
	my $logger = get_logger("Weathervane::Services::Service");
	if (((ref $self->host) ne 'DockerHost') || ((ref $other->host) ne 'DockerHost')
		|| ($self->dockerConfigHashRef->{'net'} eq 'host')
		|| ($other->dockerConfigHashRef->{'net'} eq 'host')
		|| ($self->dockerConfigHashRef->{'net'} ne $other->dockerConfigHashRef->{'net'})
		|| !$self->host->equals($other->host)
		|| ($self->host->getParamValue('vicHost') && ($self->dockerConfigHashRef->{'net'} ne "bridge"))) 
	{
		$logger->debug("corunningDockerized: " . $self->name . " and " . $other->name . " are not corunningDockerized");
		return 0;
	} else {
		$logger->debug("corunningDockerized: " . $self->name . " and " . $other->name . " are corunningDockerized");
		return 1;
	}	
	
}

# This method checks whether this service and another service are 
# both running Dockerized on the same host and Docker network.  If so, it
# returns the docker name of the service (so that this service can connect to 
# it directly via the Docker provided /etc/hosts), otherwise it returns the
# hostname of the other service.
# If this service is using Docker host networking, then this method always
# returns the hostname of the other host.
sub getHostnameForUsedService {
	my ($self, $other) = @_;
	my $logger = get_logger("Weathervane::Services::Service");
	
	if ($self->corunningDockerized($other)) 
	{
		my $ip = $other->host->dockerGetIp($other->name);
		$logger->debug("getHostnameForUsedService: Corunning dockerized, returning " . $ip);
		return $ip;
	} else {
		$logger->debug("getHostnameForUsedService: Not corunning dockerized, returning " . $other->host->name);
		return $other->host->name;
	}	
}

sub getPortNumberForUsedService {
	my ($self, $other, $portName) = @_;
	my $logger = get_logger("Weathervane::Services::Service");
	
	if ($self->corunningDockerized($other)) 
	{
		$logger->debug("getPortNumberForUsedService: Corunning dockerized, returning " . $other->internalPortMap->{$portName});
		return $other->internalPortMap->{$portName};
	} else {
		$logger->debug("getPortNumberForUsedService: Corunning dockerized, returning " . $other->portMap->{$portName});
		return $other->portMap->{$portName};
	}	
}

sub checkSizeAndTruncate {
	my ($self, $path, $filename, $maxLogLines) = @_;
	my $logger = get_logger("Weathervane::Services::Service");

#	my $sshConnectString = $self->host->sshConnectString;
#	
#	$logger->debug("checkSizeAndTruncate.  path = $path, filename = $filename, maxLogLines = $maxLogLines");	
#	
#	my $wc = `$sshConnectString wc -l $path/$filename 2>&1`;
#	if ($wc =~ /^(\d*)\s/) {
#		$wc = $1;
#	} else {
#		return;
#	}
#	$logger->debug("checkSizeAndTruncate.  wc = $wc");	
#	
#	if ($wc > $maxLogLines) {
#		# The log is too large.  Truncate it to maxLogLines by taking
#		# The start and end of the file
#		$logger->debug("checkSizeAndTruncate.  Truncating file");	
#		my $halfLines = floor($maxLogLines/2);
#		`$sshConnectString "head -n $halfLines $path/$filename > $path/$filename.head"`;
#		`$sshConnectString "tail -n $halfLines $path/$filename > $path/$filename.tail"`;
#		`$sshConnectString "mv -f $path/$filename.head $path/$filename"`;
#		`$sshConnectString "echo \"   +++++++ File truncated to $maxLogLines lines. Middle section removed.++++++   \" >> $path/$filename"`;
#		`$sshConnectString "cat $path/$filename.tail >> $path/$filename"`;
#		`$sshConnectString "rm -f $path/$filename.tail "`;
#		
#	}
	
}
sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
}



#-------------------------------
# Two services are equal if they have the same name and
# the same version.
#-------------------------------
sub equals {
	my ( $this, $that ) = @_;

	return ( $this->name() eq $that->name() ) && ( $this->service() eq $that->service() );
}

sub toString {
	my ($self) = @_;

	return "Service " . $self->name() . " with version " . $self->version() . " on host " . $self->host->toString();
}

__PACKAGE__->meta->make_immutable;

1;

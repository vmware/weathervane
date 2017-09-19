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

use Hosts::Host;
use WeathervaneTypes;
use Instance;

extends 'Instance';

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

has 'version' => (
	is  => 'ro',
	isa => 'Str',
);

has 'description' => (
	is  => 'ro',
	isa => 'Str',
);

has 'appInstance' => (
	is      => 'rw',
	isa     => 'AppInstance',
);

# Attributes for a specific instance
has 'host' => (
	is  => 'rw',
	isa => 'Host',
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

# This service is currently actively part of the running configuration
has 'isActive' => (
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


	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $configDir  = $self->getParamValue('configDir');
	if ( !( $configDir =~ /^\// ) ) {
		$configDir = $weathervaneHome . "/" . $configDir;
	}
	$self->setParamValue('configDir', $configDir);
	
	my $distDir  = $self->getParamValue( 'distDir' );
	if ( !( $distDir =~ /^\// ) ) {
		$distDir = $weathervaneHome . "/" . $distDir;
	}
	$self->setParamValue('distDir', $distDir);
	
	# if the tmpDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $tmpDir = $self->getParamValue('tmpDir' );
	if ( !( $tmpDir =~ /^\// ) ) {
		$tmpDir = $weathervaneHome . "/" . $tmpDir;
	}
	$self->setParamValue('tmpDir', $tmpDir);

	# if the dbScriptDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $dbScriptDir    = $self->getParamValue('dbScriptDir' );
	if ( !( $dbScriptDir =~ /^\// ) ) {
		$dbScriptDir = $weathervaneHome . "/" . $dbScriptDir;
	}
	$self->setParamValue('dbScriptDir', $dbScriptDir);

	# make sure the directories exist
	if ( !( -e $dbScriptDir ) ) {
		die "Error: The directory for the database creation scripts, $dbScriptDir, does not exist.";
	}
	
	if ($self->getParamValue('dockerNet')) {
		$self->dockerConfigHashRef->{'net'} = $self->getParamValue('dockerNet');
	}
	if ($self->getParamValue('dockerCpus')) {
		$self->dockerConfigHashRef->{'cpus'} = $self->getParamValue('dockerCpus');
	}
	if ($self->getParamValue('dockerCpuShares')) {
		$self->dockerConfigHashRef->{'cpu-shares'} = $self->getParamValue('dockerCpuShares');
	} 
	if ($self->getParamValue('dockerCpuSetCpus') ne "unset") {
		$self->dockerConfigHashRef->{'cpuset-cpus'} = $self->getParamValue('dockerCpuSetCpus');
		
		if ($self->getParamValue('dockerCpus') == 0) {
			# Parse the CpuSetCpus parameter to determine how many CPUs it covers and 
			# set dockerCpus accordingly so that services can know how many CPUs the 
			# container has when configuring
			my $numCpus = 0;
			my @cpuGroups = split(/,/, $self->getParamValue('dockerCpuSetCpus'));
			foreach my $cpuGroup (@cpuGroups) {
				if ($cpuGroup =~ /-/) {
					# This cpu group is a range
					my @rangeEnds = split(/-/,$cpuGroup);
					$numCpus += ($rangeEnds[1] - $rangeEnds[0] + 1);
				} else {
					$numCpus++;
				}
			}
			$self->setParamValue('dockerCpus', $numCpus);
		}
	}
	if ($self->getParamValue('dockerCpuSetMems') ne "unset") {
		$self->dockerConfigHashRef->{'cpuset-mems'} = $self->getParamValue('dockerCpuSetMems');
	}
	if ($self->getParamValue('dockerMemory')) {
		$self->dockerConfigHashRef->{'memory'} = $self->getParamValue('dockerMemory');
	}
	if ($self->getParamValue('dockerMemorySwap')) {
		$self->dockerConfigHashRef->{'memory-swap'} = $self->getParamValue('dockerMemorySwap');
	}
		
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
		$logger->debug("For service ", $self->getDockerName(), ", registering port $portNumber for key $key");
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
		$logger->debug("For service ", $self->getDockerName(), ", unregistering port $portNumber for key $key");
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

sub getWorkloadNum {
	my ($self) = @_;
	return $self->getParamValue('workloadNum');
}

sub getAppInstanceNum {
	my ($self) = @_;
	return $self->getParamValue('appInstanceNum');
}

sub getIpAddr {
	my ($self) = @_;
	if ($self->useDocker() && $self->host->dockerNetIsExternal($self->dockerConfigHashRef->{'net'})) {
		return $self->host->dockerGetExternalNetIP($self->getDockerName(), $self->dockerConfigHashRef->{'net'});
	}
	return $self->host->ipAddr;
}

sub create {
	my ($self, $logPath)            = @_;
	my $useVirtualIp     = $self->getParamValue('useVirtualIp');
	
	if (!$self->getParamValue('useDocker')) {
		return;
	}
	
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
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
	if ($self->isEdgeService() && $useVirtualIp)  {
		# This is an edge service and we are using virtual IPs.  Map the internal ports to the host ports
		$directMap = 1;
	}
	foreach my $key (keys %{$self->internalPortMap}) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	
	my $cmd = "";
	my $entryPoint = "";
	
	$self->host->dockerRun($applog, $self->getParamValue('dockerName'), $impl, $directMap, 
		\%portMap, \%volumeMap, \%envVarMap,$self->dockerConfigHashRef,	
		$entryPoint, $cmd, $self->needsTty);
		
	$self->setExternalPortNumbers();
	
	close $applog;
}

sub pullDockerImage {
	my ($self, $logfile)            = @_;
	my $logger = get_logger("Weathervane::Services::Service");
	
	if (!$self->getParamValue('useDocker')) {
		$logger->debug("$self->meta->name is not using docker.  Not pulling.");
		return;
	}

	my $impl = $self->getImpl();
	$logger->debug("Calling dockerPull for service ", $self->meta->name," instanceNum ", $self->getParamValue("instanceNum"));
	$self->host->dockerPull($logfile, $impl);
}

sub workloadRunning {
	my ($self) = @_;
	# Default workloadRunning is no-op
}

sub remove {
	my ($self) = @_;
	# Default remove is no-op
}

sub sanityCheck {
	my ($self, $cleanupLogDir) = @_;
	
	return 1;
}

sub isReachable {
	my ($self, $fileout) = @_;
	my $hostname = $self->host->hostName;
	
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

sub useDocker {
	my ($self) = @_;
	
	return $self->getParamValue("useDocker");
}

sub getDockerName {
	my ($self) = @_;
	
	return $self->getParamValue("dockerName");
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

# This method returns true is both this and the other service are
# running dockerized on the same Docker host and network but are not
# using docker host networking
sub corunningDockerized {
	my ($self, $other) = @_;
	if (!$self->useDocker() || !$other->useDocker()
		|| ($self->dockerConfigHashRef->{'net'} eq 'host')
		|| ($other->dockerConfigHashRef->{'net'} eq 'host')
		|| ($self->dockerConfigHashRef->{'net'} ne $other->dockerConfigHashRef->{'net'})
		|| !$self->host->equals($other->host)
		|| ($self->host->getParamValue('vicHost') && ($self->dockerConfigHashRef->{'net'} ne "bridge"))) 
	{
		return 0;
	} else {
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
	
	if ($self->corunningDockerized($other)) 
	{
		return $other->host->dockerGetIp($other->getDockerName());
	} else {
		return $other->getIpAddr();
	}	
}

sub getPortNumberForUsedService {
	my ($self, $other, $portName) = @_;
	
	if ($self->corunningDockerized($other)) 
	{
		return $other->internalPortMap->{$portName};
	} else {
		return $other->portMap->{$portName};
	}	
}

sub checkSizeAndTruncate {
	my ($self, $path, $filename, $maxLogLines) = @_;
	my $logger = get_logger("Weathervane::Services::Service");

	my $sshConnectString = $self->host->sshConnectString;
	
	$logger->debug("checkSizeAndTruncate.  path = $path, filename = $filename, maxLogLines = $maxLogLines");	
	
	my $wc = `$sshConnectString wc -l $path/$filename 2>&1`;
	if ($wc =~ /^(\d*)\s/) {
		$wc = $1;
	} else {
		return;
	}
	$logger->debug("checkSizeAndTruncate.  wc = $wc");	
	
	if ($wc > $maxLogLines) {
		# The log is too large.  Truncate it to maxLogLines by taking
		# The start and end of the file
		$logger->debug("checkSizeAndTruncate.  Truncating file");	
		my $halfLines = floor($maxLogLines/2);
		`$sshConnectString "head -n $halfLines $path/$filename > $path/$filename.head"`;
		`$sshConnectString "tail -n $halfLines $path/$filename > $path/$filename.tail"`;
		`$sshConnectString "mv -f $path/$filename.head $path/$filename"`;
		`$sshConnectString "echo \"   +++++++ File truncated to $maxLogLines lines. Middle section removed.++++++   \" >> $path/$filename"`;
		`$sshConnectString "cat $path/$filename.tail >> $path/$filename"`;
		`$sshConnectString "rm -f $path/$filename.tail "`;
		
	}
	
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

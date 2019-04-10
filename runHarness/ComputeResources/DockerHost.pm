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
package DockerHost;

use MooseX::Storage;
use MIME::Base64;
use POSIX;
use Log::Log4perl qw(get_logger);
use Utils qw(getIpAddress);
use ComputeResources::Host
use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Host';

has 'dockerHostString' => (
	is  => 'rw',
	isa => 'Str',
);

# used to track docker names that are used on this host
has 'dockerNameHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	my $hostname   = $self->name;
	my $dockerPort = $self->getParamValue('dockerPort');
	$self->dockerHostString( "DOCKER_HOST=" . $hostname . ":" . $dockerPort );
		
	super();
};

override 'registerService' => sub {
	my ( $self, $serviceRef ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	my $servicesRef    = $self->servicesRef;

	my $dockerName = $serviceRef->name;
	$logger->debug( "Registering service $dockerName with host ",
		$self->name );

	if ( $serviceRef->useDocker() ) {
		if ( exists $self->dockerNameHashRef->{$dockerName} ) {
			$console_logger->error( "Have two services on host ",
				$self->name, " with docker name $dockerName." );
			exit(-1);
		}
		$self->dockerNameHashRef->{$dockerName} = 1;
	}

	push @$servicesRef, $serviceRef;

};
sub dockerExists {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;
	
	my $out = `$dockerHostString docker ps -a`;
	print $logFileHandle "$dockerHostString docker ps -a\n";
	print $logFileHandle "$out\n";
	$logger->debug("name = $name, result of ps -a: $out");
	
	my @lines = split /\n/, $out;
	my $found = 0;
	
	foreach my $line (@lines) {	
		if ($line =~ /\s+$name\s*$/) {
			print $logFileHandle "Container $name found in $line\n";
			$found = 1;
			last;
		}
	}

	return $found;
}

sub dockerIsRunning {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	my $out = `$dockerHostString docker ps `;
	if ($logFileHandle) {
		print $logFileHandle "$dockerHostString docker ps\n";
		print $logFileHandle "$out\n";
	}
	$logger->debug("name = $name, docker ps output = $out");
	
	my @lines = split /\n/, $out;
	my $found = 0;
	
	foreach my $line (@lines) {	
		if ($line =~ /\s+$name\s*$/) {
			if ($logFileHandle) {
				print $logFileHandle "Container $name found in $line\n";
			}
			$found = 1;
			last;
		}
	}
	$logger->debug("name = $name, found = $found");

	return $found;

}

sub dockerStop {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerIsRunning($logFileHandle, $name)) {
		my $out = `$dockerHostString docker stop -t 60 $name`;
		print $logFileHandle "$dockerHostString docker stop $name\n";
		print $logFileHandle "$out\n";
	}
}

sub dockerStopAndRemove {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	print $logFileHandle "dockerStopAndRemove for $name " . $self->name .  " \n";
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerExists($logFileHandle, $name)) {
	print $logFileHandle "dockerStopAndRemove $name exists on" . $self->name .  "\n";
		$logger->debug("name = $name, exists");
		if ($self->dockerIsRunning($logFileHandle, $name)) {
			print $logFileHandle "dockerStopAndRemove $name is running on" . $self->name .  "\n";
			$logger->debug("name = $name, isRunning.  Stopping.");
			my $out = `$dockerHostString docker stop $name`;
			print $logFileHandle "$dockerHostString docker stop $name\n";
			print $logFileHandle "$out\n";
		}
	
		$logger->debug("name = $name, Removing.");
		my $out = `$dockerHostString docker rm -f $name 2>&1`;
		print $logFileHandle "$dockerHostString docker rm -f $name\n";
		print $logFileHandle "$out\n";
		$logger->debug("name = $name, Result of remove: $out");
		print $logFileHandle "name = $name, Result of remove: $out\n";
	}	
	
}

sub dockerStart {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $out = `$dockerHostString docker start $name`;
		print $logFileHandle "$dockerHostString docker start $name\n";
		print $logFileHandle "$out\n";
	}
	
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $logcontents = $self->dockerGetLogs($logFileHandle, $name);
		print $logFileHandle "Error: Container did not start.  Logs:\n";
		print $logFileHandle $logcontents;
		die "Docker container $name did not start on host " . $self->name;
	}	
	
	return $self->dockerPort( $name);
	
}

sub dockerNetIsHostOrExternal {
	my ( $self, $dockerNetName) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerNetIsHostOrExternal dockerNetName = $dockerNetName");
	my $dockerHostString  = $self->dockerHostString;

	my $out = `$dockerHostString docker network ls`;
	$logger->debug("output of docker network ls: $out");
	my @lines = split /\n/, $out;	
	foreach my $line (@lines) {
		if ($line =~ /^[^\s]+\s+([^\s]+)\s+([^\s]+)\s+.*$/) {
			if ($1 eq $dockerNetName) {
				if (($2 eq 'host') || ($2 eq 'external')) {
					$logger->debug("dockerNetIsHostOrExternal $dockerNetName is host or external");
					return 1;
				} else {
					$logger->debug("dockerNetIsHostOrExternal $dockerNetName is not host or external");
					return 0;
				}
			}
		}
	}
	
	die("Network $dockerNetName not found on host ", $self->name);
}

sub dockerNetIsExternal {
	my ( $self, $dockerNetName) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerNetIsExternal dockerNetName = $dockerNetName");
	my $dockerHostString  = $self->dockerHostString;

	my $out = `$dockerHostString docker network ls`;
	$logger->debug("output of docker network ls: $out");
	my @lines = split /\n/, $out;	
	foreach my $line (@lines) {
		if ($line =~ /^[^\s]+\s+([^\s]+)\s+([^\s]+)\s+.*$/) {
			if ($1 eq $dockerNetName) {
				if ($2 eq 'external') {
					$logger->debug("dockerNetIsHostOrExternal $dockerNetName is external");
					return 1;
				} else {
					$logger->debug("dockerNetIsHostOrExternal $dockerNetName is not external");
					return 0;
				}
			}
		}
	}
	
	die("Network $dockerNetName not found on host ", $self->name);
}

sub dockerPort {
	my ( $self, $name) = @_;
	my %portMap;

	my $dockerHostString  = $self->dockerHostString;
	my $out = `$dockerHostString docker port $name`;	
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		if ($line =~ /(\d+)\/.*\:(\d+)\s*$/) {
			$portMap{$1} = $2;
		}
	}
	
	return \%portMap;
	
}

sub dockerRestart {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	my $dockerHostString  = $self->dockerHostString;
	
	my $out = `$dockerHostString docker restart $name`;
	print $logFileHandle "$dockerHostString docker restart $name\n";
	print $logFileHandle "$out\n";
	
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $logcontents = $self->dockerGetLogs($logFileHandle, $name);
		print $logFileHandle "Error: Container did not start.  Logs:\n";
		print $logFileHandle $logcontents;
		die "Docker container $name did not start on host " . $self->name;
	}	
	
	$out = `$dockerHostString docker port $name`;
	print $logFileHandle "$dockerHostString docker port $name\n";
	print $logFileHandle "$out\n";
	
	my %portMap;
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		$line =~ /(\d+)\/.*\:(\d+)\s*$/;
		$portMap{$1} = $2;
	}
	
	return \%portMap;
		
}

sub dockerKill {
	my ( $self, $signal, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerKill name = $name");
	my $dockerHostString  = $self->dockerHostString;
	
	my $out;
	$out = `$dockerHostString docker kill --signal $signal $name 2>&1`;
	print $logFileHandle "$dockerHostString docker kill --signal $signal $name 2>&1\n";
	print $logFileHandle "$out\n";	

}

sub dockerReload {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	my $dockerHostString  = $self->dockerHostString;
	
	my $out;
	$out = `$dockerHostString docker kill --signal USR1 $name 2>&1`;
	print $logFileHandle "$dockerHostString docker kill --signal USR1 $name 2>&1\n";
	print $logFileHandle "$out\n";	

	$out = `$dockerHostString docker port $name`;
	print $logFileHandle "$dockerHostString docker port $name\n";
	print $logFileHandle "$out\n";
	
	my %portMap;
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		if ($line =~ /(\d+)\/.*\:(\d+)\s*$/) {
			$portMap{$1} = $2;
		}
	}
	
	return \%portMap;
	
}

sub dockerPull {
	my ( $self, $logFileHandle, $impl) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerPull for host ", $self->name, ", impl = $impl");
	my $version  = $self->getParamValue('dockerWeathervaneVersion');
	
	my $dockerHostString  = $self->dockerHostString;
	my $imagesHashRef = $self->getParamValue('dockerServiceImages');
	my $imageName = $imagesHashRef->{$impl};
	my $namespace = $self->getParamValue('dockerNamespace');

	my $out = `$dockerHostString docker pull $namespace/$imageName:$version 2>&1`;
	print $logFileHandle "$dockerHostString docker pull $namespace/$imageName:$version 2>&1\n";
	print $logFileHandle "$out\n";

}

sub dockerCreate {
	my ( $self, $logFileHandle, $name, $impl, $directMap, $portMapHashRef, $volumeMapHashRef, 
		$envVarHashRef, $dockerConfigHashRef, $entryPoint, $cmd) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");

	my $version  = $self->getParamValue('dockerWeathervaneVersion');
	my $dockerHostString  = $self->dockerHostString;
	my $imagesHashRef = $self->getParamValue('dockerServiceImages');
	my $imageName = $imagesHashRef->{$impl};
	my $namespace = $self->getParamValue('dockerNamespace');
	my $isVicHost = 	$self->getParamValue('vicHost');
	
	my $netString = "";
	if ((defined $dockerConfigHashRef->{"net"}) && ($dockerConfigHashRef->{"net"} ne "bridge")) {
		$netString = "--net=". $dockerConfigHashRef->{"net"};
	}
	
	my $portString = "";
	if (!($netString =~ /host/)) {
		$portString = "-P ";
		if (%$portMapHashRef) {
			# Use the explicit port mappings provided
			$portString = "";
			foreach my $containerPort (keys %$portMapHashRef) {
				if ($directMap) {
					my $hostPort = $portMapHashRef->{$containerPort};
					$portString .= "-p $hostPort:$containerPort ";
				} else {
					$portString .= "-p $containerPort ";
				}
			}
		}
	}
	
	my $volumeString = "";
	foreach my $containerDir (keys %$volumeMapHashRef) {
		my $hostDir = $volumeMapHashRef->{$containerDir};
		if (!$hostDir) {
			# This is a regular volume
			$volumeString .= " -v $containerDir ";
		} else {
			# This is a bind-mount volume
			$volumeString .= " -v $hostDir:$containerDir ";
		}
	}
	
	my $envString = "";
	foreach my $envVar (keys %$envVarHashRef) {
		my $value = $envVarHashRef->{$envVar};
		$envString .= " -e $envVar=$value ";
	}
	
	my $cpuSharesString = "";
	if (defined $dockerConfigHashRef->{"cpu-shares"} && $dockerConfigHashRef->{"cpu-shares"}) {
		$cpuSharesString = "--cpu-shares=". $dockerConfigHashRef->{"cpu-shares"};
	}

	my $cpusString = "";
	my $cpuSetCpusString = "";
	if (defined $dockerConfigHashRef->{"cpus"} && $dockerConfigHashRef->{"cpus"}) {
		my $cpus = $self->convertK8sCpuString($dockerConfigHashRef->{"cpus"});
		if (!$isVicHost) {
			$cpusString = sprintf("--cpus=%0.2f", $cpus);
		} else {
			$cpuSetCpusString = "--cpuset-cpus=". $cpus;
		}
	}

	if (defined $dockerConfigHashRef->{"cpuset-cpus"}) {
		$cpuSetCpusString = "--cpuset-cpus=". $dockerConfigHashRef->{"cpuset-cpus"};
	}

	my $cpuSetMemsString = "";
	if (defined $dockerConfigHashRef->{"cpuset-mems"}) {
		$cpuSetMemsString = "--cpuset-mems=". $dockerConfigHashRef->{"cpuset-mems"};
	}
	
	my $memoryString = "";
	if (defined $dockerConfigHashRef->{"memory"} && $dockerConfigHashRef->{"memory"}) {
		$memoryString = "--memory=". $self->convertK8sMemString($dockerConfigHashRef->{"memory"});
	}
	
	my $memorySwapString = "";
	if (defined $dockerConfigHashRef->{"memory-swap"} && $dockerConfigHashRef->{"memory-swap"}) {
		$memorySwapString = "--memory-swap=". $dockerConfigHashRef->{"memory-swap"};
	}
	
	my $entryPointString = "";
	if ($entryPoint) {
		$entryPointString = "--entrypoint=\"$entryPoint\"";
	}
		 
	if (!defined($cmd)) {
		$cmd = "";
	}
	
	my $cmdString = "$dockerHostString docker create $envString $volumeString $netString $portString "
		. " $cpusString $cpuSharesString $cpuSetCpusString $cpuSetMemsString "
		. " $memoryString $memorySwapString $entryPointString " 
		. " --name $name $namespace/$imageName:$version $cmd 2>&1";
	my $out = `$cmdString`;
	print $logFileHandle "$cmdString\n";
	print $logFileHandle "$out\n";
	
}


sub dockerRun {
	my ( $self, $logFileHandle, $name, $impl, $directMap, $portMapHashRef, $volumeMapHashRef, 
		$envVarHashRef, $dockerConfigHashRef, $entryPoint, $cmd, $needsTty) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name, impl = $impl, envVarHashRef values = " . (values %$envVarHashRef));

	my $version  = $self->getParamValue('dockerWeathervaneVersion');
	my $dockerHostString  = $self->dockerHostString;
	my $imagesHashRef = $self->getParamValue('dockerServiceImages');
	my $imageName = $imagesHashRef->{$impl};
	my $namespace = $self->getParamValue('dockerNamespace');
	my $isVicHost = 	$self->getParamValue('vicHost');
	
	my $netString = "";
	if ((defined $dockerConfigHashRef->{"net"}) && ($dockerConfigHashRef->{"net"} ne "bridge")) {
		$netString = "--net=". $dockerConfigHashRef->{"net"};
	}
	
	my $portString = "";
	if (!($netString =~ /host/)) {
		$portString = "-P ";
		if (%$portMapHashRef) {
			# Use the explicit port mappings provided
			$portString = "";
			foreach my $containerPort (keys %$portMapHashRef) {
				if ($directMap) {
					my $hostPort = $portMapHashRef->{$containerPort};
					$portString .= "-p $hostPort:$containerPort ";
				} else {
					$portString .= "-p $containerPort ";
				}
			}
		}
	}
	
	my $volumeString = "";
	foreach my $containerDir (keys %$volumeMapHashRef) {
		my $hostDir = $volumeMapHashRef->{$containerDir};
		if (!$hostDir) {
			# This is a regular volume
			$volumeString .= " -v $containerDir ";
		} else {
			# This is a bind-mount volume
			$volumeString .= " -v $hostDir:$containerDir ";
		}
	}
	
	my $envString = "";
	foreach my $envVar (keys %$envVarHashRef) {
		my $value = $envVarHashRef->{$envVar};
		$envString .= " -e $envVar=$value ";
	}

	my $cpuSharesString = "";
	if (defined $dockerConfigHashRef->{"cpu-shares"} && $dockerConfigHashRef->{"cpu-shares"}) {
		$cpuSharesString = "--cpu-shares=". $dockerConfigHashRef->{"cpu-shares"};
	}

	my $cpusString = "";
	my $cpuSetCpusString = "";
	if (defined $dockerConfigHashRef->{"cpus"} && $dockerConfigHashRef->{"cpus"}) {
		my $cpus = $self->convertK8sCpuString($dockerConfigHashRef->{"cpus"});
		if (!$isVicHost) {
			$cpusString = sprintf("--cpus=%0.2f", $cpus);
		} else {
			$cpuSetCpusString = "--cpuset-cpus=". $cpus;
		}
	}

	if (defined $dockerConfigHashRef->{"cpuset-cpus"}) {
		$cpuSetCpusString = "--cpuset-cpus=". $dockerConfigHashRef->{"cpuset-cpus"};
	}

	my $cpuSetMemsString = "";
	if (defined $dockerConfigHashRef->{"cpuset-mems"}) {
		$cpuSetMemsString = "--cpuset-mems=". $dockerConfigHashRef->{"cpuset-mems"};
	}
	
	my $memoryString = "";
	if (defined $dockerConfigHashRef->{"memory"} && $dockerConfigHashRef->{"memory"}) {
		$memoryString = "--memory=". $self->convertK8sMemString($dockerConfigHashRef->{"memory"});
	}
	
	my $memorySwapString = "";
	if (defined $dockerConfigHashRef->{"memory-swap"} && $dockerConfigHashRef->{"memory-swap"}) {
		$memorySwapString = "--memory-swap=". $dockerConfigHashRef->{"memory-swap"};
	}
	
	my $entryPointString = "";
	if ($entryPoint) {
		$entryPointString = "--entrypoint=\"$entryPoint\"";
	}
		
	my $ttyString = "";
	if ($needsTty) {
		$ttyString = "-t";
	}
		
	if (!defined($cmd)) {
		$cmd = "";
	}
	
	my $cmdString = "$dockerHostString docker run -d $envString $volumeString $netString $portString "
		. " $cpusString $cpuSharesString $cpuSetCpusString $cpuSetMemsString "
		. " $memoryString $memorySwapString $ttyString $entryPointString " 
		. " --name $name $namespace/$imageName:$version $cmd 2>&1";
	$logger->debug($cmdString);
	my $out = `$cmdString`;
	print $logFileHandle "$cmdString\n";
	print $logFileHandle "$out\n";
		
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $logcontents = $self->dockerGetLogs($logFileHandle, $name);
		print $logFileHandle "Error: Container did not start.  Logs:\n";
		print $logFileHandle $logcontents;
		$logger->error("Docker container $name did not start on host " . $self->name);
	}	
	
	$out = `$dockerHostString docker port $name`;
	print $logFileHandle "$dockerHostString docker port $name\n";
	print $logFileHandle "$out\n";
	
	my %portMap;
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		if (	$line =~ /(\d+)\/.*\:(\d+)\s*$/) {
			$portMap{$1} = $2;
		}
	}
		
	return \%portMap;
	
}

sub dockerGetLogs {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerExists($logFileHandle, $name)) {
		my $out = `$dockerHostString docker logs $name 2>&1`;
		return $out;
	}
	return "";
}

sub dockerFollowLogs {
	my ( $self, $logFileHandle, $name, $outFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	
	my $dockerHostString  = $self->dockerHostString;
	$logger->debug("dockerFollowLogs name = $name, outfile = $outFile, dockerHostString = $dockerHostString");
	
	if ($self->dockerExists($logFileHandle, $name)) {
		my $out = `$dockerHostString docker logs --follow $name 2>&1 > $outFile`;
		return $out;
	}
	return "";
}

sub dockerVolumeCreate {
	my ( $self, $logFileHandle, $volumeName, $volumeSize ) = @_;
	print $logFileHandle "dockerVolumeCreate $volumeName\n";
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerVolumeCreate $volumeName");
	
	my $dockerHostString  = $self->dockerHostString;
	my $cmd = "$dockerHostString docker volume create --name $volumeName ";
	if ($self->getParamValue('vicHost')) {
		# Add capacity
		$cmd .= "--opt Capacity=" . $volumeSize;
	}
	
	$logger->debug("dockerVolumeCreate cmd = $cmd");
	print $logFileHandle "$cmd\n";
	my $out = `$cmd`;
	$logger->debug("dockerVolumeCreate out = $out");
	print $logFileHandle "$out\n";

}

sub dockerVolumeExists {
	my ( $self, $volumeName ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerVolumeExists $volumeName");
	
	my $dockerHostString  = $self->dockerHostString;
	my $cmd = "$dockerHostString docker volume ls -q";
	my $out = `$cmd`;
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		chomp($line);
		if ($line eq $volumeName) {
			$logger->debug("dockerVolumeExists $volumeName exists");
			return 1;				
		}	
	} 	
	$logger->debug("dockerVolumeExists $volumeName does not exist");
	return 0;	
}

sub dockerRm {
	my ( $self, $logFileHandle, $name ) = @_;
	print $logFileHandle "dockerRm $name\n";
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerExists($logFileHandle, $name)) {
		my $out = `$dockerHostString docker rm -f $name 2>&1`;
		print $logFileHandle "$dockerHostString docker rm -f $name\n";
		print $logFileHandle "$out\n";
	}
}

sub dockerGetIp {
	my ( $self,  $name ) = @_;
	my $dockerHostString  = $self->dockerHostString;	
	my $out;
	if ($self->getParamValue('vicHost')) {
		$out = `$dockerHostString docker inspect --format '{{ .NetworkSettings.Networks.bridge.IPAddress }}' $name 2>&1`;			
	} else {
		$out = `$dockerHostString docker inspect --format '{{ .NetworkSettings.IPAddress }}' $name 2>&1`;
	}
	chomp($out);
	return $out;
}

sub dockerGetExternalNetIP {
	my ( $self, $name, $dockerNetName) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerGetExternalNetIP.  name = $name, dockerNetName = $dockerNetName");
	my $dockerHostString  = $self->dockerHostString;
	my $cmd = "$dockerHostString docker inspect --format '{{ .NetworkSettings.Networks.$dockerNetName.IPAddress }}' $name 2>&1";
	$logger->debug("command: $cmd");
	my $out = `$cmd`;
	chomp($out);
	$logger->debug("dockerGetExternalNetIP.  name = $name, dockerNetName = $dockerNetName, ipAddr = $out");
	return $out;
}

sub dockerExec {
	my ( $self, $logFileHandle, $name, $commandString ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $hostname = $self->name;
	my $dockerHostString  = $self->dockerHostString;
	
	$logger->debug("name = $name, hostname = $hostname");
		
	my $out = `$dockerHostString docker exec $name $commandString 2>&1`;
	$logger->debug("$dockerHostString docker exec $name $commandString 2>&1");
	print $logFileHandle "$dockerHostString docker exec $name $commandString 2>&1\n";
	$logger->debug("docker exec output: $out");
	print $logFileHandle "$out\n";
	
	return $out;
}

sub dockerCopyTo {
	my ( $self, $logFileHandle, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	
	my $dockerHostString  = $self->dockerHostString;
	$logger->debug("dockerCopyTo serviceName = $name");
	my $cmdString = "$dockerHostString docker cp $sourceFile $name:$destFile 2>&1";
	my $out = `$cmdString`;
	$logger->debug("$cmdString");
	print $logFileHandle "$cmdString\n";
	$logger->debug("docker cp output: $out");
	print $logFileHandle "$out\n";
	
	return $out;
}

sub dockerCopyFrom {
	my ( $self, $logFileHandle, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;
	$logger->debug("dockerCopyTo serviceName = $name");
	my $cmdString = "$dockerHostString docker cp $name:$sourceFile $destFile 2>&1";
	my $out = `$cmdString`;
	$logger->debug("$cmdString");
	print $logFileHandle "$cmdString\n";
	$logger->debug("docker cp output: $out");
	print $logFileHandle "$out\n";
	
	return $out;
}

# In the weathervane config file, CPU limits are specified using Kubernetes 
# notation.  Were we convert these to Docker notation for use in Docker commands.
# The strings have already been validated for proper K8S notation
sub convertK8sCpuString {
	my ( $self, $k8sCpuString ) = @_;
	my $dockerCpuString = $k8sCpuString;
	# A K8S CPU limit should be either a real number (e.g. 1.5), which
	# is legal docker notation, or an integer followed an "m" to indicate a millicpu
	if ($k8sCpuString =~ /(\d+)m$/) {
		$dockerCpuString = $1 * 0.001;
	}
	return $dockerCpuString;
}

# In the weathervane config file, memory limits are specified using Kubernetes 
# notation.  Were we convert these to Docker notation for use in Docker commands.
# The strings have already been validated for proper K8S notation
sub convertK8sMemString {
	my ( $self, $k8sMemString ) = @_;
	# Both K8s and Docker Memory limits are an integer followed by an optional suffix.
	# The legal suffixes in K8s are:
	#  * E, P, T, G, M, K (powers of 10)
	#  * Ei, Pi, Ti, Gi, Mi, Ki (powers of 2)
	# The legal suffixes in Docker are:
	#  * g, m, k, b (powers of 2)
	$k8sMemString =~ /^(\d+)(.*)$/;
	my $dockerMemString = $1;
	my $suffix = $2;
	if ($suffix) {
		if ($suffix =~ /i/) {
			# Already a power of 2 notation
			if ($suffix =~ /E/) {
				$dockerMemString *= 1024 * 1024 * 1024;
				$suffix = "g";
			} elsif ($suffix =~ /P/) {				
				$dockerMemString *= 1024 * 1024;
				$suffix = "g";
			} elsif ($suffix =~ /T/) {
				$dockerMemString *= 1024;
				$suffix = "g";				
			} else {
				$suffix =~ /(.)i/;
				$suffix = lc($1);
			}
		} else {
			# Power of 10 notation
			if ($suffix =~ /E/) {
				$dockerMemString *= 1000 * 1000 * 1000;
				# Convert from G to Gi
				$dockerMemString = trunc(round($dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /P/) {				
				$dockerMemString *= 1000 * 1000;
				# Convert from G to Gi
				$dockerMemString = trunc(round($dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /T/) {
				$dockerMemString *= 1000;
				# Convert from G to Gi
				$dockerMemString = trunc(round($dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /G/) {				
				# Convert from G to Gi
				$dockerMemString = trunc(round($dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /M/) {				
				# Convert from M to Mi
				$dockerMemString = trunc(round($dockerMemString * 0.9537));
				$suffix = "m";
			} elsif ($suffix =~ /K/) {				
				# Convert from K to Ki
				$dockerMemString = trunc(round($dockerMemString * 0.9766));
				$suffix = "k";
			} 	
		}
	}
	return "$dockerMemString$suffix";
}

override 'startStatsCollection' => sub {
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	super();

	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $console_logger   = get_logger("Console");
	my $hostname         = $self->name;

};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	super();
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug( "StopStatsCollect for " . $self->name );

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	super();

	my $hostname         = $self->name;

};

override 'cleanStatsFiles' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
		
	super();

};

override 'getLogFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	super();
};

override 'cleanLogFiles' => sub {
	my ($self)   = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	super();
};

override 'parseLogFiles' => sub {
	my ($self) = @_;
	super();

};

override 'getConfigFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	super();

};

override 'parseStats' => sub {
	my ( $self, $storagePath ) = @_;
	super();

};

override 'getStatsSummary' => sub {
	my ( $self, $statsFileDir ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $hostname = $self->name;
	$logger->debug("getStatsSummary on $hostname.");

	my $csvRef = ParseSar::parseSar( $statsFileDir, "${hostname}_sar.txt" );

	my $superCsvRef = super();
	for my $key ( keys %$superCsvRef ) {
		$superCsvRef->{$key} = $superCsvRef->{$key};
	}
	return $csvRef;
};

__PACKAGE__->meta->make_immutable;

1;

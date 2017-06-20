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
package DockerRole;

use Moose::Role;
use MooseX::Storage;
use MIME::Base64;
use Log::Log4perl qw(get_logger);
use Utils qw(getIpAddress);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub dockerExists {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("name = $name");
	print $logFileHandle "dockerStopAndRemove for $name " . $self->hostName .  " \n";
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerExists($logFileHandle, $name)) {
	print $logFileHandle "dockerStopAndRemove $name exists on" . $self->hostName .  "\n";
		$logger->debug("name = $name, exists");
		if ($self->dockerIsRunning($logFileHandle, $name)) {
			print $logFileHandle "dockerStopAndRemove $name is running on" . $self->hostName .  "\n";
			$logger->debug("name = $name, isRunning.  Stopping.");
			my $out = `$dockerHostString docker stop $name`;
			print $logFileHandle "$dockerHostString docker stop $name\n";
			print $logFileHandle "$out\n";
		}
	
		$logger->debug("name = $name, Removing.");
		my $out = `$dockerHostString docker rm -f $name`;
		print $logFileHandle "$dockerHostString docker rm -f $name\n";
		print $logFileHandle "$out\n";
		$logger->debug("name = $name, Result of remove: $out");
		print $logFileHandle "name = $name, Result of remove: $out\n";
	}	
	
}

sub dockerStart {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
		die "Docker container $name did not start on host " . $self->hostName;
	}	
	
	return $self->dockerPort( $name);
	
}

sub dockerPort {
	my ( $self, $name) = @_;
	my $dockerHostString  = $self->dockerHostString;
	my $out = `$dockerHostString docker port $name`;	
	my %portMap;
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		$line =~ /(\d+)\/.*\:(\d+)\s*$/;
		$portMap{$1} = $2;
	}
	
	return \%portMap;
	
}

sub dockerRestart {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("name = $name");
	my $dockerHostString  = $self->dockerHostString;
	
	my $out = `$dockerHostString docker restart $name`;
	print $logFileHandle "$dockerHostString docker restart $name\n";
	print $logFileHandle "$out\n";
	
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $logcontents = $self->dockerGetLogs($logFileHandle, $name);
		print $logFileHandle "Error: Container did not start.  Logs:\n";
		print $logFileHandle $logcontents;
		die "Docker container $name did not start on host " . $self->hostName;
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

sub dockerReload {
	my ( $self, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
		$line =~ /(\d+)\/.*\:(\d+)\s*$/;
		$portMap{$1} = $2;
	}
	
	return \%portMap;
	
}

sub dockerPull {
	my ( $self, $logFileHandle, $impl) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("dockerPull for host ", $self->hostName, ", impl = $impl");
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
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("name = $name");

	my $version  = $self->getParamValue('dockerWeathervaneVersion');
	my $dockerHostString  = $self->dockerHostString;
	my $imagesHashRef = $self->getParamValue('dockerServiceImages');
	my $imageName = $imagesHashRef->{$impl};
	my $namespace = $self->getParamValue('dockerNamespace');
	
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
	if (defined $dockerConfigHashRef->{"cpus"} && $dockerConfigHashRef->{"cpus"}) {
		$cpusString = sprintf("--cpus=%0.2f", $dockerConfigHashRef->{"cpus"});
	}

	my $cpuSetCpusString = "";
	if (defined $dockerConfigHashRef->{"cpuset-cpus"} && $dockerConfigHashRef->{"cpuset-cpus"}) {
		$cpuSetCpusString = "--cpuset-cpus=". $dockerConfigHashRef->{"cpuset-cpus"};
	}

	my $cpuSetMemsString = "";
	if (defined $dockerConfigHashRef->{"cpuset-mems"} && $dockerConfigHashRef->{"cpuset-mems"}) {
		$cpuSetMemsString = "--cpuset-mems=". $dockerConfigHashRef->{"cpuset-mems"};
	}
	
	my $memoryString = "";
	if (defined $dockerConfigHashRef->{"memory"} && $dockerConfigHashRef->{"memory"}) {
		$memoryString = "--memory=". $dockerConfigHashRef->{"memory"};
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
	
	my $cmdString = "$dockerHostString docker create --sysctl kernel.sem='250 32000 32 2000' --ulimit nofile=1048576:1048576 $envString $volumeString $netString $portString "
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
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("name = $name");

	my $version  = $self->getParamValue('dockerWeathervaneVersion');
	my $dockerHostString  = $self->dockerHostString;
	my $imagesHashRef = $self->getParamValue('dockerServiceImages');
	my $imageName = $imagesHashRef->{$impl};
	my $namespace = $self->getParamValue('dockerNamespace');
	
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

	my $cpusString = "";
	if (defined $dockerConfigHashRef->{"cpus"} && $dockerConfigHashRef->{"cpus"}) {
		$cpusString = sprintf("--cpus=%0.2f", $dockerConfigHashRef->{"cpus"});
	}
	
	my $cpuSharesString = "";
	if (defined $dockerConfigHashRef->{"cpu-shares"} && $dockerConfigHashRef->{"cpu-shares"}) {
		$cpuSharesString = "--cpu-shares=". $dockerConfigHashRef->{"cpu-shares"};
	}

	my $cpuSetCpusString = "";
	if (defined $dockerConfigHashRef->{"cpuset-cpus"} && $dockerConfigHashRef->{"cpuset-cpus"}) {
		$cpuSetCpusString = "--cpuset-cpus=". $dockerConfigHashRef->{"cpuset-cpus"};
	}

	my $cpuSetMemsString = "";
	if (defined $dockerConfigHashRef->{"cpuset-mems"} && $dockerConfigHashRef->{"cpuset-mems"}) {
		$cpuSetMemsString = "--cpuset-mems=". $dockerConfigHashRef->{"cpuset-mems"};
	}
	
	my $memoryString = "";
	if (defined $dockerConfigHashRef->{"memory"} && $dockerConfigHashRef->{"memory"}) {
		$memoryString = "--memory=". $dockerConfigHashRef->{"memory"};
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
	
	my $cmdString = "$dockerHostString docker run --sysctl kernel.sem='250 32000 32 2000' --ulimit nofile=1048576:1048576 -d $envString $volumeString $netString $portString "
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
		$logger->error("Docker container $name did not start on host " . $self->hostName);
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

sub dockerGetLogs {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	$logger->debug("name = $name");
	
	my $dockerHostString  = $self->dockerHostString;
	
	if ($self->dockerExists($logFileHandle, $name)) {
		my $out = `$dockerHostString docker logs $name 2>&1`;
		return $out;
	}
	return "";
}

sub dockerRm {
	my ( $self, $logFileHandle, $name ) = @_;
	print $logFileHandle "dockerRm $name\n";
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
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
	my $out = `$dockerHostString docker inspect --format '{{ .NetworkSettings.IPAddress }}' $name 2>&1`;
	chomp($out);
	return $out;
}

sub dockerExec {
	my ( $self, $logFileHandle, $name, $commandString ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	my $hostname = $self->hostName;
	my $dockerHostString  = $self->dockerHostString;
	
	$logger->debug("name = $name, hostname = $hostname");
		
	my $out = `$dockerHostString docker exec $name $commandString 2>&1`;
	print $logFileHandle "$dockerHostString docker exec $name $commandString 2>&1\n";
	print $logFileHandle "$out\n";
	
	return $out;
}

sub dockerScpFileTo {
	my ( $self, $logFileHandle, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	my $hostname = $self->hostName;
	my $scpConnectString = $self->scpConnectString;
	my $localHostname    = `hostname`;
	chomp($localHostname);
	my $localHostIP   = getIpAddress($localHostname);
	
	my $maxRetries = 5;
	
	while ($maxRetries > 0) {
		my $scpString = "sh -c \"$scpConnectString root\@$localHostIP:$sourceFile $destFile\"";
		$logger->debug("hostname = $hostname, localHostIP = $localHostIP, name = $name, scpString = $scpString");
		my $out = $self->dockerExec($logFileHandle, $name, $scpString);
		if ($out =~ /Connection\stimed\sout/) {
		  $maxRetries--;		
		} else {
		  last;
		}
	}
}

sub dockerScpFileFrom {
	my ( $self, $logFileHandle, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerRole");
	my $hostname = $self->hostName;
	my $scpConnectString = $self->scpConnectString;
	my $localHostname    = `hostname`;
	chomp($localHostname);
	my $localHostIP   = getIpAddress($localHostname);

	my $maxRetries = 5;
	
	while ($maxRetries > 0) {
		my $scpString = "sh -c \"$scpConnectString $sourceFile root\@$localHostIP:$destFile\"";
		$logger->debug("hostname = $hostname, localHostIP = $localHostIP, name = $name, scpString = $scpString");
		my $out = $self->dockerExec($logFileHandle, $name, $scpString);
			if ($out =~ /Connection\stimed\sout/) {
		  $maxRetries--;		
		} else {
		  last;
		}
	}
}

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package DockerHost;

use Moose;
use MooseX::Storage;
use MIME::Base64;
use POSIX;
use Log::Log4perl qw(get_logger);
use ComputeResources::Host;
use namespace::autoclean;
use Utils qw(runCmd);

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
	my $logger         = get_logger("Weathervane::Hosts::DockerHost");
	my $servicesRef    = $self->servicesRef;

	my $dockerName = $serviceRef->name;
	$logger->debug( "Registering service $dockerName with host ",
		$self->name );

	if ( exists $self->dockerNameHashRef->{$dockerName} ) {
		$console_logger->error( "Have two services on host ",
			$self->name, " with docker name $dockerName." );
		exit(-1);
	}
	$self->dockerNameHashRef->{$dockerName} = 1;

	push @$servicesRef, $serviceRef;

};

sub dockerExists {
	my ( $self, $logFileHandle, $name ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;
	
	my ($cmdFailed, $out) = runCmd("$dockerHostString docker ps -a", 0);
	if ($cmdFailed) {
		$logger->error("dockerExists docker ps failed: $cmdFailed");
	}
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
	
	my ($cmdFailed, $out) = runCmd("$dockerHostString docker ps", 0);
	if ($cmdFailed) {
		$logger->error("dockerIsRunning docker ps failed: $cmdFailed");
	}
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
		my ($cmdFailed, $out) = runCmd("$dockerHostString docker stop -t 60 $name");
		if ($cmdFailed) {
			$logger->error("dockerStop docker stop failed: $cmdFailed");
		}
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
		$logger->debug("name = $name, exists, removing");
		my ($cmdFailed, $out) = runCmd("$dockerHostString docker rm -vf $name", 0);
		if ($cmdFailed) {
			$logger->error("dockerStopAndRemove failed: $cmdFailed");
		}
		print $logFileHandle "$dockerHostString docker rm -vf $name\n";
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
		my ($cmdFailed, $out) = runCmd("$dockerHostString docker start $name");
		if ($cmdFailed) {
			$logger->error("dockerStart docker start failed: $cmdFailed");
		}
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

	my ($cmdFailed, $out) = runCmd("$dockerHostString docker network ls", 0);
	if ($cmdFailed) {
		$logger->error("dockerNetIsHostOrExternal failed: $cmdFailed");
	}
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

sub dockerPort {
	my ( $self, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my %portMap;

	my $dockerHostString  = $self->dockerHostString;
	my ($cmdFailed, $out) = runCmd("$dockerHostString docker port $name");
	if ($cmdFailed) {
		$logger->error("dockerPort failed: $cmdFailed");
	}
	my @lines = split /\n/, $out;
	foreach my $line (@lines) {
		if ($line =~ /(\d+)\/.*\:(\d+)\s*$/) {
			$portMap{$1} = $2;
		}
	}
	
	return \%portMap;
	
}

sub dockerKill {
	my ( $self, $signal, $logFileHandle, $name) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerKill name = $name");
	my $dockerHostString  = $self->dockerHostString;
	
	my ($cmdFailed, $out) = runCmd("$dockerHostString docker kill --signal $signal $name");
	if ($cmdFailed) {
		$logger->error("dockerKill failed: $cmdFailed");
	}
	print $logFileHandle "$dockerHostString docker kill --signal $signal $name\n";
	print $logFileHandle "$out\n";

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

	my ($cmdFailed, $out) = runCmd("$dockerHostString docker pull $namespace/$imageName:$version");
	if ($cmdFailed) {
		$logger->error("dockerPull failed: $cmdFailed");
	}
	print $logFileHandle "$dockerHostString docker pull $namespace/$imageName:$version\n";
	print $logFileHandle "$out\n";

}

sub dockerRun {
	my ( $self, $logFileHandle, $name, $impl, $directMap, $portMapHashRef, $volumeMapHashRef, 
		$envVarHashRef, $dockerConfigHashRef, $entryPoint, $cmd, $needsTty) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerRun name = $name, impl = $impl, envVarHashRef values = " . (values %$envVarHashRef));

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

	#only apply docker cpu and memory limits to the tomcat appServer containers
	my $applyLimits = 0;
	if ( $impl eq "tomcat" ) {
		$applyLimits = 1;
	}

	my $cpusString = "";
	my $cpuSetCpusString = "";
	if ($applyLimits && defined $dockerConfigHashRef->{"cpus"} && $dockerConfigHashRef->{"cpus"}) {
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
	if ($applyLimits && defined $dockerConfigHashRef->{"memory"} && $dockerConfigHashRef->{"memory"}) {
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
		. " --name $name $namespace/$imageName:$version $cmd";
	my $cmdFailed;
	my $out;
	($cmdFailed, $out) = runCmd($cmdString);
	if ($cmdFailed) {
		$logger->error("dockerRun docker run failed: $cmdFailed");
	}
	print $logFileHandle "$cmdString\n";
	print $logFileHandle "$out\n";
		
	if (!$self->dockerIsRunning($logFileHandle, $name)) {
		my $logcontents = $self->dockerGetLogs($logFileHandle, $name);
		print $logFileHandle "Error: Container did not start.  Logs:\n";
		print $logFileHandle $logcontents;
		$logger->error("Docker container $name did not start on host " . $self->name);
	}	
	
	($cmdFailed, $out) = runCmd("$dockerHostString docker port $name");
	if ($cmdFailed) {
		$logger->error("dockerRun docker port failed: $cmdFailed");
	}
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
	my $maxLogLines = $self->getParamValue('maxLogLines');
	
	if ($self->dockerExists($logFileHandle, $name)) {
		my $out;
		my $cmdFailed;
		if ($maxLogLines > 0) {
			($cmdFailed, $out) = runCmd("$dockerHostString docker logs --tail $maxLogLines $name");
			if ($cmdFailed) {
				$logger->error("dockerGetLogs with tail failed: $cmdFailed");
			}
		} else {
			($cmdFailed, $out) = runCmd("$dockerHostString docker logs $name");
			if ($cmdFailed) {
				$logger->error("dockerGetLogs failed: $cmdFailed");
			}
		}
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
		my ($cmdFailed, $out) = runCmd("$dockerHostString docker logs --follow $name > $outFile");
		if ($cmdFailed) {
			$logger->error("dockerFollowLogs failed: $cmdFailed");
		}
		return $out;
	}
	return "";
}

sub dockerVolumeExists {
	my ( $self, $volumeName ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	$logger->debug("dockerVolumeExists $volumeName");
	
	my $dockerHostString  = $self->dockerHostString;
	my $cmd = "$dockerHostString docker volume ls -q";
	my ($cmdFailed, $out) = runCmd($cmd);
	if ($cmdFailed) {
		$logger->error("dockerVolumeExists failed: $cmdFailed");
	}
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

sub dockerGetIp {
	my ( $self,  $name ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;	
	my $out;
	my $cmdFailed;
	if ($self->getParamValue('vicHost')) {
		($cmdFailed, $out) = runCmd("$dockerHostString docker inspect --format '{{ .NetworkSettings.Networks.bridge.IPAddress }}' $name");
		if ($cmdFailed) {
			$logger->error("dockerGetIp failed vicHost: $cmdFailed");
		}
	} else {
		$logger->debug("dockerGetIp: Getting ip address for container $name on host " . $self->name);
		($cmdFailed, $out) = runCmd("$dockerHostString docker inspect --format '{{ .NetworkSettings.IPAddress }}' $name");
		if ($cmdFailed) {
			$logger->error("dockerGetIp failed: $cmdFailed");
		}
	}
	chomp($out);
	return $out;
}

sub dockerExec {
	my ( $self, $logFileHandle, $name, $commandString ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $hostname = $self->name;
	my $dockerHostString  = $self->dockerHostString;
	
	$logger->debug("name = $name, hostname = $hostname");
		
	my ($cmdFailed, $out) = runCmd("$dockerHostString docker exec $name $commandString", 0);
	if ($cmdFailed) {
		$logger->info("dockerExec failed: $cmdFailed");
	}
	$logger->debug("$dockerHostString docker exec $name $commandString");
	print $logFileHandle "$dockerHostString docker exec $name $commandString\n";
	$logger->debug("docker exec output: $out");
	print $logFileHandle "$out\n";
	
	return ($cmdFailed, $out);
}

sub dockerCopyTo {
	my ( $self, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;
	$logger->debug("dockerCopyTo serviceName = $name");
	if ( $sourceFile =~ /\*/ ) {
		$logger->error("dockerCopyTo error, docker cp does not support wildcards: $sourceFile");
	}
	my $cmdString = "$dockerHostString docker cp $sourceFile $name:$destFile";
	my ($cmdFailed, $out) = runCmd($cmdString, 0);
	if ($cmdFailed) {
		$logger->error("dockerCopyTo failed: $cmdFailed");
	}
	$logger->debug("docker cp output: $out");
	
	return $out;
}

sub dockerCopyFrom {
	my ( $self, $logFileHandle, $name, $sourceFile, $destFile ) = @_;
	my $logger = get_logger("Weathervane::Hosts::DockerHost");
	my $dockerHostString  = $self->dockerHostString;
	$logger->debug("dockerCopyFrom serviceName = $name");
	if ( $sourceFile =~ /\*/ ) {
		$logger->error("dockerCopyFrom error, docker cp does not support wildcards: $sourceFile");
	}
	my $cmdString = "$dockerHostString docker cp $name:$sourceFile $destFile";
	my ($cmdFailed, $out) = runCmd($cmdString, 0);
	if ($cmdFailed) {
		$logger->error("dockerCopyFrom failed: $cmdFailed");
	}
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
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /P/) {				
				$dockerMemString *= 1000 * 1000;
				# Convert from G to Gi
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /T/) {
				$dockerMemString *= 1000;
				# Convert from G to Gi
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /G/) {				
				# Convert from G to Gi
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9313));
				$suffix = "g";
			} elsif ($suffix =~ /M/) {				
				# Convert from M to Mi
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9537));
				$suffix = "m";
			} elsif ($suffix =~ /K/) {				
				# Convert from K to Ki
				$dockerMemString = trunc(sprintf("%.0f", $dockerMemString * 0.9766));
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

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
package LinuxGuest;

use Moose;
use MooseX::Storage;
use Services::Service;

use Hosts::GuestHost;
use StatsParsers::ParseSar qw(parseSar);
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);
use JSON;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'GuestHost';

has 'servicesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Service]',
);

has 'portMapHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

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
	super();

	my $hostname   = $self->getParamValue('hostName');
	my $dockerPort = $self->getParamValue('dockerHostPort');
	$self->dockerHostString( "DOCKER_HOST=" . $hostname . ":" . $dockerPort );

};

override 'getCpuMemConfig' => sub {
	my ($self) = @_;
	my $hostname = $self->hostName();

	# determine the CPU count and memory size
	my $cpuInfo =
`ssh  -o 'StrictHostKeyChecking no' root\@$hostname cat /proc/cpuinfo 2>&1`;
	my $numCpus = () = $cpuInfo =~ /processor\s+\:\s+\d/gi;
	$self->cpus($numCpus);

	my $memInfo =
`ssh  -o 'StrictHostKeyChecking no' root\@$hostname cat /proc/meminfo 2>&1`;
	if ( $memInfo =~ /MemTotal:\s+(\d+)\skB/ ) {
		$self->memKb($1);
	}
	else {
		$self->memKb(0);
	}

};

override 'registerService' => sub {
	my ( $self, $serviceRef ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	my $servicesRef    = $self->servicesRef;

	my $dockerName = $serviceRef->getDockerName();
	$logger->debug( "Registering service $dockerName with host ",
		$self->hostName );

	if ( $serviceRef->useDocker() ) {
		if ( exists $self->dockerNameHashRef->{$dockerName} ) {
			$console_logger->error( "Have two services on host ",
				$self->hostName, " with docker name $dockerName." );
			exit(-1);
		}
		$self->dockerNameHashRef->{$dockerName} = 1;
	}

	push @$servicesRef, $serviceRef;

};

sub startNscd {
	my ($self)           = @_;
	my $logger           = get_logger("Weathervane::Hosts::LinuxGuest");
	my $sshConnectString = $self->sshConnectString;
	my $cmdOut           = `$sshConnectString service nscd start 2>&1`;
	$logger->debug( "service nscd start for ",
		$self->hostName, " returned ", $cmdOut );
}

sub stopNscd {
	my ($self)           = @_;
	my $logger           = get_logger("Weathervane::Hosts::LinuxGuest");
	my $sshConnectString = $self->sshConnectString;
	my $cmdOut           = `$sshConnectString \"nscd --invalidate=hosts 2>&1\"`;
	$logger->debug( "nscd --invalidate=hosts for ",
		$self->hostName, " returned ", $cmdOut );
	$cmdOut = `$sshConnectString service nscd stop 2>&1`;
	$logger->debug( "service nscd stop for ",
		$self->hostName, " returned ", $cmdOut );
}

sub restartNtp {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "Updating the time sync for host ", $self->hostName );
	my $sshConnectString = $self->sshConnectString;
	my $scpConnectString = $self->scpConnectString;
	my $scpHostString    = $self->scpHostString;

	if ( $self->getParamValue('harnessHostNtpServer') ) {

		# Copy the ntp.conf to each host
`$scpConnectString /tmp/ntp.conf root\@$scpHostString:/etc/ntp.conf 2>&1`;
	}

	my $out = `$sshConnectString service ntpd restart 2>&1`;
	$logger->debug( "Restarted ntpd on ", $self->hostName, ", output: $out" );
}

sub openPortNumber {
	my ( $self, $portNumber ) = @_;
	my $logger           = get_logger("Weathervane::Hosts::LinuxGuest");
	my $sshConnectString = $self->sshConnectString;

	$logger->debug( "Adding iptables rule to ",
		$self->hostName, " to open port $portNumber for input" );
`$sshConnectString iptables -I INPUT -p tcp --dport $portNumber -j ACCEPT 2>&1`;

}

sub closePortNumber {
	my ( $self, $portNumber ) = @_;
	my $logger           = get_logger("Weathervane::Hosts::LinuxGuest");
	my $sshConnectString = $self->sshConnectString;

	$logger->debug( "Removing iptables rule from ",
		$self->hostName, " to close port $portNumber for input" );
`$sshConnectString iptables -D INPUT -p tcp --dport $portNumber -j ACCEPT 2>&1`;
}

# Services use this method to notify the host that they are using
# a particular port number
override 'registerPortNumber' => sub {
	my ( $self, $portNumber, $service ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "Registering port $portNumber for host ", $self->hostName );

	my $portMapHashRef = $self->portMapHashRef;

	if ( exists $portMapHashRef->{$portNumber} ) {

		# Notify about conflict and exit
		my $conflictService = $portMapHashRef->{$portNumber};
		$console_logger->error(
			"Conflict on port $portNumber on host ",
			$self->hostName,
			". Required by both ",
			$conflictService->getDockerName(),
			" from Workload ",
			$conflictService->getWorkloadNum(),
			" AppInstance ",
			$conflictService->getAppInstanceNum(),
			" and ",
			$service->getDockerName(),
			" from Workload ",
			$service->getWorkloadNum(),
			" AppInstance ",
			$service->getAppInstanceNum(),
			"."
		);
		exit(-1);
	}

	$portMapHashRef->{$portNumber} = $service;
	$self->openPortNumber($portNumber);
};

override 'unRegisterPortNumber' => sub {
	my ( $self, $portNumber ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "Unregistering port $portNumber for host ",
		$self->hostName );

	my $portMapHashRef = $self->portMapHashRef;
	if ( exists $portMapHashRef->{$portNumber} ) {
		delete $portMapHashRef->{$portNumber};
		$self->closePortNumber($portNumber);
	}
};

sub initializeCpusForPinning {
	my ( $self, $pinMode, $hostNumCpus ) = @_;
	my $cpuNum  = 0;
	my $cpuStep = 1;
	if ( $pinMode eq 'odd' ) {
		$cpuNum = 1;
	}
	if ( $pinMode ne 'all' ) {
		$cpuStep = 2;
	}

	# use IxHash so that CPU numbers (keys) remain in-order
	tie( my %cpusForPinning, 'Tie::IxHash' );
	while ( $cpuNum < $hostNumCpus ) {
		$cpusForPinning{$cpuNum} = 1;
		$cpuNum += $cpuStep;
	}
	return \%cpusForPinning;
}

override 'configureDockerPinning' => sub {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $pin            = $self->getParamValue('dockerHostPin');
	my $pinMode        = $self->getParamValue('dockerHostPinMode');

	$self->getCpuMemConfig();

	if ( !$pin ) {
		return;
	}

	my $numCpus = $self->cpus;
	my $memKb   = $self->memKb;

	my $cpusForPinningHashRef =
	  $self->initializeCpusForPinning( $pinMode, $numCpus );
	my $servicesRef = $self->servicesRef;

	# Remove CPUs that are pre-selected for pinning if user
	# defined a cpuSet for a service
	foreach my $serviceHashRef (@$servicesRef) {
		my $svcDocker              = $serviceHashRef->useDocker();
		my $svcDockerConfigHashRef = $serviceHashRef->dockerConfigHashRef;
		my $name                   = $serviceHashRef->getDockerName();
		if (   !$svcDocker
			|| !exists( $svcDockerConfigHashRef->{"cpuset-cpus"} ) )
		{
			next;
		}

		if ( defined( $svcDockerConfigHashRef->{"cpus"} ) ) {
			$console_logger->warn(
"Notice: dockerConfig for service $name specifies both cpus and cpuset.",
				" Only cpuset specification will be used."
			);
		}

		my $cpuSet = $svcDockerConfigHashRef->{"cpuset-cpus"};
		my @cpuSetRanges = split( /\s*,\s*/, $cpuSet );
		foreach my $range (@cpuSetRanges) {
			my ( $start, $end ) = split( /\s*-\s*/, $range );
			if ( defined($end) ) {
				for ( my $i = $start ; $i <= $end ; $i++ ) {
					delete $cpusForPinningHashRef->{$i};
				}
			}
			else {
				delete $cpusForPinningHashRef->{$start};
			}
		}
	}

	foreach my $serviceHashRef (@$servicesRef) {
		my $svcDocker              = $serviceHashRef->useDocker();
		my $svcDockerConfigHashRef = $serviceHashRef->dockerConfigHashRef;
		my $name                   = $serviceHashRef->getDockerName();

		if ( !$svcDocker || exists( $svcDockerConfigHashRef->{"cpuset-cpus"} ) )
		{
			next;
		}

		my $svcNumCpus = $svcDockerConfigHashRef->{"cpus"};

		if ( !defined($svcNumCpus) ) {
			$console_logger->error(
"When using Docker pinning, must specify the number of CPUs for service "
				  . $serviceHashRef->getParamValue('dockerName')
				  . " in dockerCpus" );
			exit(-1);
		}

		if ( $svcNumCpus > $numCpus ) {
			$console_logger->error(
"Number of cpus specified for service $name is greater than the number of cpus on the host ",
				$self->hostName
			);
			exit(-1);
		}

		my @cpuSetCpus = ();
		while ( $svcNumCpus > 0 ) {
			my @cpusForPinning = keys %$cpusForPinningHashRef;
			if ( $#cpusForPinning == -1 ) {

# Have run out of available CPUs before determining a pinning for all Service CPUs
# Reset the list and print a warning
				$console_logger->warn(
"Notice: CPUs are overcommitted for pinning on Docker host ",
					$self->hostName,
", Pinning for service $name may use an unexpected combination of CPUs."
				);
				$cpusForPinningHashRef =
				  $self->initializeCpusForPinning( $pinMode, $numCpus );
				@cpusForPinning = keys %$cpusForPinningHashRef;
			}

			foreach my $cpuNum (@cpusForPinning) {
				push @cpuSetCpus, $cpuNum;
				delete $cpusForPinningHashRef->{$cpuNum};
				$svcNumCpus--;
				if ( $svcNumCpus == 0 ) {
					last;
				}
			}
		}
		$svcDockerConfigHashRef->{"cpuset-cpus"} = join( ",", @cpuSetCpus );
	}

# Check for over-committing and other issues
# Tests:
#	  - Die if haven't specified either cpus or cpuset and docker svc is running on a host with pinning
	my $assignedCpus  = 0;
	my $assignedmemKb = 0;
	foreach my $serviceHashRef (@$servicesRef) {
		my $svcDocker              = $serviceHashRef->useDocker();
		my $svcDockerConfigHashRef = $serviceHashRef->dockerConfigHashRef;
		my $name                   = $serviceHashRef->getDockerName();

		if (   $pin
			&& !defined( $svcDockerConfigHashRef->{"cpu-shares"} )
			&& !defined( $svcDockerConfigHashRef->{"cpuset-cpus"} ) )
		{
			$console_logger->error(
				"Host ",
				$self->hostName,
" has pin enabled for Dockerized services, but service $name doesn't specify either cpus or cpuset."
			);
			exit(-1);
		}

	}

	# Open the docker port on this host
	my $dockerPort = $self->getParamValue('dockerHostPort');
	$self->openPortNumber($dockerPort);

};

override 'startStatsCollection' => sub {
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $console_logger   = get_logger("Console");
	my $hostname         = $self->hostName;
	my $sshConnectString = $self->sshConnectString;

	my $pid = fork();
	if ( !defined $pid ) {
		$console_logger->error(
			"For hostname $hostname, couldn't fork a process: $!");
	}
	elsif ( $pid == 0 ) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error(
				"For hostname $hostname, couldn't fork a process: $!");
		}
		elsif ( $pid == 0 ) {
			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error(
					"For hostname $hostname, couldn't fork a process: $!");
			}
			elsif ( $pid == 0 ) {

				# get mpstat -I data
				my $cmdOut = `$sshConnectString mpstat -I ALL $intervalLengthSec $numIntervals > /tmp/${hostname}_mpstat.txt `;

				exit;
			}
			else {

				# get sar data
				my $cmdOut = `$sshConnectString sar -o /tmp/${hostname}_sar.out $intervalLengthSec $numIntervals &`;
				$logger->debug("Started sar on $hostname. ");

				exit;
			}
		}
		else {
			# Get socket usage data
			my $logName = "/tmp/$hostname-socketStats.log";
			my $log;
			open( $log, ">$logName" ) || die "Error opening /tmp/$logName:$!";

			my $intervalNum = 1;
			while ( $intervalNum < $numIntervals ) {
				sleep $intervalLengthSec;
				my $cmdOut = `$sshConnectString date`;
				print $log $cmdOut;
				$cmdOut = `$sshConnectString ss -s`;
				print $log $cmdOut;

				$intervalNum++;
			}
			close $log;
			exit;
		}
	}

};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	super();
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "StopStatsCollect for " . $self->hostName );

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

	my $hostname         = $self->hostName;
	my $sshConnectString = $self->sshConnectString;
	my $scpConnectString = $self->scpConnectString;
	my $scpHostString    = $self->scpHostString;
	my $cmdOut           = `$sshConnectString sync 2>&1`;
	$logger->debug( "getStatsFiles from $hostname. sync cmdOut = ", $cmdOut );
	$cmdOut = `mv /tmp/${hostname}_mpstat.txt $destinationPath/. 2>&1 `;
	$logger->debug( "getStatsFiles from $hostname. scp mpstat cmdOut = ",
		$cmdOut );
	$cmdOut =
`$scpConnectString root\@$scpHostString:/tmp/${hostname}_sar.out $destinationPath/. 2>&1 `;
	$logger->debug( "getStatsFiles from $hostname. scp sar cmdOut = ",
		$cmdOut );
	$cmdOut =
`sar -Ap -f $destinationPath/${hostname}_sar.out > $destinationPath/${hostname}_sar.txt 2>&1`;
	$logger->debug( "getStatsFiles from $hostname. sar -Ap cmdOut = ",
		$cmdOut );

	my $logName = "/tmp/$hostname-socketStats.log";
	$cmdOut = `mv $logName $destinationPath/.`;

};

override 'cleanStatsFiles' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	
	if (!$self->isNonDocker()) {
		return;
	}
	
	super();

	my $hostname         = $self->hostName;
	my $sshConnectString = $self->sshConnectString;
	my $cmdOut =
	  `$sshConnectString \"rm -f /tmp/${hostname}_sar.out 2>&1\" 2>&1`;
	$logger->debug( "cleanStatsFiles on $hostname. cmdOut = ", $cmdOut );

};

override 'getLogFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	super();

	my $hostname = $self->hostName;

};

override 'cleanLogFiles' => sub {
	my ($self)   = @_;
	my $logger   = get_logger("Weathervane::Hosts::LinuxGuest");
	my $hostname = $self->hostName;

	
	if (!$self->isNonDocker()) {
		return;
	}

	super();

	my $sshConnectString = $self->sshConnectString;
	my $cmdOut = `$sshConnectString \"nscd --invalidate=hosts 2>&1\" 2>&1`;
	$logger->debug( "cleanLogFiles on $hostname. cmdOut = ", $cmdOut );

};

override 'parseLogFiles' => sub {
	my ($self) = @_;
	super();

};

override 'getConfigFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

	my $hostname         = $self->hostName;
	my $sshConnectString = $self->sshConnectString;
	my $scpConnectString = $self->scpConnectString;
	my $scpHostString    = $self->scpHostString;

	my $out =
`$scpConnectString root\@$scpHostString:/etc/sysctl.conf $destinationPath/. 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 1 out = ", $out );
	$out =
`$scpConnectString root\@$scpHostString:/etc/rc.local $destinationPath/. 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 2 out = ", $out );
	$out =
`$scpConnectString root\@$scpHostString:/etc/fstab $destinationPath/. 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 3 out = ", $out );

	$out =
	  `$sshConnectString \"cat /proc/cpuinfo\" > $destinationPath/cpuinfo 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 4 out = ", $out );
	$out =
`$sshConnectString \"cat /proc/meminfo\" >  $destinationPath/meminfo 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 5 out = ", $out );
	$out =
	  `$sshConnectString \"cat /proc/mounts\" >  $destinationPath/mounts 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 6 out = ", $out );

	$out =
	  `$sshConnectString \"ifconfig\" > $destinationPath/ifconfig.txt 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 7 out = ", $out );
	$out =
`$sshConnectString \"ip route show\" > $destinationPath/ipRouteShow.txt 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 8 out = ", $out );
	$out = `$sshConnectString \"ulimit -a\" > $destinationPath/ulimit.txt 2>&1`;
	$logger->debug( "getConfigFiles on $hostname. 9 out = ", $out );

};

override 'parseStats' => sub {
	my ( $self, $storagePath ) = @_;
	super();

};

override 'getStatsSummary' => sub {
	my ( $self, $statsFileDir ) = @_;
	my $logger   = get_logger("Weathervane::Hosts::LinuxGuest");
	my $hostname = $self->hostName;
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

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
package HaproxyDockerService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'HAProxy', );

has '+version' => ( default => '1.5.0', );

has '+description' => ( default => 'HAProxy revorse-proxy server', );


override 'initialize' => sub {
	my ( $self, $numLbServers ) = @_;

	super();
};

override 'create' => sub {
	my ( $self, $logPath ) = @_;

	if ( !$self->getParamValue('useDocker') ) {
		return;
	}

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $impl     = $self->getImpl();

	my $logName = "$logPath/CreateHaproxyDocker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# The default create doesn't map any volumes
	my %volumeMap;

	# Set environment variables for startup configuration
	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	my $appServersRef  = $self->appInstance->getActiveServicesByType('appServer');

	my $numWebServers = $self->appInstance->getNumActiveOfServiceType('webServer');
	my $numAppServers = $self->appInstance->getNumActiveOfServiceType('appServer');
	my $users = $self->appInstance->getUsers();

	my $maxConn = $self->getParamValue('frontendConnectionMultiplier') * $users;
	if ($self->getParamValue('haproxyMaxConn')) {
		$maxConn = $self->getParamValue('haproxyMaxConn');
	}
	
	my $serverMaxConn = $maxConn;
	if ( $numWebServers == 0 ) {
		$serverMaxConn = $self->getParamValue('haproxyAppServerMaxConn');
	}
	
	my $terminateTLS = $self->getParamValue('haproxyTerminateTLS');
	my $httpHostnames = "";
	my $httpsHostnames = "";
	if ( $numWebServers > 0 ) {
		foreach my $webServer (@$webServersRef) {
			my $httpPort = $self->getPortNumberForUsedService($webServer,"http");
			my $httpsPort = $self->getPortNumberForUsedService($webServer,"https");
			my $hostname = $self->getHostnameForUsedService($webServer);
			$httpHostnames .=  "$hostname:$httpPort,";
			$httpsHostnames .=  "$hostname:$httpsPort,";
		}
	} elsif ( $numAppServers > 0 ) {
		foreach my $appServer (@$appServersRef) {
			my $httpPort = $self->getPortNumberForUsedService($appServer,"http");
			my $httpsPort = $self->getPortNumberForUsedService($appServer,"https");
			my $hostname = $self->getHostnameForUsedService($appServer);
			$httpHostnames .=  "$hostname:$httpPort,";
			$httpsHostnames .=  "$hostname:$httpsPort,";
		}
	}
	chop($httpHostnames);
	chop($httpsHostnames);
		
	my $haproxyNbproc = 1;
	if ($self->getParamValue('haproxyProcPerCpu') || $terminateTLS) {
		$haproxyNbproc            = $self->host->cpus;
		if ($self->getParamValue('dockerCpus')) {
			$haproxyNbproc = $self->getParamValue('dockerCpus');
		}
	}
	
	my %envVarMap;
	$envVarMap{"HAPROXY_HTTP_PORT"} = $self->internalPortMap->{"http"};
	$envVarMap{"HAPROXY_HTTPS_PORT"} = $self->internalPortMap->{"https"};
	$envVarMap{"HAPROXY_STATS_PORT"} = $self->internalPortMap->{"stats"} ;
	$envVarMap{"HAPROXY_MAXCONN"} = $maxConn ;
	$envVarMap{"HAPROXY_SERVER_MAXCONN"} = $serverMaxConn;
	$envVarMap{"HAPROXY_SERVER_HTTPHOSTNAMES"} = "\"$httpHostnames\"";
	$envVarMap{"HAPROXY_SERVER_HTTPSHOSTNAMES"} = "\"$httpsHostnames\"";
	$envVarMap{"HAPROXY_TERMINATETLS"} = $terminateTLS ;
	$envVarMap{"HAPROXY_NBPROC"} = $haproxyNbproc;

	# Create the container
	my %portMap;
	my $directMap = 0;
	my $useVirtualIp     = $self->getParamValue('useVirtualIp');
	if ( $self->isEdgeService() && $useVirtualIp ) {
		# This is an edge service and we are using virtual IPs.  Map the internal ports to the host ports
		$directMap = 1;
	}
	foreach my $key ( keys %{ $self->internalPortMap } ) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}

	my $cmd        = "";
	my $entryPoint = "";

	$self->host->dockerRun(
		$applog, $self->getParamValue('dockerName'),
		$impl, $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef,
		$entryPoint, $cmd, $self->needsTty
	);

	close $applog;
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::HaproxyDockerService");
	$logger->debug("stop HaproxyDockerService");

	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/StopHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop($applog, $name);

	close $applog;
}

sub start {
	my ( $self, $logPath ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/StartHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};				
	} else {
		# For bridged networking, ports get assigned at start time
		my $portMapRef = $self->host->dockerPort($name);
		$self->portMap->{"http"} = $portMapRef->{$self->internalPortMap->{"http"}};
		$self->portMap->{"https"} = $portMapRef->{$self->internalPortMap->{"https"}};
		$self->portMap->{"stats"} = $portMapRef->{$self->internalPortMap->{"stats"}};		
	}
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
}

override 'remove' => sub {
	my ($self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/RemoveHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove($applog, $name);

	close $applog;
};

sub isUp {
	my ( $self, $fileout ) = @_;
	
	if ( !$self->isRunning($fileout) ) {
		return 0;
	}
	
	return 1;
	
}


sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->getParamValue('dockerName');
	return $self->host->dockerIsRunning($fileout, $name);

}

sub setPortNumbers {
	my ( $self ) = @_;
	
	my $serviceType = $self->getParamValue( 'serviceType' );
	my $useVirtualIp     = $self->getParamValue('useVirtualIp');

	my $portOffset = 0;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	if (!$useVirtualIp) {
		$portOffset = $self->getParamValue( $serviceType . 'PortOffset')
		  + ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
	} 
	$self->internalPortMap->{"http"} = 80 + $portOffset;
	$self->internalPortMap->{"https"} = 443 + $portOffset;
	$self->internalPortMap->{"stats"} = 10080 + $portOffset;	
}


sub setExternalPortNumbers {
	my ( $self ) = @_;
	my $name = $self->getParamValue('dockerName');
	
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};				
	} else {
		# For bridged networking, ports get assigned at start time
		my $portMapRef = $self->host->dockerPort($name);
		$self->portMap->{"http"} = $portMapRef->{$self->internalPortMap->{"http"}};
		$self->portMap->{"https"} = $portMapRef->{$self->internalPortMap->{"https"}};
		$self->portMap->{"stats"} = $portMapRef->{$self->internalPortMap->{"stats"}};		
	}
	
}

sub configure {
	my ($self, $logPath, $users, $suffix)            = @_;

}

sub stopStatsCollection {
	my ($self) = @_;

	my $setupLogDir = $self->getParamValue('tmpDir') . "/setupLogs";
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $port =  $self->portMap->{"stats"};

	my $response = `curl -s -o /tmp/HaproxyDockerStopStats-$hostname-$name.csv \"http://$hostname:$port/stats;csv\"`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $setupLogDir = $self->getParamValue('tmpDir') . "/setupLogs";
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $port =  $self->portMap->{"stats"};
	my $response = `curl -s -o /tmp/HaproxyDockerStartStats-$hostname-$name.csv \"http://$hostname:$port/stats;csv\"`;
	
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;

	my $out = `mv /tmp/HaproxyDockerStartStats-$hostname-$name.csv $destinationPath/. 2>&1`;
	$out = `mv /tmp/HaproxyDockerStopStats-$hostname-$name.csv $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ($self) = @_;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/GetStatsFilesHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";
	  	
	my $logContents = $self->host->dockerGetLogs($applog, $name); 
	
	close $applog;

	my $logfile;
	open ( $logfile , ">$logpath/haproxy-$hostname-$name.log")
		or die "Error opening $logpath/haproxy-$hostname-$name.log: $!\n";
		
	print $logfile $logContents;
	
	close $logfile;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::HaproxyDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/GetConfigFilesHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	  	
	$self->host->dockerScpFileFrom($applog, $name, "/etc/haproxy/haproxy.cfg", "$logpath/.");
	
	close $applog;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"haproxyMaxConn"} = $self->getParamValue('haproxyMaxConn');

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

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
package NginxDockerService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'Nginx', );

has '+version' => ( default => '1.7.xx', );

has '+description' => ( default => 'Nginx Web Server', );


override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

override 'create' => sub {
	my ($self, $logPath)            = @_;
	my $useVirtualIp     = $self->getParamValue('useVirtualIp');
	
	if (!$self->getParamValue('useDocker')) {
		return;
	}
	
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $host = $self->host;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	my %volumeMap;
	my $instanceNumber = $self->getParamValue('instanceNum');
	my $dataDir = "/mnt/cache/nginx$instanceNumber";
	if ($host->getParamValue('dockerHostUseNamedVolumes') || $host->getParamValue('vicHost')) {
		$dataDir = $self->getParamValue('nginxCacheVolume') . $instanceNumber;
		# use named volumes.  Create volume if it doesn't exist
		if (!$host->dockerVolumeExists($applog, $dataDir)) {
			# Create the volume
			my $volumeSize = 0;
			if ($host->getParamValue('vicHost')) {
				$volumeSize = $self->getParamValue('nginxCacheVolumeSize');
			}
			$host->dockerVolumeCreate($applog, $dataDir, $volumeSize);
		}
	}	
	$volumeMap{"/var/cache/nginx"} = $dataDir;
		
	my %envVarMap;
	my $users = $self->appInstance->getUsers();
	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getNumActiveOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}
	$envVarMap{'WORKERCONNECTIONS'} = $workerConnections;
	
	my $perServerConnections = floor( 50000.0 / $self->appInstance->getNumActiveOfServiceType('appServer') );
	$envVarMap{'PERSERVERCONNECTIONS'} = $perServerConnections;
	
	$envVarMap{'KEEPALIVETIMEOUT'} = $self->getParamValue('nginxKeepaliveTimeout');
	$envVarMap{'MAXKEEPALIVEREQUESTS'} = $self->getParamValue('nginxMaxKeepaliveRequests');
	$envVarMap{'IMAGESTORETYPE'} = $self->getParamValue('imageStoreType');
	
	$envVarMap{'HTTPPORT'} = $self->internalPortMap->{"http"};
	$envVarMap{'HTTPSPORT'} = $self->internalPortMap->{"https"};
	
	# Add the appserver names for the balancer
	my $appServersRef  =$self->appInstance->getActiveServicesByType('appServer');
	my $appServersString = "";
	my $cnt = 1;
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $self->getHostnameForUsedService($appServer);
		my $appServerPort = $self->getPortNumberForUsedService($appServer, "http");
		$appServersString .= "$appHostname:$appServerPort";
		if ($cnt != (scalar @{ $appServersRef }) ) {
			$appServersString .= ",";
		}
		$cnt++;
	}
	$envVarMap{'APPSERVERS'} = $appServersString;
	
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
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxDockerService");
	$logger->debug("stop NginxDockerService");

	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/StopNginxDocker-$hostname-$name.log";

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
	my $logName          = "$logPath/StartNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	} else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{"http"} = $portMapRef->{$self->internalPortMap->{"http"}};
		$self->portMap->{"https"} = $portMapRef->{$self->internalPortMap->{"https"}};
	}
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
}

override 'remove' => sub {
	my ($self, $logPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/RemoveNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove($applog, $name);

	close $applog;
};

sub isUp {
	my ( $self, $applog ) = @_;
	my $hostname         = $self->getIpAddr();
	my $port = $self->portMap->{"http"};
	
	my $response = `curl -s -w "%{http_code}\n" -o /dev/null http://$hostname:$port`;
	print $applog "curl -s -w \"\%{http_code}\\n\" -o /dev/null http://$hostname:$port\n";
	print $applog "$response\n"; 
	
	if ($response =~ /200$/) {
		return 1;
	} else {
		return 0;
	}
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
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	my $name = $self->getParamValue('dockerName');
	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	} else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{"http"} = $portMapRef->{$self->internalPortMap->{"http"}};
		$self->portMap->{"https"} = $portMapRef->{$self->internalPortMap->{"https"}};
	}
	
}
sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;

}

sub stopStatsCollection {
	my ($self) = @_;

	my $hostname = $self->host->hostName;
	my $port = $self->portMap->{"http"};
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-stopStats.html https://$hostname:$port/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-stopStats.html > /tmp/nginx-$hostname-stopStats.txt 2>&1`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $hostname = $self->host->hostName;
	my $port = $self->portMap->{"http"};
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-startStats.html https://$hostname:$port/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-startStats.html > /tmp/nginx-$hostname-startStats.txt 2>&1`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

	my $out = `mv /tmp/nginx-$hostname-* $destinationPath/. 2>&1`;
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

	my $logName          = "$logpath/NginxDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";
	  	
	my $logContents = $self->host->dockerGetLogs($applog, $name); 
		
	print $applog $logContents;
	
	close $applog;

}


sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::NginxDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $nginxServerRoot  = $self->getParamValue('nginxServerRoot');
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;


	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/GetConfigFilesNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerScpFileFrom($applog, $name, "$nginxServerRoot/*.conf", "$logpath/.");
	$self->host->dockerScpFileFrom($applog, $name, "$nginxServerRoot/conf.d/*.conf", "$logpath/.");
	close $applog;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"nginxKeepaliveTimeout"}     = $self->getParamValue('nginxKeepaliveTimeout');
	$csv{"nginxMaxKeepaliveRequests"} = $self->getParamValue('nginxMaxKeepaliveRequests');
	$csv{"nginxWorkerConnections"}    = $self->getParamValue('nginxWorkerConnections');
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

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

override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

override 'create' => sub {
	my ($self, $logPath)            = @_;
		
	my $name = $self->name;
	my $hostname         = $self->host->name;
	my $host = $self->host;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	my %volumeMap;		
	my %envVarMap;
	my $users = $self->appInstance->getUsers();
	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getTotalNumOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}
	$envVarMap{'WORKERCONNECTIONS'} = $workerConnections;
	
	my $perServerConnections = floor( 50000.0 / $self->appInstance->getTotalNumOfServiceType('appServer') );
	$envVarMap{'PERSERVERCONNECTIONS'} = $perServerConnections;
	
	$envVarMap{'KEEPALIVETIMEOUT'} = $self->getParamValue('nginxKeepaliveTimeout');
	$envVarMap{'MAXKEEPALIVEREQUESTS'} = $self->getParamValue('nginxMaxKeepaliveRequests');
	$envVarMap{'IMAGESTORETYPE'} = $self->getParamValue('imageStoreType');
	
	$envVarMap{'HTTPPORT'} = $self->internalPortMap->{"http"};
	$envVarMap{'HTTPSPORT'} = $self->internalPortMap->{"https"};
	
	# Add the appserver names for the balancer
	my $appServersRef  =$self->appInstance->getAllServicesByType('appServer');
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
};

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxDockerService");
	$logger->debug("stop NginxDockerService");

	my $hostname         = $self->host->name;
	my $name = $self->name;
	my $logName          = "$logPath/StopNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop($applog, $name);

	close $applog;
}

sub startInstance {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->name;
	my $name = $self->name;
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

	close $applog;
}

override 'remove' => sub {
	my ($self, $logPath ) = @_;

	my $name = $self->name;
	my $hostname         = $self->host->name;
	my $logName          = "$logPath/RemoveNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove($applog, $name);

	close $applog;
};

sub isUp {
	my ( $self, $applog ) = @_;
	my $hostname         = $self->host->name;
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
	my $name = $self->name;

	return $self->host->dockerIsRunning($fileout, $name);

}

sub isStopped {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return !$self->host->dockerExists( $fileout, $name );
}

sub setPortNumbers {
	my ( $self ) = @_;
	
	my $serviceType = $self->getParamValue( 'serviceType' );

	my $portOffset = 0;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	$portOffset = $self->getParamValue( $serviceType . 'PortOffset')
	  + ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
	$self->internalPortMap->{"http"} = 80 + $portOffset;
	$self->internalPortMap->{"https"} = 443 + $portOffset;
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	my $name = $self->name;
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

	my $hostname = $self->host->name;
	my $port = $self->portMap->{"http"};
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-stopStats.html https://$hostname:$port/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-stopStats.html > /tmp/nginx-$hostname-stopStats.txt 2>&1`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $hostname = $self->host->name;
	my $port = $self->portMap->{"http"};
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-startStats.html https://$hostname:$port/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-startStats.html > /tmp/nginx-$hostname-startStats.txt 2>&1`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->name;

	my $out = `mv /tmp/nginx-$hostname-* $destinationPath/. 2>&1`;
}

sub cleanStatsFiles {
	my ($self) = @_;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name = $self->name;
	my $hostname         = $self->host->name;

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
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $nginxServerRoot  = $self->getParamValue('nginxServerRoot');
	my $name = $self->name;
	my $hostname         = $self->host->name;


	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/GetConfigFilesNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerCopyFrom($applog, $name, "$nginxServerRoot/*.conf", "$logpath/.");
	$self->host->dockerCopyFrom($applog, $name, "$nginxServerRoot/conf.d/*.conf", "$logpath/.");
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

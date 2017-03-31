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

	my $portMapRef = $self->host->dockerReload($applog, $name);

	if  ($self->getParamValue('dockerNet') eq "host") {
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
	my $hostname         = $self->host->hostName;
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
	my $isEdgeServer = $self->isEdgeService();
	my $portOffset = 0;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	if (!$isEdgeServer) {
		$portOffset = $self->getParamValue( $serviceType . 'PortOffset') +
		  ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
	}
	$self->internalPortMap->{"http"} = 80 + $portOffset;
	$self->internalPortMap->{"https"} = 443 + $portOffset;		
}


sub setExternalPortNumbers {
	my ( $self ) = @_;
	my $name = $self->getParamValue('dockerName');
	my $portMapRef = $self->host->dockerPort($name);

	if  ($self->getParamValue('dockerNet') eq "host") {
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
	my $sshConnectString = $self->host->sshConnectString;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $nginxServerRoot  = $self->getParamValue('nginxServerRoot');
	my $configDir        = $self->getParamValue('configDir');
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/ConfigureNginxDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getNumActiveOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}

	my $perServerConnections = floor( 50000.0 / $self->appInstance->getNumActiveOfServiceType('appServer') );

	# Modify nginx.conf and then copy to web server
	open( FILEIN,  "$configDir/nginx/nginxDocker.conf" ) or die "Can't open file $configDir/nginx/nginx.conf: $!";
	open( FILEOUT, ">/tmp/nginx$suffix.conf" )            or die "Can't open file /tmp/nginx$suffix.conf: $!";

	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /[^\$]upstream/ ) {
			print FILEOUT $inline;
			print FILEOUT "least_conn;\n";
			do {
				$inline = <FILEIN>;
			} while ( !( $inline =~ /}/ ) );

			# Add the balancer lines for each app server
			my $appServersRef  =$self->appInstance->getActiveServicesByType('appServer');

			my $cnt = 1;
			foreach my $appServer (@$appServersRef) {
				my $appHostname = $self->getHostnameForUsedService($appServer);
				my $appServerPort = $self->getPortNumberForUsedService($appServer, "http");
				print FILEOUT "      server $appHostname:$appServerPort max_fails=0 ;\n";
			}
			print FILEOUT "      keepalive 1000;";
			print FILEOUT "    }\n";
		}
		elsif ( $inline =~ /^\s*worker_connections\s/ ) {
			print FILEOUT "    worker_connections " . $workerConnections . ";\n";
		}
		elsif ( $inline =~ /^\s*keepalive_timeout\s/ ) {
			print FILEOUT "    keepalive_timeout " . $self->getParamValue('nginxKeepaliveTimeout') . ";\n";
		}
		elsif ( $inline =~ /^\s*keepalive_requests\s/ ) {
			print FILEOUT "    keepalive_requests " . $self->getParamValue('nginxMaxKeepaliveRequests') . ";\n";
		}
		else {
			print FILEOUT $inline;
		}

	}

	close FILEIN;
	close FILEOUT;
	
	# Push the config file to the docker container 
	$self->host->dockerScpFileTo($applog, $name, "/tmp/nginx$suffix.conf", "/etc/nginx/nginx.conf");
		
	# Modify ssl.conf and then copy to web server
	open( FILEIN,  "$configDir/nginx/ssl.conf" ) or die "Can't open file $configDir/nginx/ssl.conf: $!";
	open( FILEOUT, ">/tmp/ssl$suffix.conf" )            or die "Can't open file /tmp/ssl$suffix.conf: $!";

	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /rewrite rules go here/ ) {
			print FILEOUT $inline;
			if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
				print FILEOUT "if (\$query_string ~ \"size=(.*)\$\") {\n";
				print FILEOUT "set \$size \$1;\n";
				print FILEOUT "rewrite ^/auction/image/([^\.]*)\.(.*)\$ /imageStore/\$1_\$size.\$2;\n";
				print FILEOUT "}\n";
				print FILEOUT "location /imageStore{\n";
				print FILEOUT "root /mnt;\n";
				print FILEOUT "}\n";

			}
		}
		elsif ( $inline =~ /^\s*listen\s+443/ ) {
			print FILEOUT "    listen   " . $self->internalPortMap->{"https"} . " ssl backlog=16384 ;\n";
		}
		else {
			print FILEOUT $inline;
		}

	}

	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container 
	$self->host->dockerScpFileTo($applog, $name, "/tmp/ssl$suffix.conf", "/etc/nginx/conf.d/ssl.conf");
	
	open( FILEIN,  "$configDir/nginx/default.conf" ) or die "Can't open file $configDir/nginx/default.conf: $!";
	open( FILEOUT, ">/tmp/default$suffix.conf" )            or die "Can't open file /tmp/default$suffix.conf: $!";

	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /rewrite rules go here/ ) {
			print FILEOUT $inline;
			if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
				print FILEOUT "if (\$query_string ~ \"size=(.*)\$\") {\n";
				print FILEOUT "set \$size \$1;\n";
				print FILEOUT "rewrite ^/auction/image/([^\.]*)\.(.*)\$ /imageStore/\$1_\$size.\$2;\n";
				print FILEOUT "}\n";
				print FILEOUT "location /imageStore{\n";
				print FILEOUT "root /mnt;\n";
				print FILEOUT "}\n";

			}
		}
		elsif ( $inline =~ /^\s*listen\s+80/ ) {
			print FILEOUT "    listen   " . $self->internalPortMap->{"http"} . " backlog=16384 ;\n";
		}
		else {
			print FILEOUT $inline;
		}

	}

	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container 
	$self->host->dockerScpFileTo($applog, $name, "/tmp/default$suffix.conf", "/etc/nginx/conf.d/default.conf");

	close $applog;
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

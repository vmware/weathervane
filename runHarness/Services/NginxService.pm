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
package NginxService;

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

sub stopInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopNginx-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	my $logger = get_logger("Weathervane::Services::NginxService");
	$logger->debug("stop NginxService");

	my $nginxServerRoot = $self->getParamValue('nginxServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the app server is up
	print $applog "Checking whether nginx is already up on $hostname\n";
	if ($self->isRunning($applog) ) {

		# The server is running
		print $applog "Stopping nginx on $hostname\n";
		print $applog "$sshConnectString service nginx stop 2>&1\n";
		my $out = `$sshConnectString service nginx stop 2>&1`;
		print $applog "$out\n";

		if ( $self->isRunning($applog) ) {
			print $applog "Couldn't stop nginx on $hostname";
			die "Couldn't stop nginx on $hostname";
		}

	}

	close $applog;
}

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartNginx-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $nginxServerRoot = $self->getParamValue('nginxServerRoot');

	$self->portMap->{"http"} = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->registerPortsWithHost();

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the web server is up
	print $applog "Checking whether nginx is already up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting nginx on $hostname\n";
		print $applog "$sshConnectString service nginx start\n";
		my $out = `$sshConnectString service nginx start 2>&1`;
		print $applog "$out\n";
	}

	$self->host->startNscd();

	close $applog;
}

sub isUp {
	my ( $self ) = @_;
	my $hostname         = $self->host->hostName;
	my $port = $self->portMap->{"http"};
	my $logger = get_logger("Weathervane::Services:NginxService");
	
	$logger->debug("Checking whether nginx is up on $hostname port $port, self = $self");
	my $response = `curl -s -w "%{http_code}\n" -o /dev/null http://$hostname:$port`;
	$logger->debug("curl -s -w \"\%{http_code}\\n\" -o /dev/null http://$hostname:$port");
	$logger->debug("$response"); 
	
	if ($response =~ /200$/) {
		return 1;
	} else {
		return 0;
	}
}

sub isRunning {
	my ( $self, $fileout ) = @_;

	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString service nginx status 2>&1`;
	print $fileout $out;
	if ( ($out =~ /is running/ ) || ($out =~ /active\s+\(running/)) {
		return 1;
	}
	else {
		return 0;
	}
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
	$self->portMap->{"http"} = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $nginxServerRoot  = $self->getParamValue('nginxServerRoot');
	my $configDir        = $self->getParamValue('configDir');

	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getNumActiveOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}

	my $perServerConnections = floor( 50000.0 / $self->appInstance->getNumActiveOfServiceType('appServer') );

	# Modify nginx.conf and then copy to web server
	open( FILEIN,  "$configDir/nginx/nginx.conf" ) or die "Can't open file $configDir/nginx/nginx.conf: $!";
	open( FILEOUT, ">/tmp/nginx$suffix.conf" )            or die "Can't open file /tmp/nginx.conf: $!";

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
				my $appServerPort = $self->getPortNumberForUsedService($appServer,"http");
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

	`$scpConnectString /tmp/nginx$suffix.conf root\@$scpHostString:${nginxServerRoot}/nginx.conf 2>&1`;

	# Modify ssl.conf and then copy to web server
	open( FILEIN,  "$configDir/nginx/ssl.conf" ) or die "Can't open file $configDir/nginx/ssl.conf: $!";
	open( FILEOUT, ">/tmp/ssl$suffix.conf" )            or die "Can't open file /tmp/ssl.conf: $!";

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

	`$scpConnectString /tmp/ssl$suffix.conf root\@$scpHostString:${nginxServerRoot}/conf.d/ssl.conf 2>&1`;

	open( FILEIN,  "$configDir/nginx/default.conf" ) or die "Can't open file $configDir/nginx/default.conf: $!";
	open( FILEOUT, ">/tmp/default$suffix.conf" )            or die "Can't open file /tmp/default.conf: $!";

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

	`$scpConnectString /tmp/default$suffix.conf root\@$scpHostString:${nginxServerRoot}/conf.d/default.conf 2>&1`;

}

sub stopStatsCollection {
	my ($self) = @_;

	my $hostname = $self->host->hostName;
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-stopStats.html https://$hostname/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-stopStats.html > /tmp/nginx-$hostname-stopStats.txt 2>&1`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $hostname = $self->host->hostName;
	my $out      = `wget --no-check-certificate -O /tmp/nginx-$hostname-startStats.html https://$hostname/nginx-status 2>&1`;
	$out = `lynx -dump /tmp/nginx-$hostname-startStats.html > /tmp/nginx-$hostname-startStats.txt 2>&1`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

	my $out = `mv /tmp/nginx-$hostname-* $destinationPath/. 2>&1`;
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

	my $out = `rm -f /tmp/nginx-$hostname-* 2>&1`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	
	my $maxLogLines = $self->getParamValue('maxLogLines');
	$self->checkSizeAndTruncate("/var/log/nginx", "error.log", $maxLogLines);
	
	my $out              = `$scpConnectString root\@$scpHostString:/var/log/nginx/error.log $destinationPath/.  2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString \"rm /var/log/nginx/* 2>&1\"`;
	$out = `$sshConnectString \"rm -rf /var/cache/nginx/* 2>&1\"`;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $nginxServerRoot  = $self->getParamValue('nginxServerRoot');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:$nginxServerRoot/*.conf $destinationPath/.`;
	$out = `$scpConnectString root\@$scpHostString:$nginxServerRoot/conf.d/*.conf $destinationPath/.`;

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

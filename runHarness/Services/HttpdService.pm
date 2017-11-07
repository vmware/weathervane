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
package HttpdService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'Apache Httpd', );

has '+version' => ( default => '2.4.x', );

has '+description' => ( default => 'Apache Httpd Web Server', );

override 'initialize' => sub {
	my ( $self ) = @_;

	super();
};

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartHttpd-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $httpdServerRoot = $self->getParamValue( 'httpdServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	my $out;
	print $applog $self->meta->name . " In HttpdService::start\n";

	# Check whether the web server is up
	print $applog "Checking whether httpd is already up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting httpd on $hostname\n";
		print $applog "$sshConnectString apachctl -k start\n";
		$out = `$sshConnectString apachectl -k start 2>&1`;
		print $applog "$out\n";
	}

	# Stop htcacheclean
	print $applog "Stopping htcacheclean on $hostname\n";
	$out = `$sshConnectString killall htcacheclean 2>&1`;
	print $applog "$out\n";

	# Start htcacheclean
	print $applog "Starting htcacheclean on $hostname\n";
	$out = `$sshConnectString htcacheclean -d5 -l10G -n -t -p/var/cache/apache 2>&1`;
	print $applog "$out\n";

	$self->portMap->{"http"} = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;

}

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::HttpdService");
	$logger->debug("stop HttpdService");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopHttpd-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $httpdServerRoot = $self->getParamValue( 'httpdServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";
	my $out;

	print $applog $self->meta->name . " In HttpdService::stop\n";

	# Check whether the app server is up
	print $applog "Checking whether httpd is already up on $hostname\n";
	if ( $self->isRunning($applog) ) {

		# The server is running
		print $applog "Stopping httpd on $hostname\n";
		print $applog "$sshConnectString apachectl -k stop\n";
		$out = `$sshConnectString apachectl -k stop`;
		print $applog "$out\n";
		# kill any httpd processes that may still be running
		$out = `$sshConnectString killall httpd 2>&1`;
		print $applog "$out\n";
	
	}

	# Stop htcacheclean
	print $applog "Stopping htcacheclean on $hostname\n";
	$out = `$sshConnectString killall htcacheclean 2>&1`;
	print $applog "$out\n";
	close $applog;

}

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

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString ps x | grep \"httpd -k start\" | grep -v grep 2>&1`;
	print $fileout $out;
	if ( $out =~ /httpd/ ) {
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
	my $server           = $self->host->hostName;
	my $httpdServerRoot  = $self->getParamValue( 'httpdServerRoot');
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $sshConnectString = $self->host->sshConnectString;
	my $configDir        = $self->getParamValue( 'configDir');
	my $distDir          = $self->getParamValue( 'distDir');
		
	`$sshConnectString rm $httpdServerRoot/conf.d/* 2>&1`;

	my $maxClients = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getNumActiveOfServiceType('webServer') * 1.0 ) );
	if ( $maxClients < 100 ) {
		$maxClients = 100;
	}
	if ( $self->getParamValue('httpdMaxClients')) {
		$maxClients = $self->getParamValue('httpdMaxClients');
	}

	my $serverLimit = ceil( $maxClients / ( $self->getParamValue('httpdThreadsPerChild') * 1.0 ) );

	# Make sure that $serverLimit*$threadsPerChild is less than $maxClients
	my $threadsPerChild = floor( $maxClients / ( $serverLimit * 1.0 ) );

	# Get the httpd.conf from the config dir, modify it, and
	# then copy to the server
	open( FILEIN, "$configDir/httpd/httpd.conf" ) or die "Can't open file $configDir/httpd/httpd.conf: $!";
	open( FILEOUT, ">/tmp/httpd$suffix.conf" ) or die "Can't open file /tmp/httpd$suffix.conf : $!";

	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /EnableMMAP/ ) {
			if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
				print FILEOUT "EnableMMAP off\n";
			}
			else {
				print FILEOUT "EnableMMAP on\n";
			}
		}
		elsif ( $inline =~ /^Listen\s+80/ ) {
			print FILEOUT "Listen " . $self->internalPortMap->{"http"} . "\n";
		}
		elsif ( $inline =~ /^ServerName\s+.*:80/ ) {
			print FILEOUT "ServerName www.weathervane:" . $self->internalPortMap->{"http"} . "\n";
		}
		elsif ( $inline =~ /EnableSendfile/ ) {
			if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
				print FILEOUT "EnableSendfile off\n";
			}
			else {
				print FILEOUT "EnableSendfile on\n";
			}
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	`$scpConnectString /tmp/httpd$suffix.conf root\@$scpHostString:${httpdServerRoot}/conf/httpd.conf`;

	# Edit the ssl
	open( FILEIN, "$configDir/httpd/httpd-ssl.conf" ) or die "Can't open file $configDir/httpd/httpd-ssl.conf: $!";
	open( FILEOUT, ">/tmp/httpd-ssl$suffix.conf" ) or die "Can't open file /tmp/httpd-ssl$suffix.conf : $!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /^Listen\s+443/ ) {
			print FILEOUT "Listen " . $self->internalPortMap->{"https"} . "\n";
		}
		else {
			print FILEOUT $inline;
		}	
	}
	close FILEIN;
	close FILEOUT;
	`$scpConnectString /tmp/httpd-ssl$suffix.conf root\@$scpHostString:${httpdServerRoot}/conf.d/httpd-ssl.conf`;

	# Don't currently edit httpd-info.conf at all
	`$scpConnectString $configDir/httpd/httpd-info.conf root\@$scpHostString:${httpdServerRoot}/conf.d/httpd-info.conf`;

	# Edit the defaults
	open( FILEIN, "$configDir/httpd/httpd-default.conf" ) or die "Can't open file $configDir/httpd/httpd-default.conf: $!";
	open( FILEOUT, ">/tmp/httpd-default$suffix.conf" ) or die "Can't open file /tmp/httpd-default$suffix.conf : $!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /^\s*KeepAlive\s/ ) {
			if ($self->getParamValue('httpdKeepalive')) {
				print FILEOUT "KeepAlive On\n";			
			} else {
				print FILEOUT "KeepAlive Off\n";							
			}
		}
		elsif ( $inline =~ /^\s*KeepAliveTimeout\s/ ) {
			print FILEOUT "KeepAliveTimeout " . $self->getParamValue('httpdKeepaliveTimeout') . "\n";
		}
		elsif ( $inline =~ /^\s*MaxKeepAliveRequests\s/ ) {
			print FILEOUT "MaxKeepAliveRequests " . $self->getParamValue('httpdMaxKeepaliveRequests') . "\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	`$scpConnectString /tmp/httpd-default$suffix.conf root\@$scpHostString:${httpdServerRoot}/conf.d/httpd-default.conf`;

	# The MaxRequestWorkers must be an integer multiple of ThreadsPerChild
	# and less than threadsPerChild*ServerLimit
	my $maxRequestWorkers = $maxClients - ($maxClients % $threadsPerChild);
	while ($maxRequestWorkers > ($threadsPerChild * $serverLimit)) {
		$maxRequestWorkers -= $threadsPerChild;
	}

	# edit the event MPM settings
	open( FILEIN, "$configDir/httpd/httpd-mpm.conf" ) or die "Can't open file $configDir/httpd/httpd-mpm.conf: $!";
	open( FILEOUT, ">/tmp/httpd-mpm$suffix.conf" ) or die "Can't open file /tmp/httpd-mpm$suffix.conf : $!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /^\s*MaxRequestWorkers\s/ ) {
			print FILEOUT "MaxRequestWorkers\t" . $maxRequestWorkers . "\n";
		}
		elsif ( $inline =~ /^\s*ThreadsPerChild\s/ ) {
			print FILEOUT "ThreadsPerChild\t" . $threadsPerChild . "\n";
		}
		elsif ( $inline =~ /^\s*ThreadLimit\s/ ) {
			print FILEOUT "ThreadLimit\t" . $threadsPerChild . "\n";
		}
		elsif ( $inline =~ /^\s*ServerLimit\s/ ) {
			print FILEOUT "ServerLimit\t" . $serverLimit . "\n";
		}
		elsif ( $inline =~ /^\s*MinSpareThreads\s/ ) {
			print FILEOUT "MinSpareThreads\t" . $self->getParamValue('httpdMinSpareThreads') . "\n";
		}
		elsif ( $inline =~ /^\s*MaxSpareThreads\s/ ) {
			print FILEOUT "MaxSpareThreads\t" . $self->getParamValue('httpdMaxSpareThreads') . "\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	`$scpConnectString /tmp/httpd-mpm$suffix.conf root\@$scpHostString:${httpdServerRoot}/conf.d/httpd-mpm.conf`;

	# edit the vhost settings
	my $configFileName = "$configDir/httpd/httpd-vhosts-noSSL.conf";
	if ($self->getParamValue('ssl')) {
		$configFileName = "$configDir/httpd/httpd-vhosts.conf";
	}
	open( FILEIN, $configFileName ) or die "Can't open file $configFileName: $!";
	open( FILEOUT, ">/tmp/httpd-vhosts$suffix.conf" ) or die "Can't open file /tmp/httpd-vhosts$suffix.conf : $!";
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /<Proxy balancer:\/\// ) {
			print FILEOUT $inline;
			do {
				$inline = <FILEIN>;
			} while ( !( $inline =~ /<\/Proxy/ ) );

			# Add the balancer lines for each app server
			my $appServersRef  =  $self->appInstance->getActiveServicesByType('appServer');		
			my $cnt = 1;
			foreach my $appServer (@$appServersRef) {
				my $appHostname = $appServer->host->hostName;
				my $appPort = $appServer->portMap->{"http"};
				print FILEOUT "BalancerMember http://$appHostname:$appPort/auction route=$appHostname timeout=60 connectionTimeout=60 ttl=1800 retry=0 status=+I-E \n";
			}
			print FILEOUT "</Proxy>\n";
		}
		elsif ( $inline =~ /^\<VirtualHost\s+\*:80/ ) {
			print FILEOUT "<VirtualHost *:" . $self->internalPortMap->{"http"} . ">\n";
		}
		elsif ( $inline =~ /^\<VirtualHost\s+\*:443/ ) {
			print FILEOUT "<VirtualHost *:" . $self->internalPortMap->{"https"} . ">\n";
		}
		elsif ( $inline =~ /rewrite rules go here/ ) {
			print FILEOUT $inline;
			if ( $self->getParamValue('imageStoreType') eq "filesystem" ) {
				print FILEOUT "RewriteEngine on\n";
				print FILEOUT "RewriteCond %{QUERY_STRING} size=(.*)\$\n";
				print FILEOUT "RewriteRule ^/auction/image/([^\.]*)\.(.*)\$ /mnt/imageStore/\$1_%1.\$2\n";

				# Don't pass image urls to app server
				print FILEOUT "ProxyPass /auction/image !\n";
				print FILEOUT "ProxyPassReverse /auction/image !\n";
			}
		}
		else {
			print FILEOUT $inline;
		}
	}

	close FILEIN;
	close FILEOUT;

	`$scpConnectString /tmp/httpd-vhosts$suffix.conf root\@$scpHostString:${httpdServerRoot}/conf.d/httpd-vhosts.conf`;

	`$scpConnectString $configDir/httpd/00-mpm.conf root\@$scpHostString:${httpdServerRoot}/conf.modules.d/`;

}

sub stopStatsCollection {
	my ($self) = @_;

	my $hostname = $self->host->hostName;
	my $out      = `wget --no-check-certificate -O /tmp/httpd-$hostname-stopStats.html https://$hostname/server-status 2>&1`;
	$out = `lynx -dump /tmp/httpd-$hostname-stopStats.html > /tmp/httpd-$hostname-stopStats.txt`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $hostname = $self->host->hostName;
	my $out      = `wget --no-check-certificate -O /tmp/httpd-$hostname-startStats.html https://$hostname/server-status 2>&1`;
	$out = `lynx -dump /tmp/httpd-$hostname-startStats.html > /tmp/httpd-$hostname-startStats.txt`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

	my $out = `mv /tmp/httpd-$hostname-* $destinationPath/. 2>&1`;
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

	my $out = `rm -f /tmp/httpd-$hostname-* 2>&1`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $httpdServerRoot  = $self->getParamValue('httpdServerRoot');

	my $out = `$scpConnectString root\@$scpHostString:$httpdServerRoot/logs/* $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $httpdServerRoot  = $self->getParamValue('httpdServerRoot');
	my $out = `$sshConnectString \"rm -f $httpdServerRoot/logs/* 2>&1\"`;
	$out = `$sshConnectString \"rm -rf /var/cache/apache/* 2>&1\"`;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $httpdServerRoot  = $self->getParamValue('httpdServerRoot');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString -r root\@$scpHostString:$httpdServerRoot/conf $destinationPath/.`;
	$out = `$scpConnectString -r root\@$scpHostString:$httpdServerRoot/conf.d $destinationPath/.`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"httpdKeepaliveTimeout"}     = $self->getParamValue('httpdKeepaliveTimeout');
	$csv{"httpdMaxKeepaliveRequests"} = $self->getParamValue('httpdMaxKeepaliveRequests');
	$csv{"httpdThreadsPerChild"}      = $self->getParamValue('httpdThreadsPerChild');
	$csv{"httpdMinSpareThreads"}      = $self->getParamValue('httpdMinSpareThreads');
	$csv{"httpdMaxSpareThreads"}      = $self->getParamValue('httpdMaxSpareThreads');

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

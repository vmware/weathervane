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
package HaproxyService;

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

has '+description' => ( default => 'HAProxy reverse-proxy server', );


override 'initialize' => sub {
	my ( $self, $numLbServers ) = @_;

	super();
};

sub start {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $logName = "$logPath/StartHaproxy-$hostname.log";

	my $haproxyServerRoot = $self->getParamValue('haproxyServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog $self->meta->name . " In HaproxyService::start\n";

	# Check whether haproxy is up
	print $applog "Checking whether haproxy is already up on $hostname\n";
	if ( !$self->isRunning($applog)) {

		# The server is not running
		print $applog "Starting haproxy on $hostname\n";
		print $applog "$sshConnectString /usr/sbin/haproxy -f $haproxyServerRoot/haproxy.cfg -D -p /run/haproxy.pid  \n";
		my $out = `$sshConnectString /usr/sbin/haproxy -f $haproxyServerRoot/haproxy.cfg -D -p /run/haproxy.pid 2>&1`;
		print $applog "$out\n";
	}

	$self->portMap->{"http"} = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
}

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::HaproxyService");
	$logger->debug("stop HaproxyService");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopHaproxy-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $haproxyServerRoot = $self->getParamValue('haproxyServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog $self->meta->name . " In HaproxyService::start\n";

	# Check whether HAProxy is up
	print $applog "Checking whether haproxy is already up on $hostname\n";
	if ($self->isRunning($applog) ) {

		# The server is running
		my $out = `$sshConnectString ps aux | grep /usr/sbin/haproxy | grep -v grep  2>&1`;
 		print $applog "Stopping haproxy on $hostname\n";
		while ($out =~ /haproxy\s+(\d+)\s/g) {
			print $applog "$sshConnectString kill $1 2>&1\n";
			my $out = `$sshConnectString kill $1 2>&1`;
			print $applog "$out\n";
		}


	}

	close $applog;
}

sub isUp {
	my ( $self, $fileout ) = @_;
	
	return $self->isRunning($fileout);
	
}

sub isRunning {
	my ( $self, $fileout ) = @_;

	my $sshConnectString = $self->host->sshConnectString;

	print $fileout "$sshConnectString ps aux | grep /usr/sbin/haproxy | grep -v grep  2>&1";
	my $out = `$sshConnectString ps aux | grep /usr/sbin/haproxy | grep -v grep  2>&1`;
	print $fileout $out;
	if ($out =~ /haproxy/ ) {
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
	$self->internalPortMap->{"stats"} = 10080 + $portOffset;	
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	$self->portMap->{"http"} = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};

}

sub configure {
	my ($self, $logPath, $users, $suffix)            = @_;
	my $server            = $self->host->hostName;
	my $haproxyServerRoot = $self->getParamValue('haproxyServerRoot');
	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $configDir         = $self->getParamValue('configDir');

	my $terminateTLS = $self->getParamValue('haproxyTerminateTLS');
	
	# Get the haproxy.cfg from the haproxy instance, modify it, and
	# then copy back
	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	my $appServersRef  =  $self->appInstance->getActiveServicesByType('appServer');		

	my $numWebServers = $self->appInstance->getNumActiveOfServiceType('webServer');
	my $numAppServers = $self->appInstance->getNumActiveOfServiceType('appServer');
	my $numLbServers = $self->appInstance->getNumActiveOfServiceType('lbServer');

	my $maxConn = $self->getParamValue('frontendConnectionMultiplier') * floor($users / $numLbServers);
	if ($self->getParamValue('haproxyMaxConn')) {
		$maxConn = $self->getParamValue('haproxyMaxConn');
	}

	my $configFileName = "$configDir/haproxy/haproxy.cfg";
	if ($terminateTLS) {
		$configFileName = "$configDir/haproxy/haproxy.cfg.terminateTLS";
	}
	open( FILEIN, $configFileName ) or die "Can't open file $configFileName: $!";
	open( FILEOUT, ">/tmp/haproxy$suffix.cfg" ) or die "Can't open file /tmp/haproxy$suffix.cfg: $!";
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^\s*backend\s/ ) {
			print FILEOUT $inline;
			while ( $inline = <FILEIN> ) {

				if ( $inline =~ /^\s*server\s/ ) {

					# Parse the port number and any other keywords
					$inline =~ /\:(\d+)(\s.*)$/;
					my $endLine = $2;
					my $filePort = $1;

					# suck up all of the old server lines until the next
					# non-server line.
					while ( $inline = <FILEIN> ) {
						if ( !( $inline =~ /^\s*server\s/ ) ) {
							last;
						}
					}

					# Output server lines for each web server, then
					# add the line that was read after the server lines
					my $cnt = 1;

					# if there are no web servers, then balance across appServers
					# if only one app server, don't balance at all.
					if ( $numWebServers > 0 ) {
						my $serverMaxConn = $maxConn;
						
						foreach my $webServer (@$webServersRef) {
							my $serverHostname = $self->getHostnameForUsedService($webServer);
							my $port;
							if ($filePort == 80) {
								$port = $self->getPortNumberForUsedService($webServer, "http");							
							} else {
								$port = $self->getPortNumberForUsedService($webServer, "https");															
							}
							print FILEOUT "    server web" . $cnt . " "
							  . $serverHostname .":" . $port
							  . $endLine
							  . " maxconn $serverMaxConn "
							  . "\n";
							$cnt++;
						}
					}
					else {
						foreach my $appServer (@$appServersRef) {
							my $serverHostname = $self->getHostnameForUsedService($appServer);
							my $port;
							if ($filePort == 80) {
								$port = $self->getPortNumberForUsedService($appServer, "http");							
							} else {
								$port = $self->getPortNumberForUsedService($appServer, "https");															
							}
							print FILEOUT "    server app" . $cnt . " "
							  . $serverHostname .":" . $port
							  . $endLine
							  . " maxconn " . $self->getParamValue('haproxyAppServerMaxConn')
							  . "\n";
							$cnt++;
						}
					}

					if ( $inline && !( $inline =~ /^\s*server\s/ ) ) {
						print FILEOUT $inline;
					}
					last;
				}
				else {
					print FILEOUT $inline;
				}

			}
		}
		elsif ( $inline =~ /bind\s+\*\:10080/ ) {
			print FILEOUT "        bind *:" . $self->internalPortMap->{"stats"} . "\n";			
		}
		elsif ( $inline =~ /bind\s+\*\:80/ ) {
			print FILEOUT "        bind *:" . $self->internalPortMap->{"http"} . "\n";			
		}
		elsif ( $inline =~ /bind\s+\*\:443/ ) {
			my $tlsTerminationString = "";
			if ($terminateTLS) {
				$tlsTerminationString = " ssl crt /etc/pki/tls/private/weathervane.pem";
			}
			print FILEOUT "        bind *:" . $self->internalPortMap->{"https"} . "$tlsTerminationString\n";			
		}
		elsif ( $inline =~ /maxconn/ ) {
			print FILEOUT "    maxconn\t" . $maxConn . "\n";
		}
		elsif ( $inline =~ /nbproc/ ) {
			if ($self->getParamValue('haproxyProcPerCpu') || $terminateTLS) {
				print FILEOUT "    nbproc " . $self->host->cpus . "\n";
			}
		}
		elsif ( $inline =~ /^\s*listen.*ssh\s/ ) {

			# we are at the ssh forwarders section.
			# suck up everything through the end of the file and then
			# put the new forwarders in
			last;
		}
		else {
			print FILEOUT $inline;
		}
	}

	close FILEIN;
	close FILEOUT;

	`$scpConnectString /tmp/haproxy$suffix.cfg root\@$scpHostString:$haproxyServerRoot/haproxy.cfg`;
}

sub stopStatsCollection {
	my ($self) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $out = `$sshConnectString "echo \"show stat\" | socat /var/run/haproxy.sock stdio > /tmp/haproxy.stats"`;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString "echo \"clear counters all\" | socat /var/run/haproxy.sock stdio"`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;

	my $out = `$scpConnectString root\@$scpHostString:/tmp/haproxy.stats $destinationPath/haproxy.stats.csv 2>&1`;

}

sub cleanStatsFiles {
	my ($self) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString \"rm -f /tmp/haproxy.stats 2>&1\"`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;

	my $maxLogLines = $self->getParamValue('maxLogLines');
	$self->checkSizeAndTruncate("/var/log", "haproxy.log", $maxLogLines);
	my $out              = `$scpConnectString root\@$scpHostString:/var/log/haproxy.log $destinationPath/.  2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString \"rm -f /var/log/haproxy.log 2>&1\"`;

	# restart rsyslog so that can haproxy log again
	$out = `$sshConnectString service rsyslog restart 2>&1`;

}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $haproxyServerRoot = $self->getParamValue('haproxyServerRoot');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:$haproxyServerRoot/haproxy.cfg $destinationPath/.`;

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

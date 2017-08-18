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

	my $portMapRef = $self->host->dockerReload($applog, $name);
	
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};				
	} else {
		# For bridged networking, ports get assigned at start time
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
	my $portMapRef = $self->host->dockerPort($name);
	
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"} = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"stats"} = $self->internalPortMap->{"stats"};				
	} else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{"http"} = $portMapRef->{$self->internalPortMap->{"http"}};
		$self->portMap->{"https"} = $portMapRef->{$self->internalPortMap->{"https"}};
		$self->portMap->{"stats"} = $portMapRef->{$self->internalPortMap->{"stats"}};		
	}
	
}

sub configure {
	my ($self, $logPath, $users, $suffix)            = @_;
	my $configDir         = $self->getParamValue('configDir');

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/ConfigureHaproxyDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Get the haproxy.cfg from the haproxy instance, modify it, and
	# then copy back
	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	my $appServersRef  = $self->appInstance->getActiveServicesByType('appServer');

	my $numWebServers = $self->appInstance->getNumActiveOfServiceType('webServer');
	my $numAppServers = $self->appInstance->getNumActiveOfServiceType('appServer');

	my $maxConn = $self->getParamValue('frontendConnectionMultiplier') * $users;
	if ($self->getParamValue('haproxyMaxConn')) {
		$maxConn = $self->getParamValue('haproxyMaxConn');
	}

	my $configFileName = "$configDir/haproxy/haproxyDocker.cfg";
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
							my $port;
							if ($filePort == 80) {
								$port = $self->getPortNumberForUsedService($webServer, "http");							
							} else {
								$port = $self->getPortNumberForUsedService($webServer, "https");																	
							}
							print FILEOUT "    server web" . $cnt . " "
							  . $self->getHostnameForUsedService($webServer) .":" . $port
							  . $endLine
							  . " maxconn $serverMaxConn "
							  . "\n";
							$cnt++;
						}
					}
					elsif ( $numAppServers > 0 ) {
						foreach my $appServer (@$appServersRef) {
							my $port;
							if ($filePort == 80) {
								$port = $self->getPortNumberForUsedService($appServer, "http");							
							} else {
								$port = $self->getPortNumberForUsedService($appServer, "https");																	
							}
							print FILEOUT "    server app" . $cnt . " "
							  . $self->getHostnameForUsedService($appServer) .":" . $port
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
		elsif ( $inline =~ /maxconn/ ) {
			print FILEOUT "    maxconn\t" . $maxConn . "\n";
		}
		elsif ( $inline =~ /bind\s+\*\:10080/ ) {
			print FILEOUT "        bind *:" . $self->internalPortMap->{"stats"} . "\n";			
		}
		elsif ( $inline =~ /bind\s+\*\:80/ ) {
			print FILEOUT "        bind *:" . $self->internalPortMap->{"http"} . "\n";			
		}
		elsif ( $inline =~ /bind\s+\*\:443/ ) {
			print FILEOUT "        bind *:" . $self->internalPortMap->{"https"} . "\n";			
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

	# Push the config file to the docker container 
	$self->host->dockerScpFileTo($applog, $name, "/tmp/haproxy$suffix.cfg", "/etc/haproxy/haproxy.cfg");	

	close $applog;
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

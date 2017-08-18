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
package ConfigurationManagerDocker;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);
use WeathervaneTypes;
use JSON;

use LWP;
use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'ConfigurationManagerDocker', );

has '+version' => ( default => 'xx', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ( $self ) = @_;

	super();
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ConfigurationManagerDocker");
	
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StopConfigurationManagerDocker-$hostname-$name-$time.log";
	$logger->debug("stop ConfigurationManagerDocker");

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $applog, $name );

	close $applog;
	
}

override 'create' => sub {
	my ($self, $logPath)            = @_;
	
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	# The default create doesn't map any volumes
	my %volumeMap;
	
	# Set the environment variables for the Configuration manager
	my %envVarMap;
	my $jvmOpts = $self->getParamValue('configurationManagerJvmOpts');
	$envVarMap{"JVMOPTS"} = "\"$jvmOpts\"";
	$envVarMap{"WORKLOADNUM"} = $self->getParamValue('workloadNum');
	$envVarMap{"APPINSTANCENUM"} = $self->getParamValue('appInstanceNum');
	$envVarMap{"PORT"} = $self->internalPortMap->{$impl};
	
	# Create the container
	my %portMap;
	my $directMap = 0;
	if ($self->getParamValue( 'serviceType' ) eq $self->appInstance->getEdgeService()) {
		# This is an edge service.  Map the internal ports to the host ports
		$directMap = 1;
	}
	foreach my $key (keys %{$self->internalPortMap}) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	
	my $cmd = "";
	my $entryPoint = "";
	
	my $portMapRef = $self->host->dockerRun($applog, $self->getParamValue('dockerName'), $impl, $directMap, 
		\%portMap, \%volumeMap, \%envVarMap,$self->dockerConfigHashRef,	
		$entryPoint, $cmd, $self->needsTty);
		
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

		# For docker host networking, external ports are same as internal ports
		$self->	portMap->{$impl}   = $self->internalPortMap->{$impl};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{$impl}   = $portMapRef->{ $self->internalPortMap->{$impl} };
	}
	$self->registerPortsWithHost();
	
	close $applog;
};

sub start {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ConfigurationManager");
	my $workloadNum      = $self->getParamValue('workloadNum');
	my $appInstanceNum   = $self->getParamValue('appInstanceNum');
	my $hostname         = $self->host->hostName;
	my $logName =
"$logPath/StartConfigurationManagerDocker-$hostname-W${workloadNum}I${appInstanceNum}.log";
	open( my $applog, ">$logName" ) || die "Error opening /$logName:$!";

	# Don't need to reload as we configure properly on initial create

	# Wait for the configurationManager to be up and then
	# configure it with the information on the initial services
	my $maxSleep      = 600;
	my $curSleepTotal = 0;
	my $sleepTime     = 15;
	while ( !$self->isUp($applog) && ( $curSleepTotal <= $maxSleep ) ) {
		$logger->debug("Configuration Manager is not yet up.  Waiting.");
		sleep $sleepTime;
		$curSleepTotal += $sleepTime;
	}

	close $applog;

	if ( $curSleepTotal <= $maxSleep ) {
		$self->configureAfterIsUp();
	}
	
}


sub configureAfterIsUp {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::ConfigurationManager");
	my $console_logger = get_logger("Console");

	my $hostname = $self->getIpAddr();
	my $impl     = $self->getImpl();
	my $port     = $self->portMap->{$impl};

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");
	$ua->timeout(1200);

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $wkldImpl     = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$wkldImpl};

	# First set the defaults for the appInstance
	my %paramHash = %{ $self->appInstance->paramHashRef };
	my $content   = $json->encode( \%paramHash );
	my $url       = "http://$hostname:$port/appInstance/defaults";
	$logger->debug("Sending post to $url");
	$logger->debug("Content = $content");
	my $req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($content);

	my $res = $ua->request($req);
	$logger->debug( "Response status line: " . $res->status_line );

	# Check the outcome of the response
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: " . $res->content );
	}

	# Set the defaults for the services.  The defaults
	# come from the first service instance of each type for this appInstance
	my $configDir = $self->getParamValue('configDir');
	$logger->debug("Setting defaults for serviceTypes: @$serviceTypes");
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef =
		  $self->appInstance->getActiveServicesByType($serviceType);
		if ( $#{$servicesRef} >= 0 ) {
			my $service = $servicesRef->[0];
			%paramHash = %{ $service->paramHashRef };

			$paramHash{"dockerHostPort"} =
			  $self->host->getParamValue('dockerHostPort');
			$paramHash{"users"} = $self->getParamValue('users');
			if ( $serviceType eq "lbServer" ) {
				my $impl = $service->getImpl();
				if ( $impl eq "haproxy" ) {
					{
						local $/ = undef;
						open FILE, "$configDir/haproxy/haproxy.cfg.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						my $fileString = <FILE>;
						close FILE;
						$paramHash{"haproxyCfgFile"} = $fileString;

						open FILE, "$configDir/haproxy/haproxyDocker.cfg"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"haproxyDockerCfgFile"} = $fileString;

						open FILE, "$configDir/haproxy/haproxy.cfg.terminateTLS.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"haproxyTerminateTLSCfgFile"} = $fileString;

					}
				}
			}
			elsif ( $serviceType eq "webServer" ) {
				my $impl = $service->getImpl();
				if ( $impl eq "nginx" ) {
					{
						local $/ = undef;
						open FILE, "$configDir/nginx/nginx.conf.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						my $fileString = <FILE>;
						close FILE;
						$paramHash{"nginxConfFile"} = $fileString;

						open FILE, "$configDir/nginx/nginxDocker.conf"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"nginxDockerConfFile"} = $fileString;

						open FILE, "$configDir/nginx/default.conf.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"defaultConfFile"} = $fileString;

						open FILE, "$configDir/nginx/ssl.conf.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"sslConfFile"} = $fileString;
					}
				}
			}
			elsif ( $serviceType eq "appServer" ) {
				my $impl = $service->getImpl();
				if ( $impl eq "tomcat" ) {
					{
						local $/ = undef;
						open FILE, "$configDir/tomcat/setenv.sh.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						my $fileString = <FILE>;
						close FILE;
						$paramHash{"setenvShFile"} = $fileString;

						open FILE, "$configDir/tomcat/server.xml.template"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"serverXmlFile"} = $fileString;

						open FILE, "$configDir/tomcat/context.xml"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"contextXmlFile"} = $fileString;

						open FILE, "$configDir/tomcat/web.xml"
						  or die "Couldn't open file: $!";
						binmode FILE;
						$fileString = <FILE>;
						close FILE;
						$paramHash{"webXmlFile"} = $fileString;

					}
				}
			}

			$content = $json->encode( \%paramHash );
			$url     = "http://$hostname:$port/$serviceType/defaults";
			$logger->debug("Sending post to $url");
			$logger->debug("Content = $content");
			$req = HTTP::Request->new( POST => $url );
			$req->content_type('application/json');
			$req->header( Accept => "application/json" );
			$req->content($content);

			my $res = $ua->request($req);
			$logger->debug( "Response status line: " . $res->status_line );

			# Check the outcome of the response
			if ( $res->is_success ) {
				$logger->debug(
					"Response sucessful.  Content: " . $res->content );
			}
		}

	}

	# Add the appInstance to the configuration server
	%paramHash = %{ $self->appInstance->paramHashRef };
	$content   = $json->encode( \%paramHash );
	$url       = "http://$hostname:$port/appInstance/add";
	$logger->debug("Sending post to $url");
	$logger->debug("Content = $content");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($content);

	$res = $ua->request($req);
	$logger->debug( "Response status line: " . $res->status_line );

	# Check the outcome of the response
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: "
			  . $json->encode( $json->decode( $res->content ) ) );
	}

	# Add all of the initial services to the configuration server
	$logger->debug(
		"Adding initial instance info for serviceTypes: @$serviceTypes");
	my @appServerIds;
	$logger->debug(
		"Adding initial instance info for serviceTypes: @$serviceTypes");
	foreach my $serviceType (@$serviceTypes) {

		my $servicesRef =
		  $self->appInstance->getActiveServicesByType($serviceType);

		foreach my $service (@$servicesRef) {
			my %paramHash = %{ $service->paramHashRef };

			$paramHash{"class"} = $serviceType;

			foreach my $portName ( keys %{ $service->internalPortMap } ) {
				$paramHash{ $portName . "InternalPort" } =
				  $service->internalPortMap->{$portName};
			}
			foreach my $portName ( keys %{ $service->portMap } ) {
				$paramHash{ $portName . "Port" } =
				  $service->portMap->{$portName};
			}
			$paramHash{"hostHostName"}     = $service->host->hostName;
			$paramHash{"hostIpAddr"}       = $service->host->ipAddr;
			if ($service->host->getParamValue('vicHost')) {
				$paramHash{"hostCpus"}         = 2;				
				$paramHash{"hostMemKb"}        = 8192;
			} else {
				$paramHash{"hostCpus"}         = $service->host->cpus + 0;
				$paramHash{"hostMemKb"}        = $service->host->memKb + 0;
			}

			my $content = $json->encode( \%paramHash );
			my $url     = "http://$hostname:$port/$serviceType/add";
			$logger->debug("Sending post to $url");
			$logger->debug("Content = $content");
			my $req = HTTP::Request->new( POST => $url );
			$req->content_type('application/json');
			$req->header( Accept => "application/json" );
			$req->content($content);

			my $res = $ua->request($req);
			$logger->debug( "Response status line: " . $res->status_line );

			# Check the outcome of the response
			if ( $res->is_success ) {
				$logger->debug( "Response sucessful.  Content: "
					  . $json->encode( $json->decode( $res->content ) ) );

				my $contentHashRef = $json->decode( $res->content );

				# Save the url needed for removing the service
				if (
					(
						exists $contentHashRef->{"_links"}->{"remove"}->{"href"}
					)
					&& (
						defined $contentHashRef->{"_links"}->{"remove"}
						->{"href"} )
				  )
				{
					my $removeUrl =
					  $contentHashRef->{"_links"}->{"remove"}->{"href"};
					$logger->debug( "Adding remove url " . $removeUrl );
					$service->removeUrl($removeUrl);

			 # Save the id assigned to this service by the configuration manager
					$removeUrl =~ /\/(\d+)$/;
					my $id = $1;
					$service->id($id);
					$logger->debug( "Found $serviceType id " . $id );

				   # If this is an app server, save the id to a list to initiate
				   # prewarming is requested
					if ( $serviceType eq "appServer" ) {
						push @appServerIds, $id;
					}

				}

			}

		}
	}

	# Now warm the app servers if requested
	if ( $self->getParamValue('prewarmAppServers') ) {
		my $workloadNum    = $self->getParamValue('workloadNum');
		my $appInstanceNum = $self->getParamValue('appInstanceNum');
		my $content        = $json->encode( \@appServerIds );
		my $url            = "http://$hostname:$port/appServer/warm";
		$logger->debug("Sending PUT to $url");
		$logger->debug("Content = $content");
		my $req = HTTP::Request->new( PUT => $url );
		$req->content_type('application/json');
		$req->header( Accept => "application/json" );
		$req->content($content);

		my $res = $ua->request($req);
		$logger->debug( "Response status line: " . $res->status_line );
		if ( $res->is_success ) {
			$logger->debug( "Response sucessful.  Content: "
				  . $json->encode( $json->decode( $res->content ) ) );
		}
		else {
			$console_logger->warn(
"Could not prewarm application servers for workload $workloadNum, appInstance $appInstanceNum.  Proceeding without the pre-warm step."
			);
		}
	}

}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ConfigurationManagerDocker");
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	$logger->debug("remove. logPath = $logPath, hostname = $hostname, dockerName = $name");
	my $logName  = "$logPath/RemoveConfigurationManagerDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove( $applog, $name );

	close $applog;
};

sub isUp {
	my ( $self, $fileout ) = @_;
	my $logger = get_logger("Weathervane::Services::ConfigurationManager");

	my $hostname = $self->getIpAddr();
	my $port     = $self->portMap->{$self->getImpl()};

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");

	my $url = "http://$hostname:$port/healthCheck";
	$logger->debug("Sending get to $url");
	my $req = HTTP::Request->new( GET => $url );

	my $res = $ua->request($req);
	$logger->debug( "Response status line: " . $res->status_line );
	if ( $res->is_success ) {
		return 1;
	}

	return 0;

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->getParamValue('dockerName');

	return $self->host->dockerIsRunning( $fileout, $name );
}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getImpl();
	my $portMultiplier =
	  $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset =
	  $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	$self->internalPortMap->{$impl} =
	  $self->getParamValue('configurationManagerPort') + $portOffset;	  

}

sub setExternalPortNumbers {
	my ($self) = @_;
	$self->portMap->{$self->getImpl()} = $self->internalPortMap->{$self->getImpl()};

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;

}

sub stopStatsCollection {
	my ( $self, $host, $configPath ) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	
	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/ConfigurationManagerDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $logContents = $self->host->dockerGetLogs( $applog, $name );

	print $applog $logContents;

	close $applog;


}

sub cleanLogFiles {
	my ($self)           = @_;
	
}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	
}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

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

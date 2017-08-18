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
package TomcatDockerService;

use Moose;
use MooseX::Storage;

use POSIX;
use Services::Service;
use Parameters qw(getParamValue);
use StatsParsers::ParseGC qw( parseGCLog );
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'Tomcat', );

has '+version' => ( default => '8', );

has '+description' => ( default => 'The Apache Tomcat Servlet Container', );

has 'mongosDocker' => (
	is      => 'rw',
	isa     => 'Str',
	default => "",
);

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub setMongosDocker {
	my ( $self, $mongosDockerName ) = @_;
	$self->mongosDocker($mongosDockerName);
}

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatDockerService");
	$logger->debug("stop TomcatDockerService");

	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $logName  = "$logPath/StopTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $applog, $name );

	close $applog;
}

sub start {
	my ( $self, $logPath ) = @_;
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $logName  = "$logPath/StartTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my $portMapRef = $self->host->dockerReload( $applog, $name );

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"}  = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"shutdown"} = $self->internalPortMap->{"shutdown"};
	}
	else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{"http"}  = $portMapRef->{ $self->internalPortMap->{"http"} };
		$self->portMap->{"https"} = $portMapRef->{ $self->internalPortMap->{"https"} };
		$self->portMap->{"shutdown"} = $portMapRef->{ $self->internalPortMap->{"shutdown"} };
	}

	$self->registerPortsWithHost();
	$self->host->startNscd();

	close $applog;
}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatDockerService");
	$logger->debug("logPath = $logPath");
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	my $logName  = "$logPath/RemoveTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove( $applog, $name );

	close $applog;
};

override 'create' => sub {
	my ( $self, $logPath ) = @_;

	if ( !$self->getParamValue('useDocker') ) {
		return;
	}

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $impl     = $self->getImpl();

	my $logName = "$logPath/Create${impl}Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# The default create doesn't map any volumes
	my %volumeMap;

	# The default create doesn't create any environment variables
	my %envVarMap;

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

sub isUp {
	my ( $self, $applog ) = @_;
	my $hostname = $self->getIpAddr();
	my $port     = $self->portMap->{"http"};

	my $response = `curl -s http://$hostname:$port/auction/healthCheck`;
	print $applog "curl -s http://$hostname:$port/auction/healthCheck\n";
	print $applog "$response\n";

	if ( $response =~ /alive/ ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->getParamValue('dockerName');

	return $self->host->dockerIsRunning( $fileout, $name );

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
	$self->internalPortMap->{"shutdown"} = 8005 + ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
}

sub setExternalPortNumbers {
	my ($self)     = @_;
	my $name       = $self->getParamValue('dockerName');
	
	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"http"}  = $self->internalPortMap->{"http"};
		$self->portMap->{"https"} = $self->internalPortMap->{"https"};
		$self->portMap->{"shutdown"} = $self->internalPortMap->{"shutdown"};
	}
	else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{"http"}  = $portMapRef->{ $self->internalPortMap->{"http"} };
		$self->portMap->{"https"} = $portMapRef->{ $self->internalPortMap->{"https"} };
		$self->portMap->{"shutdown"} = $portMapRef->{ $self->internalPortMap->{"shutdown"} };
	}

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');
	my $name             = $self->getParamValue('dockerName');
	my $nodeNum = $self->getParamValue('instanceNum');

	my $logName = "$logPath/ConfigureTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $numCpus            = $self->host->cpus;
	if ($self->getParamValue('dockerCpus')) {
		$numCpus = $self->getParamValue('dockerCpus');
	}
	my $threads            = $self->getParamValue('appServerThreads') * $numCpus;
	my $connections        = $self->getParamValue('appServerJdbcConnections') * $numCpus;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	my $maxConnections =
	  ceil( $self->getParamValue('frontendConnectionMultiplier') *
		  $users /
		  ( $self->appInstance->getNumActiveOfServiceType('appServer') * 1.0 ) );
	if ( $maxConnections < 100 ) {
		$maxConnections = 100;
	}

	my $completeJVMOpts .= $self->getParamValue('appServerJvmOpts');
	$completeJVMOpts .= " " . $serviceParamsHashRef->{"jvmOpts"};
	if ( $self->getParamValue('appServerEnableJprofiler') ) {
		$completeJVMOpts .=
		  " -agentpath:/opt/jprofiler8/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m";
	}

	if ( $self->getParamValue('logLevel') >= 3 ) {
		$completeJVMOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:$tomcatCatalinaBase/logs/gc.log ";
	}
	$completeJVMOpts .= " -DnodeNumber=$nodeNum ";

	# Modify setenv.sh and then copy to app server
	open( FILEIN,  "$configDir/tomcat/setenv.sh" ) or die "Can't open file $configDir/tomcat/setenv.sh: $!\n";
	open( FILEOUT, ">/tmp/setenv${suffix}-N${nodeNum}.sh" )      or die "Can't open file /tmp/setenv${suffix}-N${nodeNum}.sh: $!\n";

	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^CATALINA_OPTS="(.*)"/ ) {
			print FILEOUT "CATALINA_OPTS=\"$completeJVMOpts\"\n";
		}
		else {
			print FILEOUT $inline;
		}

	}

	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container
	$self->host->dockerScpFileTo( $applog, $name, "/tmp/setenv${suffix}-N${nodeNum}.sh", "${tomcatCatalinaBase}/bin/setenv.sh" );

	# Configure the database info
	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $self->getHostnameForUsedService($dbService);
	my $db            = $dbService->getImpl();
	my $dbPort        = $self->getPortNumberForUsedService( $dbService, $db );

	my $driverClassName;
	if ( $db eq "mysql" ) {
		$driverClassName = "com.mysql.jdbc.Driver";
	}
	elsif ( $db eq "postgresql" ) {
		$driverClassName = "org.postgresql.Driver";
	}

	my $dbUrl;
	if ( $db eq "mysql" ) {
		$dbUrl = "jdbc:mysql://" . $dbHostname . ":" . $dbPort . "/auction";
	}
	elsif ( $db eq "postgresql" ) {
		$dbUrl = "jdbc:postgresql://" . $dbHostname . ":" . $dbPort . "/auction";
	}

	open( FILEIN,  "$configDir/tomcat/server.xml" );
	open( FILEOUT, ">/tmp/server$suffix-N${nodeNum}.xml" );
	my $maxIdle = ceil($self->getParamValue('appServerJdbcConnections') / 2);
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /<Server port="8005" shutdown="SHUTDOWN">/ ) {
			print FILEOUT "<Server port=\"" .  $self->internalPortMap->{"shutdown"} . "\" shutdown=\"SHUTDOWN\">\n";
		} 
		elsif ( $inline =~ /<Resource/ ) {
			print FILEOUT $inline;

			do {
				$inline = <FILEIN>;
				if ( $inline =~ /(.*)maxActive="\d+"(.*)/ ) {
					$inline = "${1}maxActive=\"$connections\"$2\n";
				}

				if ( $inline =~ /(.*)maxIdle="\d+"(.*)/ ) {
					$inline = "${1}maxIdle=\"$maxIdle\"$2\n";
				}
				if ( $inline =~ /(.*)initialSize="\d+"(.*)/ ) {
					$inline = "${1}initialSize=\"$maxIdle\"$2\n";
				}
				if ( $inline =~ /(.*)url=".*"(.*)/ ) {
					$inline = "${1}url=\"$dbUrl\"$2\n";
				}
				if ( $inline =~ /(.*)driverClassName=".*"(.*)/ ) {
					$inline = "${1}driverClassName=\"$driverClassName\"$2\n";
				}

				print FILEOUT $inline;
			} while ( !( $inline =~ /\/>/ ) );
		}
		elsif ( $inline =~ /<Connector/ ) {
			print FILEOUT $inline;

			# suck up the rest of the existing connector definition
			do {
				$inline = <FILEIN>;
			} while ( !( $inline =~ /\/>/ ) );
			print FILEOUT "acceptCount=\"100\"\n";
			print FILEOUT "acceptorThreadCount=\"2\"\n";
			print FILEOUT "connectionTimeout=\"60000\"\n";
			print FILEOUT "asyncTimeout=\"60000\"\n";
			print FILEOUT "disableUploadTimeout=\"false\"\n";
			print FILEOUT "connectionUploadTimeout=\"240000\"\n";
			print FILEOUT "socketBuffer=\"65536\"\n";
			print FILEOUT "executor=\"tomcatThreadPool\"\n";
			print FILEOUT "maxKeepAliveRequests=\"-1\"\n";
			print FILEOUT "keepAliveTimeout=\"-1\"\n";
			print FILEOUT "maxConnections=\"$maxConnections\"\n";
			print FILEOUT "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n";

			if ( $self->getParamValue('ssl') && ( $self->appInstance->getNumActiveOfServiceType('webServer') == 0 ) ) {

				# If using ssl, reconfigure the connector
				# to handle ssl on https port
				# output an ssl connector and a redirect connector
				print FILEOUT "port=\"" . $self->internalPortMap->{"https"} . "\"\n";
				print FILEOUT "scheme=\"https\" secure=\"true\" SSLEnabled=\"true\"\n";
				print FILEOUT "keystoreFile=\"/etc/pki/tls/weathervane.jks\" keystorePass=\"weathervane\"\n";
				print FILEOUT "clientAuth=\"false\" sslProtocol=\"TLS\"/>\n";

				# Connector for http traffic
				print FILEOUT "<Connector port=\"" . $self->internalPortMap->{"http"} . "\"\n";
				print FILEOUT "enableLookups=\"false\" \n";
				print FILEOUT "redirectPort=\"" . $self->internalPortMap->{"https"} . "\"/>\n";
				print FILEOUT "acceptCount=\"100\"\n";
				print FILEOUT "acceptorThreadCount=\"2\"\n";
				print FILEOUT "socketBuffer=\"65536\"\n";
				print FILEOUT "connectionTimeout=\"60000\"\n";
				print FILEOUT "disableUploadTimeout=\"false\"\n";
				print FILEOUT "connectionUploadTimeout=\"240000\"\n";
				print FILEOUT "asyncTimeout=\"60000\"\n";
				print FILEOUT "executor=\"tomcatThreadPool\"\n";
				print FILEOUT "maxKeepAliveRequests=\"-1\"\n";
				print FILEOUT "keepAliveTimeout=\"-1\"\n";
				print FILEOUT "maxConnections=\"$maxConnections\"\n";
				print FILEOUT "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n";
				print FILEOUT "/>\n";
			}
			else {
				print FILEOUT "port=\"" . $self->internalPortMap->{"http"} . "\"\n";
				print FILEOUT "redirectPort=\"" . $self->internalPortMap->{"https"} . "\"/>\n";
			}
		}
		elsif ( $inline =~ /<Executor\s+maxThreads="\d+"(.*)/ ) {
			print FILEOUT "<Executor maxThreads=\"$threads\"${1}\n";
			do {

				$inline = <FILEIN>;

				if ( $inline =~ /(.*)minSpareThreads="\d+"(.*)/ ) {
					my $minThreads = ceil( $threads / 3 );
					$inline = "${1}minSpareThreads=\"$minThreads\"$2\n";
				}

				print FILEOUT $inline;
			} while ( !( $inline =~ /\/>/ ) );
		}
		elsif ( $inline =~ /<Engine.*jvmRoute/ ) {
			print FILEOUT "    <Engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"$hostname\">\n";
		}
		else {
			print FILEOUT $inline;
		}

	}

	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container
	$self->host->dockerScpFileTo( $applog, $name, "/tmp/server$suffix-N${nodeNum}.xml", "${tomcatCatalinaBase}/conf/server.xml" );

	# if the number of web servers is 0, and we are using ssl,
	# we need to add a security
	# constraint to Tomcat's web.xml so all traffic is redirected to ssl
	open( FILEIN,  "$configDir/tomcat/web.xml" );
	open( FILEOUT, ">/tmp/web$suffix-N${nodeNum}.xml" );
	while ( my $inline = <FILEIN> ) {
		if (   ( $inline =~ /<\/web-app>/ )
			&& ( $self->appInstance->getNumActiveOfServiceType('webServer') == 0 )
			&& ( $self->getParamValue('ssl') ) )
		{
			print FILEOUT "<security-constraint>\n";
			print FILEOUT "<web-resource-collection>\n";
			print FILEOUT "<web-resource-name>Entire Application</web-resource-name>\n";
			print FILEOUT "<url-pattern> /*</url-pattern>\n";
			print FILEOUT "</web-resource-collection>\n";
			print FILEOUT "<user-data-constraint>\n";
			print FILEOUT "<transport-guarantee>CONFIDENTIAL</transport-guarantee>\n";
			print FILEOUT "</user-data-constraint>\n";
			print FILEOUT "</security-constraint>\n";

			print FILEOUT $inline;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;

	# Push the config file to the docker container
	$self->host->dockerScpFileTo( $applog, $name, "/tmp/web$suffix-N${nodeNum}.xml", "${tomcatCatalinaBase}/conf/web.xml" );

	# Push the config file to the docker container
	$self->host->dockerScpFileTo(
		$applog, $name,
		"$configDir/tomcat/context.xml",
		"${tomcatCatalinaBase}/conf/context.xml"
	);

	close $applog;

}

sub stopStatsCollection {
	my ($self)   = @_;
	my $port     = $self->portMap->{"http"};
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');

	if ( $self->getParamValue('appServerPerformanceMonitor') ) {
`curl -s -o /tmp/$hostname-$name-performanceMonitor.csv http://$hostname:$port/auction/javasimon/data/table.csv?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
`curl -s -o /tmp/$hostname-$name-performanceMonitor.json http://$hostname:$port/auction/javasimon/data/table.json?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
	}

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $setupLogDir        = $self->getParamValue('tmpDir') . "/setupLogs";
	my $name               = $self->getParamValue('dockerName');
	my $hostname           = $self->host->hostName;

	my $logName = "$setupLogDir/StartStatsCollectionTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerExec( $applog, $name,
		"cp $tomcatCatalinaBase/logs/gc.log $tomcatCatalinaBase/logs/gc_rampup.log" );

	close $applog;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $name               = $self->getParamValue('dockerName');
	my $hostname           = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/GetStatsFilesTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	`mv /tmp/$hostname-$name-performanceMonitor.csv $logpath/. 2>&1`;
	`mv /tmp/$hostname-$name-performanceMonitor.json $logpath/. 2>&1`;

	$self->host->dockerScpFileFrom( $applog, $name, "$tomcatCatalinaBase/logs/gc*.log", "$logpath/." );

	close $applog;

}

sub cleanStatsFiles {
	my ( $self, $destinationPath ) = @_;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatDockerService");
	$logger->debug("getLogFiles");

	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $name               = $self->getParamValue('dockerName');
	my $hostname           = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/TomcatDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog $self->host->dockerGetLogs( $applog, $name );

	close $applog;

}

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatDockerService");
	$logger->debug("cleanLogFiles");
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $name               = $self->getParamValue('dockerName');
	my $hostname           = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/GetConfigFilesTomcatDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerScpFileFrom( $applog, $name, "$tomcatCatalinaBase/conf/*",        "$logpath/." );
	$self->host->dockerScpFileFrom( $applog, $name, "$tomcatCatalinaBase/bin/setenv.sh", "$logpath/." );
	close $applog;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"tomcatThreads"}     = $self->getParamValue('appServerThreads');
	$csv{"tomcatConnections"} = $self->getParamValue('appServerJdbcConnections');
	$csv{"tomcatJvmOpts"}     = $self->getParamValue('appServerJvmOpts');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $gcviewerDir     = $self->getParamValue('gcviewerDir');
	if ( !( $gcviewerDir =~ /^\// ) ) {
		$gcviewerDir = $weathervaneHome . "/" . $gcviewerDir;
	}

	# Only parseGc if gcviewer is present
	if ( -f "$gcviewerDir/gcviewer-1.34-SNAPSHOT.jar" ) {

		open( HOSTCSVFILE, ">>$statsLogPath/tomcat_gc_summary.csv" )
		  or die "Can't open $statsLogPath/tomcat_gc_summary.csv : $! \n";
		my $addedHeaders = 0;

		tie( my %accumulatedCsv, 'Tie::IxHash' );
		my $serviceType = $self->getParamValue('serviceType');
		my $servicesRef = $self->appInstance->getActiveServicesByType($serviceType);
		my $numServices = $#{$servicesRef} + 1;
		my $csvHashRef;
		foreach my $service (@$servicesRef) {
			my $name    = $service->getParamValue('dockerName');
			my $logPath = $statsLogPath . "/" . $service->host->hostName . "/$name";
			$csvHashRef = ParseGC::parseGCLog( $logPath, "", $gcviewerDir );

			if ( !$addedHeaders ) {
				print HOSTCSVFILE "Hostname,IP Addr";
				foreach my $key ( keys %$csvHashRef ) {
					print HOSTCSVFILE ",$key";
				}
				print HOSTCSVFILE "\n";

				$addedHeaders = 1;
			}

			print HOSTCSVFILE $service->host->hostName . "," . $service->host->ipAddr;
			foreach my $key ( keys %$csvHashRef ) {
				print HOSTCSVFILE "," . $csvHashRef->{$key};
				if ( $csvHashRef->{$key} eq "na" ) {
					next;
				}
				if ( !( exists $accumulatedCsv{"tomcat_$key"} ) ) {
					$accumulatedCsv{"tomcat_$key"} = $csvHashRef->{$key};
				}
				else {
					$accumulatedCsv{"tomcat_$key"} += $csvHashRef->{$key};
				}
			}
			print HOSTCSVFILE "\n";

		}

		# Now turn the total into averages
		foreach my $key ( keys %$csvHashRef ) {
			if ( exists $accumulatedCsv{"tomcat_$key"} ) {
				$accumulatedCsv{"tomcat_$key"} /= $numServices;
			}
		}

		# Now add the key/value pairs to the returned csv
		@csv{ keys %accumulatedCsv } = values %accumulatedCsv;

		close HOSTCSVFILE;
	}
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

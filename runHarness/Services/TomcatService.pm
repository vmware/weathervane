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
package TomcatService;

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
	my ( $self, $numAppServers ) = @_;

	super();
};

sub setMongosDocker {
	my ( $self, $mongosDockerName ) = @_;
	$self->mongosDocker($mongosDockerName);
}

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatService");
	$logger->debug("stop TomcatService");
	
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $tomcatCatalinaHome = $self->getParamValue('tomcatCatalinaHome');
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	my $logName = "$logPath/StopTomcat-$hostname.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the app server is up
	print $applog "Checking whether Tomcat is already up on $hostname\n";
	if ( $self->isRunning($applog) ) {

		# Send a prepare to stop message to the app server
		my $hostname = $self->host->hostName;
		my $port     = $self->portMap->{"http"};
		if (!(defined $port)) {
			$port  = $self->internalPortMap->{"http"};
		}
		$logger->debug("Sending prepareForShutdown: curl -s http://$hostname:$port/auction/live/auction/prepareForShutdown");
		print $applog "curl -s http://$hostname:$port/auction/live/auction/prepareForShutdown\n";
		my $response = `curl -s http://$hostname:$port/auction/live/auction/prepareForShutdown`;
		$logger->debug("Response: $response");
		print $applog "$response\n";		

		sleep 15;

		# The server is running
		print $applog "Stopping Tomcat on $hostname\n";
		print $applog
		  "$sshConnectString CATALINA_BASE=\"$tomcatCatalinaBase\" ${tomcatCatalinaHome}/bin/shutdown.sh -force 2>&1 \n";
		my $out =
		  `$sshConnectString CATALINA_BASE=\"$tomcatCatalinaBase\" ${tomcatCatalinaHome}/bin/shutdown.sh -force 2>&1`;
		print $applog "$out\n";

		$out = `$sshConnectString jps`;
		print $applog "$out\n";
		if ( $out =~ /Bootstrap/ ) {
			print $applog "Couldn't stop Tomcat on $hostname: $out";
			die "Couldn't stop Tomcat on $hostname: $out";
		}

	}

	close $applog;

}

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartTomcat-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $tomcatCatalinaHome = $self->getParamValue('tomcatCatalinaHome');
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	$self->portMap->{"http"}  = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->portMap->{"shutdown"} = $self->internalPortMap->{"shutdown"};

	$self->registerPortsWithHost();
	
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the app server is up
	print $applog "Checking whether Tomcat is already up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting Tomcat on $hostname\n";
		print $applog "$sshConnectString CATALINA_BASE=\"$tomcatCatalinaBase\" ${tomcatCatalinaHome}/bin/startup.sh\n";
		my $out = `$sshConnectString CATALINA_BASE=\"$tomcatCatalinaBase\" ${tomcatCatalinaHome}/bin/startup.sh`;
		print $applog "$out\n";
	}

	$self->host->startNscd();

	close $applog;

}

sub isUp {
	my ( $self, $applog ) = @_;
	my $hostname = $self->host->hostName;
	my $port     = $self->portMap->{"http"};
	if (!(defined $port)) {
		$port  = $self->internalPortMap->{"http"};
	}

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

	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString jps`;
	print $fileout "$out\n";
	if ( $out =~ /Bootstrap/ ) {
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
	$self->internalPortMap->{"shutdown"} = 8005 + ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	$self->portMap->{"http"}  = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->portMap->{"shutdown"} = $self->internalPortMap->{"shutdown"};
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');
	my $nodeNum = $self->getParamValue('instanceNum');

	my $serviceType    = $self->getParamValue('serviceType');
	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $serviceType );

	my $numCpus = $self->host->cpus;
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
	open( FILEOUT, ">/tmp/setenv${suffix}-N${nodeNum}.sh" )             or die "Can't open file /tmp/setenv$suffix-N${nodeNum}.sh: $!\n";

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

	`$scpConnectString /tmp/setenv${suffix}-N${nodeNum}.sh root\@$scpHostString:${tomcatCatalinaBase}/bin/setenv.sh`;

	# Configure the database info
	my $dbServicesRef = $self->appInstance->getActiveServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $dbService->host->hostName;
	my $db            = $dbService->getImpl();
	my $dbPort        = $dbService->portMap->{$db};

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
	open( FILEOUT, ">/tmp/server${suffix}-N${nodeNum}.xml" );
	my $maxIdle = ceil( $self->getParamValue('appServerJdbcConnections') / 2 );
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
				print FILEOUT "redirectPort=\"" . $self->internalPortMap->{"https"} . "\"\n";
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
	`$scpConnectString /tmp/server${suffix}-N${nodeNum}.xml root\@$scpHostString:$tomcatCatalinaBase/conf/server.xml`;

	# if the number of web servers is 0, and we are using ssl,
	# we need to add a security
	# constraint to Tomcat's web.xml so all traffic is redirected to ssl
	open( FILEIN,  "$configDir/tomcat/web.xml" );
	open( FILEOUT, ">/tmp/web${suffix}-N${nodeNum}.xml" );
	while ( my $inline = <FILEIN> ) {
		if (0) {

#		if ( ( $inline =~ /<\/web-app>/ ) && ( $self->appInstance->getNumActiveOfServiceType('webServer') == 0 ) && ( $self->getParamValue('ssl') ) ) {
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
	`$scpConnectString /tmp/web${suffix}-N${nodeNum}.xml root\@$scpHostString:$tomcatCatalinaBase/conf/web.xml`;

	`$scpConnectString $configDir/tomcat/context.xml root\@$scpHostString:$tomcatCatalinaBase/conf/context.xml`;

}

sub stopStatsCollection {
	my ($self)   = @_;
	my $port     = $self->portMap->{"http"};
	my $hostname = $self->host->hostName;

	if ( $self->getParamValue('appServerPerformanceMonitor') ) {
`curl -s -o /tmp/$hostname-performanceMonitor.csv http://$hostname:$port/auction/javasimon/data/table.csv?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
`curl -s -o /tmp/$hostname-performanceMonitor.json http://$hostname:$port/auction/javasimon/data/table.json?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
	}
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $sshConnectString   = $self->host->sshConnectString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	`$sshConnectString \"cp $tomcatCatalinaBase/logs/gc.log $tomcatCatalinaBase/logs/gc_rampup.log\"`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $hostname           = $self->host->hostName;

	`mv /tmp/$hostname-performanceMonitor.csv $destinationPath/. 2>&1`;
	`mv /tmp/$hostname-performanceMonitor.json $destinationPath/. 2>&1`;

	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/logs/gc*.log $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	`$sshConnectString \"rm $tomcatCatalinaBase/logs/gc*.log 2>&1\"`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	my $maxLogLines = $self->getParamValue('maxLogLines');
	my $date = `$sshConnectString date +%Y-%m-%d`;
	chomp($date);
	
	$self->checkSizeAndTruncate("$tomcatCatalinaBase/logs", "auction.log", $maxLogLines);
	$self->checkSizeAndTruncate("$tomcatCatalinaBase/logs", "catalina.out", $maxLogLines);
	$self->checkSizeAndTruncate("$tomcatCatalinaBase/logs", "catalina.$date.log", $maxLogLines);	
	$self->checkSizeAndTruncate("$tomcatCatalinaBase/logs", "localhost.$date.log", $maxLogLines);	

	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/logs/auction.log $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/logs/catalina.out $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/logs/catalina.$date.log $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/logs/localhost.$date.log $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');

	`$sshConnectString \"rm -f $tomcatCatalinaBase/logs/*  2>&1\"`;
	`$sshConnectString \"rm -rf $tomcatCatalinaBase/work/*  2>&1\"`;
	`$sshConnectString \"rm -rf /tmp/copycat*  2>&1\"`;
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	`mkdir -p $destinationPath`;
	`$scpConnectString -r root\@$scpHostString:$tomcatCatalinaBase/conf/* $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$tomcatCatalinaBase/bin/setenv.sh $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"tomcatThreads"}     = $self->getParamValue('appServerThreads');
	$csv{"tomcatConnections"} = $self->getParamValue('appServerJdbcConnections');
	$csv{"tomcatJvmOpts"}     = $self->getParamValue('appServerJvmOpts');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	open( HOSTCSVFILE, ">>$statsLogPath/tomcat_gc_summary.csv" )
	  or die "Can't open $statsLogPath/tomcat_gc_summary.csv : $! \n";
	my $addedHeaders = 0;

	my $weathervaneHome  = $self->getParamValue('weathervaneHome');
	my $gcviewerDir = $self->getParamValue('gcviewerDir');
	if ( !( $gcviewerDir =~ /^\// ) ) {
		$gcviewerDir = $weathervaneHome . "/" . $gcviewerDir;
	}

	tie( my %accumulatedCsv, 'Tie::IxHash' );
	my $serviceType = $self->getParamValue('serviceType');
	my $servicesRef = $self->appInstance->getActiveServicesByType($serviceType);

	my $numServices = $#{$servicesRef} + 1;
	my $csvHashRef;
	foreach my $service (@$servicesRef) {
		my $logPath = $statsLogPath . "/" . $service->host->hostName;
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
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

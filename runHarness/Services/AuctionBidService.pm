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
package AuctionBidService;

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

override 'initialize' => sub {
	my ( $self, $numAuctionBidServers ) = @_;

	super();
};

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::AuctionBidService");
	$logger->debug("stop AuctionBidService");
	
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $bidServiceCatalinaHome = $self->getParamValue('bidServiceCatalinaHome');
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	my $logName = "$logPath/StopAuctionBidService-$hostname.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the app server is up
	print $applog "Checking whether AuctionBidService is already up on $hostname\n";
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
		print $applog "Stopping AuctionBidService on $hostname\n";
		print $applog
		  "$sshConnectString CATALINA_BASE=\"$bidServiceCatalinaBase\" ${bidServiceCatalinaHome}/bin/shutdown.sh -force 2>&1 \n";
		my $out =
		  `$sshConnectString CATALINA_BASE=\"$bidServiceCatalinaBase\" ${bidServiceCatalinaHome}/bin/shutdown.sh -force 2>&1`;
		print $applog "$out\n";

		$out = `$sshConnectString jps`;
		print $applog "$out\n";
		if ( $out =~ /Bootstrap/ ) {
			print $applog "Couldn't stop AuctionBidService on $hostname: $out";
			die "Couldn't stop AuctionBidService on $hostname: $out";
		}

	}

	close $applog;

}

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartAuctionBidService-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $bidServiceCatalinaHome = $self->getParamValue('bidServiceCatalinaHome');
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	$self->portMap->{"http"}  = $self->internalPortMap->{"http"};
	$self->portMap->{"https"} = $self->internalPortMap->{"https"};
	$self->portMap->{"shutdown"} = $self->internalPortMap->{"shutdown"};

	$self->registerPortsWithHost();
	
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether the app server is up
	print $applog "Checking whether AuctionBidService is already up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting AuctionBidService on $hostname\n";
		print $applog "$sshConnectString CATALINA_BASE=\"$bidServiceCatalinaBase\" ${bidServiceCatalinaHome}/bin/startup.sh\n";
		my $out = `$sshConnectString CATALINA_BASE=\"$bidServiceCatalinaBase\" ${bidServiceCatalinaHome}/bin/startup.sh`;
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

	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset = $self->getParamValue( $serviceType . 'PortOffset')
		  + ( $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier );
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
	my $threads            = $self->getParamValue('auctionBidServerThreads') * $numCpus;
	my $connections        = $self->getParamValue('auctionBidServerJdbcConnections') * $numCpus;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	my $maxConnections =
	  ceil( $self->getParamValue('frontendConnectionMultiplier') *
		  $users /
		  ( $self->appInstance->getNumActiveOfServiceType('auctionBidServer') * 1.0 ) );
	if ( $maxConnections < 100 ) {
		$maxConnections = 100;
	}

	my $completeJVMOpts .= $self->getParamValue('auctionBidServerJvmOpts');
	$completeJVMOpts .= " " . $serviceParamsHashRef->{"jvmOpts"};
	if ( $self->getParamValue('auctionBidServiceEnableJprofiler') ) {
		$completeJVMOpts .=
		  " -agentpath:/opt/jprofiler8/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m";
	}

	if ( $self->getParamValue('logLevel') >= 3 ) {
		$completeJVMOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:$bidServiceCatalinaBase/logs/gc.log ";
	}
	$completeJVMOpts .= " -DnodeNumber=$nodeNum ";

	# Modify setenv.sh and then copy to app server
	open( FILEIN,  "$configDir/auctionBidService/setenv.sh" ) or die "Can't open file $configDir/auctionBidService/setenv.sh: $!\n";
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

	`$scpConnectString /tmp/setenv${suffix}-N${nodeNum}.sh root\@$scpHostString:${tomcbidServiceCatalinaBasen/setenv.sh`;

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

	open( FILEIN,  "$configDir/auctionBidService/server.xml" );
	open( FILEOUT, ">/tmp/server${suffix}-N${nodeNum}.xml" );
	my $maxIdle = ceil( $self->getParamValue('auctionBidServerJdbcConnections') / 2 );
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
			print FILEOUT "port=\"" . $self->internalPortMap->{"http"} . "\"\n";
			print FILEOUT "redirectPort=\"" . $self->internalPortMap->{"https"} . "\"/>\n";
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
	`$scpConnectString /tmp/server${suffix}-N${nodeNum}.xml root\@$scpHostString:$bidServiceCatalinaBase/conf/server.xml`;

	`$scpConnectString $configDir/auctionBidService/web.xml root\@$scpHostString:$bidServiceCatalinaBase/conf/web.xml`;
	`$scpConnectString $configDir/auctionBidService/context.xml root\@$scpHostString:$bidServiceCatalinaBase/conf/context.xml`;

}

sub stopStatsCollection {
	my ($self)   = @_;
	my $port     = $self->portMap->{"http"};
	my $hostname = $self->host->hostName;

	if ( $self->getParamValue('auctionBidServerPerformanceMonitor') ) {
`curl -s -o /tmp/$hostname-performanceMonitor.csv http://$hostname:$port/auction/javasimon/data/table.csv?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
`curl -s -o /tmp/$hostname-performanceMonitor.json http://$hostname:$port/auction/javasimon/data/table.json?type=STOPWATCH&type=COUNTER&timeFormat=NANOSECOND `;
	}
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $sshConnectString   = $self->host->sshConnectString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');
	`$sshConnectString \"cp $bidServiceCatalinaBase/logs/gc.log $bidServiceCatalinaBase/logs/gc_rampup.log\"`;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');
	my $hostname           = $self->host->hostName;

	`mv /tmp/$hostname-performanceMonitor.csv $destinationPath/. 2>&1`;
	`mv /tmp/$hostname-performanceMonitor.json $destinationPath/. 2>&1`;

	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/logs/gc*.log $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	`$sshConnectString \"rm $bidServiceCatalinaBase/logs/gc*.log 2>&1\"`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	my $maxLogLines = $self->getParamValue('maxLogLines');
	my $date = `$sshConnectString date +%Y-%m-%d`;
	chomp($date);
	
	$self->checkSizeAndTruncate("$bidServiceCatalinaBase/logs", "auction.log", $maxLogLines);
	$self->checkSizeAndTruncate("$bidServiceCatalinaBase/logs", "catalina.out", $maxLogLines);
	$self->checkSizeAndTruncate("$bidServiceCatalinaBase/logs", "catalina.$date.log", $maxLogLines);	
	$self->checkSizeAndTruncate("$bidServiceCatalinaBase/logs", "localhost.$date.log", $maxLogLines);	

	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/logs/auction.log $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/logs/catalina.out $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/logs/catalina.$date.log $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/logs/localhost.$date.log $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $sshConnectString   = $self->host->sshConnectString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');

	`$sshConnectString \"rm -f $bidServiceCatalinaBase/logs/*  2>&1\"`;
	`$sshConnectString \"rm -rf $bidServiceCatalinaBase/work/*  2>&1\"`;
	`$sshConnectString \"rm -rf /tmp/copycat*  2>&1\"`;
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	my $bidServiceCatalinaBase = $self->getParamValue('bidServiceCatalinaBase');
	`mkdir -p $destinationPath`;
	`$scpConnectString -r root\@$scpHostString:$bidServiceCatalinaBase/conf/* $destinationPath/. 2>&1`;
	`$scpConnectString root\@$scpHostString:$bidServiceCatalinaBase/bin/setenv.sh $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"auctionBidServerThreads"}     = $self->getParamValue('auctionBidServerThreads');
	$csv{"auctionBidServerThreads"} = $self->getParamValue('auctionBidServerThreads');
	$csv{"auctionBidServerJvmOpts"}     = $self->getParamValue('auctionBidServerJvmOpts');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	open( HOSTCSVFILE, ">>$statsLogPath/auctionBidServer_gc_summary.csv" )
	  or die "Can't open $statsLogPath/auctionBidServer_gc_summary.csv : $! \n";
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
			if ( !( exists $accumulatedCsv{"auctionBidServer_$key"} ) ) {
				$accumulatedCsv{"auctionBidServer_$key"} = $csvHashRef->{$key};
			}
			else {
				$accumulatedCsv{"auctionBidServer_$key"} += $csvHashRef->{$key};
			}
		}
		print HOSTCSVFILE "\n";

	}

	# Now turn the total into averages
	foreach my $key ( keys %$csvHashRef ) {
		if ( exists $accumulatedCsv{"auctionBidServer_$key"} ) {
			$accumulatedCsv{"auctionBidServer_$key"} /= $numServices;
		}
	}

	# Now add the key/value pairs to the returned csv
	@csv{ keys %accumulatedCsv } = values %accumulatedCsv;

	close HOSTCSVFILE;
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

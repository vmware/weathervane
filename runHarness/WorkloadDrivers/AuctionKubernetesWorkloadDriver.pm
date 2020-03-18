# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AuctionKubernetesWorkloadDriver;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use WorkloadDrivers::AuctionKubernetesWorkloadDriver;
use AppInstance::AppInstance;
use Parameters qw(getParamValue setParamValue);
use WeathervaneTypes;
use POSIX;
use List::Util qw[min max];
use StatsParsers::ParseGC qw( parseGCLog );
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use Log::Log4perl qw(get_logger);
use Tie::IxHash;
use LWP;
use JSON;
use Utils
  qw(callMethodOnObjectsParallel callMethodsOnObjectParallel callBooleanMethodOnObjectsParallel1
  callBooleanMethodOnObjectsParallel2 callMethodOnObjectsParallel1 callMethodOnObjectsParallel2
  callMethodsOnObject1 callMethodOnObjects1 runCmd);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

extends 'AuctionWorkloadDriver';

has 'namespace' => (
	is  => 'rw',
	isa => 'Str',
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();

	my $cluster = $self->host;
	$self->namespace($cluster->kubernetesGetNamespace($self->workload->instanceNum, ""));
};

override 'redeploy' => sub {
	my ( $self, $logfile, $hostsRef ) = @_;
};

override 'getControllerURL' => sub {
	my ( $self ) = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	if (!$self->controllerUrl) {
		$self->controllerUrl("http://localhost:80");
	}
	return $self->controllerUrl;
};

override 'getHosts' => sub {
	my ( $self ) = @_;
	my $numDrivers = $#{$self->secondaries} + 2;
	my @hosts;
	for (my $i = 0; $i < $numDrivers; $i++) {
		push @hosts, "wklddriver-${i}.wklddriver";
	}
	return \@hosts;
};

sub getHostPort {
	my ( $self ) = @_;
	return 80;
}

override 'getRunStatsHost' => sub {
	my ( $self ) = @_;
	return "localhost";
};

override 'getWorkloadStatsHost' => sub {
	my ( $self ) = @_;
	return "wkldcontroller";
};

override 'killOld' => sub {
	my ($self, $setupLogDir)           = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("killOld");
	$self->stopDrivers();
};

sub configureWkldController {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("Configure Workload Controller");
	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');
	my $workloadNum    = $self->workload->instanceNum;
	
	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $driverThreads                       = $self->getParamValue('driverThreads');
	my $driverHttpThreads                   = $self->getParamValue('driverHttpThreads');
	my $maxConnPerUser                      = $self->getParamValue('driverMaxConnPerUser');
	my $driverJvmOpts           = $self->getParamValue('driverControllerJvmOpts');
	if ( $self->getParamValue('logLevel') >= 3 ) {
		$driverJvmOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/tmp/gc-W${workloadNum}.log";
	}
	if ( $self->getParamValue('enableJmx') ) {
		$driverJvmOpts .= " -Dcom.sun.management.jmxremote.rmi.port=9090 -Dcom.sun.management.jmxremote=true "
							. "-Dcom.sun.management.jmxremote.port=9090 -Dcom.sun.management.jmxremote.ssl=false "
							. "-Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false "
							. "-Djava.rmi.server.hostname=127.0.0.1 ";
	}

	if ( $maxConnPerUser > 0 ) {
		$driverJvmOpts .= " -DMAXCONNPERUSER=" . $maxConnPerUser;
	}
	if ( $driverHttpThreads > 0 ) {
		$driverJvmOpts .= " -DNUMHTTPPOOLTHREADS=" . $driverHttpThreads . " ";
	}
	if ( $driverThreads > 0 ) {
		$driverJvmOpts .= " -DNUMSCHEDULEDPOOLTHREADS=" . $driverThreads . " ";
	}

	open( FILEIN,  "$configDir/kubernetes/auctionworkloadcontroller.yaml" ) or die "$configDir/kubernetes/auctionworkloadcontroller.yaml: $!\n";
	open( FILEOUT, ">/tmp/auctionworkloadcontroller-$namespace.yaml" )             or die "Can't open file /tmp/auctionworkloadcontroller-$namespace.yaml: $!\n";	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)PORT:/ ) {
			print FILEOUT "${1}PORT: \"80\"\n";
		}
		elsif ( $inline =~ /(\s+)JVMOPTS:/ ) {
			print FILEOUT "${1}JVMOPTS: \"$driverJvmOpts\"\n";
		}
		elsif ( $inline =~ /(\s+)WORKLOADNUM:/ ) {
			print FILEOUT "${1}WORKLOADNUM: \"$workloadNum\"\n";
		}
		elsif ( $inline =~ /(\s+)cpu:/ ) {
			print FILEOUT "${1}cpu: " . $self->getParamValue('driverControllerCpus') . "\n";
		}
		elsif ( $inline =~ /(\s+)memory:/ ) {
			print FILEOUT "${1}memory: " . $self->getParamValue('driverControllerMem') . "\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			if ($self->getParamValue('redeploy')) {
				print FILEOUT "${1}imagePullPolicy: Always\n";			
			} else {
				print FILEOUT "${1}imagePullPolicy: IfNotPresent\n";				
			}
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
}

sub configureWkldDriver {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("Configure Workload Driver");
	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');
	my $numDrivers        = $self->getParamValue('numDrivers');
	my $workloadNum    = $self->workload->instanceNum;

	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $driverThreads                       = $self->getParamValue('driverThreads');
	my $driverHttpThreads                   = $self->getParamValue('driverHttpThreads');
	my $maxConnPerUser                      = $self->getParamValue('driverMaxConnPerUser');
	my $driverJvmOpts           = $self->getParamValue('driverJvmOpts');
	if ( $self->getParamValue('logLevel') >= 3 ) {
		$driverJvmOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/tmp/gc-W${workloadNum}.log";
	}
	if ( $self->getParamValue('enableJmx') ) {
		$driverJvmOpts .= " -Dcom.sun.management.jmxremote.rmi.port=9090 -Dcom.sun.management.jmxremote=true "
							. "-Dcom.sun.management.jmxremote.port=9090 -Dcom.sun.management.jmxremote.ssl=false "
							. "-Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false "
							. "-Djava.rmi.server.hostname=127.0.0.1 ";
	}

	if ( $maxConnPerUser > 0 ) {
		$driverJvmOpts .= " -DMAXCONNPERUSER=" . $maxConnPerUser;
	}
	if ( $driverHttpThreads > 0 ) {
		$driverJvmOpts .= " -DNUMHTTPPOOLTHREADS=" . $driverHttpThreads . " ";
	}
	if ( $driverThreads > 0 ) {
		$driverJvmOpts .= " -DNUMSCHEDULEDPOOLTHREADS=" . $driverThreads . " ";
	}

	open( FILEIN,  "$configDir/kubernetes/auctionworkloaddriver.yaml" ) or die "$configDir/kubernetes/auctionworkloaddriver.yaml: $!\n";
	open( FILEOUT, ">/tmp/auctionworkloaddriver-$namespace.yaml" )             or die "Can't open file /tmp/auctionworkloaddriver-$namespace.yaml: $!\n";	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)PORT:/ ) {
			print FILEOUT "${1}PORT: \"80\"\n";
		}
		elsif ( $inline =~ /(\s+)JVMOPTS:/ ) {
			print FILEOUT "${1}JVMOPTS: \"$driverJvmOpts\"\n";
		}
		elsif ( $inline =~ /(\s+)WORKLOADNUM:/ ) {
			print FILEOUT "${1}WORKLOADNUM: \"$workloadNum\"\n";
		}
		elsif ( $inline =~ /(\s+)cpu:/ ) {
			print FILEOUT "${1}cpu: " . $self->getParamValue('driverCpus') . "\n";
		}
		elsif ( $inline =~ /(\s+)memory:/ ) {
			print FILEOUT "${1}memory: " . $self->getParamValue('driverMem') . "\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			if ($self->getParamValue('redeploy')) {
				print FILEOUT "${1}imagePullPolicy: Always\n";			
			} else {
				print FILEOUT "${1}imagePullPolicy: IfNotPresent\n";				
			}
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numDrivers\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
}

override 'startDrivers' => sub {
	my ( $self, $logDir, $suffix, $logHandle) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	my $cluster = $self->host;
	my $namespace = $self->namespace;
	
	$logger->debug("Starting Workload Controller");
	$self->configureWkldController();
	$cluster->kubernetesApply("/tmp/auctionworkloadcontroller-${namespace}.yaml", $namespace);

	$logger->debug("Starting Workload Driver");
	$self->configureWkldDriver();
	$cluster->kubernetesApply("/tmp/auctionworkloaddriver-${namespace}.yaml", $namespace);	
	
};

override 'doHttpPost' => sub {
	my ( $self, $url, $content) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("doHttpPost: Sending POST to $url.");

	# Write the content into a local file
	my $namespace = $self->namespace;
	open( my $contentFile, ">content-${namespace}.json" ) or die "Can't open file content-${namespace}.json: $!\n";	
	my @contentLines = split(/\n/, $content);
	foreach my $line (@contentLines) {
		print $contentFile $line;
	}
	close $contentFile;
		
	my $cluster = $self->host;
	my $success = $cluster->kubernetesCopyToFirst("impl=wkldcontroller", "wkldcontroller", $namespace, 
												"content-${namespace}.json", "content.json" );
	if (!$success) {
		$logger->debug("Error copying content to content.json");
		return {"is_success" => 0, "content" => "" };
	} 
	
	my $cmd = "bash -c \"http --pretty none --print hb --timeout 240 POST $url < content.json\"";
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne("wkldcontroller", $cmd, $self->namespace);
	if ($cmdFailed) {
		return {"is_success" => 0, "content" => "" };
	} 
	
	# Parse the response
	my @outLines = split(/\n/, $outString);
	my $status_line = $outLines[0];
	chomp($status_line);
	my $isSuccess = 1;
	if (($status_line =~ /1\.1\s+4\d\d/) || ($status_line =~ /1\.1\s+5\d\d/)) {
		$isSuccess = 0;
	}
	
	my $responseContent = "";
	my $foundContent = 0;
	foreach my $line (@outLines) {
		if ($line =~ /^\s*$/) {
			# Blank lines start and end content
			if ($foundContent) {
				last;
			} else {
			    $foundContent = 1;
			    next;			
			}
		}
		if ($foundContent) {
			$responseContent .= $line;	
		}
	}

	$logger->debug("doHttpPost Response status line: " . $status_line . 
				", is_success = " . $isSuccess . 
				", content = " . $responseContent );
	
	return {"is_success" => $isSuccess,
			"content" => $responseContent
	};
};

override 'doHttpGet' => sub {
	my ( $self, $url) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("doHttpGet: Sending Get to $url.");
	
	my $cmd = "http --pretty none --print hb --timeout 120 GET $url";
	my $cluster = $self->host;
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne("wkldcontroller", $cmd, $self->namespace);
	if ($cmdFailed) {
		return {"is_success" => 0, "content" => "" };
	} 
	
	# Parse the response
	my @outLines = split(/\n/, $outString);
	my $status_line = $outLines[0];
	chomp($status_line);
	my $isSuccess = 1;
	if (($status_line =~ /1\.1\s+4\d\d/) || ($status_line =~ /1\.1\s+5\d\d/)) {
		$isSuccess = 0;
	}
	
	my $responseContent = "";
	my $foundContent = 0;
	foreach my $line (@outLines) {
		if ($line =~ /^\s*$/) {
			# Blank lines start and end content
			if ($foundContent) {
				last;
			} else {
			    $foundContent = 1;
			    next;			
			}
		}
		if ($foundContent) {
			$responseContent .= $line;	
		}
	}

	$logger->debug("doHttpGet Response status line: " . $status_line . 
				", is_success = " . $isSuccess . 
				", content = " . $responseContent );
	
	return {"is_success" => $isSuccess,
			"content" => $responseContent
	};
};

override 'isUp' => sub {
	my ($self) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $cluster = $self->host;

	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne( "wkldcontroller", "curl http://localhost:80/run/up", $self->namespace );
	if ($cmdFailed) {
		return 0;
	} else {
		if ($outString =~ /isStarted\":true/) {
			return 1;
		} else {
			return 0;
		}		
	}
	return 0;
};

override 'followLogs' => sub {
	my ( $self, $logDir, $suffix, $logHandle) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	my $cluster = $self->host;
	my $namespace = $self->namespace;
	
	my $pid              = fork();
	if ( $pid == 0 ) {
		$cluster->kubernetesFollowLogsFirstPod("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "$logDir/run$suffix.log" );
		exit;
	}	
};

override 'getLogFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	$self->host->kubernetesGetLogs("type=node", "wklddriver", $namespace, $destinationPath );
};

override 'stopDrivers' => sub {
	my ( $self, $logHandle) = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
	$logger->debug("stopDrivers");
	my $cluster = $self->host;
	
	my $selector = "app=auction,tier=driver";
	$cluster->kubernetesDeleteAllWithLabel($selector, $self->namespace);
};

override 'getStatsFiles' => sub {
	my ( $self, $baseDestinationPath ) = @_;
	my $hostname           = $self->host->name;
	my $destinationPath  = $baseDestinationPath . "/" . $hostname;
	my $workloadNum      = $self->workload->instanceNum;
	my $namespace             = $self->namespace;
		
	if ( !( -e $destinationPath ) ) {
		`mkdir -p $destinationPath`;
	} else {
		return;
	}

	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/gc-W${workloadNum}.log", "$destinationPath/gc-W${workloadNum}.log" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/appInstance${workloadNum}-loadPath1.csv", "$destinationPath/appInstance${workloadNum}-loadPath1.csv" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/appInstance${workloadNum}-loadPath1-allSamples.csv", "$destinationPath/appInstance${workloadNum}-loadPath1-allSamples.csv" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/appInstance${workloadNum}-periodic.csv", "$destinationPath/appInstance${workloadNum}-periodic.csv" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/appInstance${workloadNum}-periodic-allSamples.csv", "$destinationPath/appInstance${workloadNum}-periodic-allSamples.csv" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=controller", "wkldcontroller", $namespace, "/tmp/appInstance${workloadNum}-loadPath1-summary.txt", "$destinationPath/appInstance${workloadNum}-loadPath1-summary.txt" );
	$self->host->kubernetesCopyFromFirst("app=auction,tier=driver,type=node", "wklddriver", $namespace, "/tmp/gc-W${workloadNum}.log", "$destinationPath/gc-W${workloadNum}-wklddriver.log" );
};

override 'getNumActiveUsers' => sub {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
};

override 'setNumActiveUsers' => sub {
	my ( $self, $appInstanceName, $numUsers ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionKubernetesWorkloadDriver");
};

__PACKAGE__->meta->make_immutable;

1;

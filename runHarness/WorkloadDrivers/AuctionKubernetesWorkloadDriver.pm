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
package AuctionKubernetesWorkloadDriver;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use WorkloadDrivers::AuctionWorkloadDriver;
use AppInstance::AppInstance;
use Parameters qw(getParamValue setParamValue);
use WeathervaneTypes;
use POSIX;
use List::Util qw[min max];
use StatsParsers::ParseGC qw( parseGCLog );
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use Log::Log4perl qw(get_logger);
use Utils;
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

has 'imagePullPolicy' => (
	is      => 'rw',
	isa     => 'Str',
	default => "IfNotPresent",
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();
	$self->namespace("auctionw" . $self->workload->instanceNum);

};

override 'redeploy' => sub {
	my ( $self, $logfile, $hostsRef ) = @_;
	$self->imagePullPolicy("Always");
};

override 'getControllerURL' => sub {
	my ( $self ) = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $cluster = $self->host;
	
	my $hostname;
	my $port;
	$logger->debug("getControllerURL: useLoadBalancer = " . $cluster->getParamValue('useLoadBalancer'));
	if ($cluster->getParamValue('useLoadBalancer')) {
		# Wait for ip to be provisioned
		# ToDo: Need a timeout here.
		my $ip = "";
		while (!$ip) {
			my $cmdFailed;
		  	($cmdFailed, $ip) = $cluster->kubernetesGetLbIP("wkldcontroller", $self->namespace);
		  	if ($cmdFailed)	{
		  		$logger->error("Error getting IP for wkldcontroller loadbalancer: error = $cmdFailed");
		  	}
		  	if (!$ip) {
		  		sleep 10;
		  	}
			$logger->debug("Called kubernetesGetLbIP: got $ip");
		}
        $hostname = $ip;
	    $port = $self->portMap->{'http'};
	} else {
		# Using NodePort service for ingress
		# Get the IP addresses of the nodes 
		my $ipAddrsRef = $cluster->kubernetesGetNodeIPs();
		if ($#{$ipAddrsRef} < 0) {
			$logger->error("There are no IP addresses for the Kubernetes nodes");
			exit 1;
		}
		$hostname = $ipAddrsRef->[0];
		$port = $cluster->kubernetesGetNodePortForPortNumber("app=auction,tier=driver,type=controller", $self->portMap->{'http'}, $self->namespace);
	}
	return "http://${hostname}:$port";
};

override 'getHosts' => sub {
	my ( $self ) = @_;
	my $numDrivers = $#{$self->secondaries} + 2;
	my @hosts;
	for (my $i = 0; $i < $numDrivers; $i++) {
		push @hosts, "wklddriver-$i";
	}
	return \@hosts;
};

override 'getStatsHost' => sub {
	my ( $self ) = @_;
	return "wkldcontroller";
};

override 'killOld' => sub {
	my ($self, $setupLogDir)           = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("killOld");
	$self->stopDrivers();
};

sub configureWkldController {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
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
			print FILEOUT "${1}PORT: \"" . $self->portMap->{'http'} . "\"\n";
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
			print FILEOUT "${1}imagePullPolicy: " . $self->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /(\s+)type:\s+LoadBalancer/ ) {
			my $useLoadbalancer = $self->host->getParamValue('useLoadBalancer');
			if (!$useLoadbalancer) {
				print FILEOUT "${1}type: NodePort\n";				
			} else {
				print FILEOUT $inline;		
			}
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
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("Configure Workload Driver");
	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');
	my $workloadNum    = $self->workload->instanceNum;

	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $driverThreads                       = $self->getParamValue('driverThreads');
	my $driverHttpThreads                   = $self->getParamValue('driverHttpThreads');
	my $maxConnPerUser                      = $self->getParamValue('driverMaxConnPerUser');
	my $driverJvmOpts           = $self->getParamValue('driverJvmOpts');
	if ( $self->getParamValue('logLevel') >= 3 ) {
		$driverJvmOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/tmp/gc-W${workloadNum}.log";
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
			print FILEOUT "${1}PORT: \"" . $self->portMap->{'http'} . "\"\n";
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
			print FILEOUT "${1}imagePullPolicy: " . $self->imagePullPolicy . "\n";
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

override 'startDrivers' => sub {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $cluster = $self->host;
	my $namespace = $self->namespace;
	
	$logger->debug("Starting Workload Controller");
	$self->configureWkldController();
	$cluster->kubernetesApply("/tmp/auctionworkloadcontroller-${namespace}.yaml", $namespace);
	
	$logger->debug("Starting Workload Driver");
	$self->configureWkldController();
	$cluster->kubernetesApply("/tmp/auctionworkloadcontroller-${namespace}.yaml", $namespace);	
	
};

override 'stopDrivers' => sub {
	my ( $self ) = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("stopDrivers");
	my $cluster = $self->host;
	my $selector = "app=auction,tier=driver";
	$cluster->kubernetesDeleteAllWithLabel($selector, $self->namespace);
};

sub getStatsFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $hostname           = $self->host->name;
	my $destinationPath  = $baseDestinationPath . "/" . $hostname;
	my $workloadNum      = $self->workload->instanceNum;
	my $name               = $self->name;
		
	if ( !( -e $destinationPath ) ) {
		`mkdir -p $destinationPath`;
	} else {
		return;
	}

	my $logName = "$destinationPath/GetStatsFilesWorkloadDriver-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerCopyFrom( $applog, $name, "/tmp/gc-W${workloadNum}.log", "$destinationPath/." );
	$self->host->dockerCopyFrom( $applog, $name, "/tmp/appInstance${workloadNum}-loadPath1.csv", "$destinationPath/." );
	$self->host->dockerCopyFrom( $applog, $name, "/tmp/appInstance${workloadNum}-loadPath1-allSamples.csv", "$destinationPath/." );
	$self->host->dockerCopyFrom( $applog, $name, "/tmp/appInstance${workloadNum}-periodic.csv", "$destinationPath/." );
	$self->host->dockerCopyFrom( $applog, $name, "/tmp/appInstance${workloadNum}-periodic-allSamples.csv", "$destinationPath/." );
	$self->host->dockerCopyFrom( $applog, $name, "/tmp/appInstance${workloadNum}-loadPath1-summary.txt", "$destinationPath/." );

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $secHostname     = $secondary->host->name;
		$destinationPath = $baseDestinationPath . "/" . $secHostname;
		`mkdir -p $destinationPath 2>&1`;
		$name     = $secondary->name;
		$secondary->host->dockerCopyFrom( $applog, $name, "/tmp/gc-W${workloadNum}.log", "$destinationPath/." );
	}

}

override 'getNumActiveUsers' => sub {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
};

override 'setNumActiveUsers' => sub {
	my ( $self, $appInstanceName, $numUsers ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
};

__PACKAGE__->meta->make_immutable;

1;

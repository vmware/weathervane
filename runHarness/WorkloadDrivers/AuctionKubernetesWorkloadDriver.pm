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
	
};

sub killOld {
	my ($self, $setupLogDir)           = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum    = $self->workload->instanceNum;
	$logger->debug("killOld");
	my $cluster = $self->host;
	my $selector = "app=auction,tier=driver";
	$cluster->kubernetesDeleteAllWithLabel($selector, $self->namespace);
}

override 'startDrivers' => sub {
	my ( $self ) = @_;
	
};

override 'stopDrivers' => sub {
	my ( $self ) = @_;
	
};

sub startAuctionWorkloadDriverContainer {
	my ( $self, $driver, $applog ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum    = $driver->workload->instanceNum;
	my $name        = $driver->name;
		
	$driver->host->dockerStopAndRemove( $applog, $name );

	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $weathervaneWorkloadHome = $driver->getParamValue('workloadDriverDir');
	my $workloadProfileHome     = $driver->getParamValue('workloadProfileDir');

	my $driverThreads                       = $driver->getParamValue('driverThreads');
	my $driverHttpThreads                   = $driver->getParamValue('driverHttpThreads');
	my $maxConnPerUser                      = $driver->getParamValue('driverMaxConnPerUser');

	my $port = $driver->portMap->{'http'};

	my $driverJvmOpts           = $driver->getParamValue('driverJvmOpts');
	if ( $driver->getParamValue('logLevel') >= 3 ) {
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
	my %envVarMap;
	$envVarMap{"PORT"} = $port;	
	$envVarMap{"JVMOPTS"} = "\"$driverJvmOpts\"";	
	$envVarMap{"WORKLOADNUM"} = $workloadNum;	
	
	# Start the  auctionworkloaddriver container
	my %volumeMap;
	my %portMap;
	my $directMap = 0;
	my $cmd        = "";
	my $entryPoint = "";
	my $dockerConfigHashRef = {};	
	$dockerConfigHashRef->{'net'} = "host";

	my $numCpus = $driver->getParamValue('driverCpus');
	my $mem = $driver->getParamValue('driverMem');
	if ($numCpus) {
		$dockerConfigHashRef->{'cpus'} = $numCpus;
	}
	if ($driver->getParamValue('dockerCpuShares')) {
		$dockerConfigHashRef->{'cpu-shares'} = $driver->getParamValue('dockerCpuShares');
	} 
	if ($driver->getParamValue('dockerCpuSetCpus') ne "unset") {
		$dockerConfigHashRef->{'cpuset-cpus'} = $driver->getParamValue('dockerCpuSetCpus');		
	}
	if ($driver->getParamValue('dockerCpuSetMems') ne "unset") {
		$dockerConfigHashRef->{'cpuset-mems'} = $driver->getParamValue('dockerCpuSetMems');
	}
	if ($mem) {
		$dockerConfigHashRef->{'memory'} = $mem;
	}
	if ($driver->getParamValue('dockerMemorySwap')) {
		$dockerConfigHashRef->{'memory-swap'} = $driver->getParamValue('dockerMemorySwap');
	}	
	$driver->host->dockerRun(
		$applog, $name,
		"auctionworkloaddriver", $directMap, \%portMap, \%volumeMap, \%envVarMap, $dockerConfigHashRef,
		$entryPoint, $cmd, 1
	);
}

sub stopAuctionWorkloadDriverContainer {
	my ( $self, $applog, $driver ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $name        = $driver->name;

	$driver->host->dockerStopAndRemove( $applog, $name );

}

sub stopRun {
	my ( $self, $runNum, $logDir, $suffix ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	my $workloadNum             = $self->workload->instanceNum;
	my $runName                 = "runW${workloadNum}";
	my $port = $self->portMap->{'http'};
	my $hostname = $self->host->name;

	my $logName = "$logDir/StopRun$suffix.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	# Create a list of all of the workloadDriver nodes including the primary
	my $driversRef     = [];
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		push @$driversRef, $secondary;
	}
	push @$driversRef, $self;

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");
	
	
	# Now send the shutdown message
	my $url      = "http://$hostname:$port/run/$runName/shutdown";
	$logger->debug("Sending POST to $url");
	my $req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	my $runContent = "{}";
	$req->content($runContent);

	my $res = $ua->request($req);
	$logger->debug( "Response status line: "
		  . $res->status_line
		  . " for url "
		  . $url );
	if ( $res->is_success ) {
		$logger->debug(
			"Response sucessful.  Content: " . $res->content );
	}	
	else {
		$console_logger->warn(
			"Could not send shutdown message to workload driver node on $hostname. Exiting"
		);
		return 0;
	}
				
	# Now stop and remove all of the driver containers
	foreach my $driver (@$driversRef) {
		$self->stopAuctionWorkloadDriverContainer($logHandle, $driver);
	}

	close $logHandle;
	return 1;

}

sub isUp {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my $hostname = $self->host->name;
	my $port     = $self->portMap->{'http'};
	my $json     = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");

	my $url = "http://$hostname:$port/run/$runName/up";
	$logger->debug("Sending get to $url");
	my $req = HTTP::Request->new( GET => $url );

	my $res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		my $jsonResponse = $json->decode( $res->content );

		if ( $jsonResponse->{"isStarted"} ) {
			return 1;
		}
	}
	return 0;

}

sub isStarted {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my $hostname = $self->host->name;
	my $port     = $self->portMap->{'http'};
	my $json     = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");

	my $url = "http://$hostname:$port/run/$runName/start";
	$logger->debug("Sending get to $url");
	my $req = HTTP::Request->new( GET => $url );

	my $res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		my $jsonResponse = $json->decode( $res->content );

		if ( $jsonResponse->{"isStarted"} ) {
			return 1;
		}
	}
	return 0;

}

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

sub getNumActiveUsers {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my %appInstanceToUsersHash;

	my $ua = LWP::UserAgent->new;

	$ua->timeout(300);
	$ua->agent("Weathervane/1.0");

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	# Get the number of users on the primary driver
	my $hostname = $self->host->name;
	my $port     = $self->portMap->{'http'};

	my $url = "http://$hostname:$port/run/$runName/users";
	$logger->debug("Sending get to $url");

	my $req = HTTP::Request->new( GET => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );

	my $res = $ua->request($req);
	$logger->debug( "Response status line: " . $res->status_line );
	my $contentHashRef = $json->decode( $res->content );
	$logger->debug( "Response content:\n" . $res->content );
	my $workloadActiveUsersRef = $contentHashRef->{'workloadActiveUsers'};
	foreach my $appInstance ( keys %$workloadActiveUsersRef ) {
		my $numUsers = $workloadActiveUsersRef->{$appInstance};
		$logger->debug(
"For workloadDriver host $hostname, appInstance $appInstance has $numUsers active users."
		);
		$appInstanceToUsersHash{$appInstance} = $numUsers;
	}

	# get the number of users on each secondary driver
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		$hostname = $secondary->host->name;
		$port     = $secondary->portMap->{'http'};

		$url = "http://$hostname:$port/run/$runName/users";
		$logger->debug("Sending get to $url");

		$req = HTTP::Request->new( GET => $url );
		$req->content_type('application/json');
		$req->header( Accept => "application/json" );

		$res = $ua->request($req);
		$logger->debug( "Response status line: " . $res->status_line );
		$contentHashRef = $json->decode( $res->content );
		$logger->debug( "Response content:\n" . $res->content );
		my $workloadActiveUsersRef = $contentHashRef->{'workloadActiveUsers'};
		foreach my $appInstance ( keys %$workloadActiveUsersRef ) {
			my $numUsers = $workloadActiveUsersRef->{$appInstance};
			$logger->debug(
"For workloadDriver host $hostname, appInstance $appInstance has $numUsers active users."
			);
			$appInstanceToUsersHash{$appInstance} =
			  $appInstanceToUsersHash{$appInstance} + $numUsers;
		}

	}

	return \%appInstanceToUsersHash;
}

sub setNumActiveUsers {
	my ( $self, $appInstanceName, $numUsers ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my %appInstanceToUsersHash;

	my $ua = LWP::UserAgent->new;

	$ua->timeout(300);
	$ua->agent("Weathervane/1.0");

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	# Need to divide the number of users across the number of workload
	# driver nodes.
	my $secondariesRef = $self->secondaries;
	my @workloadDrivers;
	push @workloadDrivers, $self;
	push @workloadDrivers, @$secondariesRef;

	my $driverNum = 0;
	foreach my $driver (@workloadDrivers) {
		my $users =
		  $self->adjustUsersForLoadInterval( $numUsers, $driverNum,
			$#workloadDrivers + 1 );
		my $hostname = $driver->host->name;
		my $port     = $driver->portMap->{'http'};
		my $url =
		  "http://$hostname:$port/run/$runName/workload/$appInstanceName/users";
		$logger->debug("Sending POST to $url");

		my $changeMessageContent = {};
		$changeMessageContent->{"numUsers"} = $users;
		my $content = $json->encode($changeMessageContent);

		$logger->debug("Content = $content");
		my $req = HTTP::Request->new( POST => $url );
		$req->content_type('application/json');
		$req->header( Accept => "application/json" );
		$req->content($content);

		my $res = $ua->request($req);
		$logger->debug( "Response status line: " . $res->status_line );
		my $contentHashRef = $json->decode( $res->content );
		$logger->debug( "Response content:\n" . $res->content );

		$driverNum++;
	}

}

sub parseStats {
	my ( $self, $tmpDir ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum             = $self->workload->instanceNum;
	my $runName                 = "runW${workloadNum}";
	my $port = $self->portMap->{'http'};
	my $hostname = $self->host->name;

	if ($self->resultsValid) {
		return 1;
	}

	my $anyUsedLoadPath = 0;
	my $appInstancesRef = $self->workload->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $userLoadPath = $appInstance->getLoadPath();
		if ( $#$userLoadPath >= 0 ) {
			$anyUsedLoadPath = 1;
		}
	}
	
	my @operations = @{ $self->operations };

	# Initialize the counters used for the csv output
	for ( my $opCounter = 0 ; $opCounter <= $#operations ; $opCounter++ ) {
		$self->proportion->{ $operations[$opCounter] } = 0;
		$self->successes->{ $operations[$opCounter] }  = 0;
		$self->failures->{ $operations[$opCounter] }   = 0;
		$self->rtAvg->{ $operations[$opCounter] }      = 0;
		$self->pctPassRT->{ $operations[$opCounter] }  = 0;
	}	
	
	my $numAppInstances = $#$appInstancesRef + 1;
	my $suffix          = $self->workload->suffix;
	
	# Get the final stats summary from the workload driver
	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");
	my $url = "http://$hostname:$port/run/$runName/state";
	$logger->debug("Sending get to $url");
	my $req = HTTP::Request->new( GET => $url );
	my $res = $ua->request($req);
	my $runStatus;
	$logger->debug("Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$runStatus = $json->decode( $res->content );			
	} else {
		$console_logger->warn("Could not retrieve find run state for workload $workloadNum");
		return 0;
	}

	$logger->debug("parseStats: Parsing stats");
	
	my $workloadStati = $runStatus->{"workloadStati"};
	foreach my $workloadStatus (@$workloadStati) {
		# For each appinstance, get the statsRollup for the max passing loadInterval
		my $appInstanceName = $workloadStatus->{"name"};
		$appInstanceName =~ /appInstance(\d+)/;
		my $appInstanceNum = $1;
		my $statsSummaries = $workloadStatus->{"intervalStatsSummaries"};
		my $maxPassIntervalName = $workloadStatus->{"maxPassIntervalName"};
		my $maxPassUsers = $workloadStatus->{"maxPassUsers"};
		my $passed = $workloadStatus->{"passed"};
		$logger->debug("parseStats: Found workloadStatus for workload " . $appInstanceName 
					. ", appInstanceNum = " . $appInstanceNum);
		
		my $maxPassStatsSummary = "";
		for my $statsSummary (@$statsSummaries) {
			if ($statsSummary->{"intervalName"} eq $maxPassIntervalName) {
				$maxPassStatsSummary = $statsSummary;
			}
		}
		
		if (!$maxPassStatsSummary) {
			$console_logger->warn("Could not find the max passing interval for appInstance " + $appInstanceName);
			next;
		}
		
		$self->maxPassUsers->{$appInstanceNum} = $maxPassUsers;
		$self->passAll->{$appInstanceNum} = $maxPassStatsSummary->{"intervalPassed"};
		$self->passRT->{$appInstanceNum} = $maxPassStatsSummary->{"intervalPassedRT"};
		$self->overallAvgRT->{$appInstanceNum} = $maxPassStatsSummary->{"avgRT"};
		$self->opsSec->{$appInstanceNum} = $maxPassStatsSummary->{"throughput"};
		$self->reqSec->{$appInstanceNum} = $maxPassStatsSummary->{"stepsThroughput"};
		
		open( RESULTFILE, "$tmpDir/run$suffix.log" )
		  or die "Can't open $tmpDir/run$suffix.log: $!";

		while ( my $inline = <RESULTFILE> ) {
	
			if ( $inline =~ /Summary Statistics for workload appInstance${appInstanceNum}\s*$/ )
			{

				# This is the section with the operation response-time data
				# for appInstance $1
				while ( $inline = <RESULTFILE> ) {

					if ( $inline =~ /Interval:\s$maxPassIntervalName/ ) {

						# parse the steadystate results for appInstance $1
						while ( $inline = <RESULTFILE> ) {
							if ( $inline =~ /\|\s+Name/ ) {

								# Now can parse the per-operation stats
								while ( $inline = <RESULTFILE> ) {
									if ( $inline =~ /^\s*$/ ) {
										last;
									}
									elsif ( $inline =~
/\|\s*(\w+)\|[^\|]*\|\s*(true|false)\|\s*(true|false)\|[^\|]*\|\s*(\d+\.\d+)\|[^\|]*\|[^\|]*\|[^\|]*\|[^\|]*\|\s*(\d+\.\d+)\|\s*(\d+\.\d+)\|\s*(\d+)\|\s*(\d+)\|/
									  )
									{

										my $operation = $1;
										my $opPassRT  = $2;
										my $opPassMix = $3;

										$self->rtAvg->{"$operation-$appInstanceNum"}
										  = $4;
										$self->proportion->{
											"$operation-$appInstanceNum"} = $5;
										$self->pctPassRT->{
											"$operation-$appInstanceNum"} = $6;

										$self->successes->{
											"$operation-$appInstanceNum"} = $7;
										$self->failures->{
											"$operation-$appInstanceNum"} = $8;

										if ( $opPassRT eq "false" ) {
											$console_logger->info(
"Workload $workloadNum AppInstance $appInstanceNum: Failed Response-Time metric for $operation"
											);
										}
										if (   ( $opPassMix eq "false" )
											&& ( $anyUsedLoadPath == 0 ) )
										{
											$console_logger->info(
"Workload $workloadNum AppInstance $appInstanceNum: Proportion check failed for $operation"
											);
										}

									}
								}
							}
							if ( $inline =~ /^\s*$/ ) {
								last;
							}
						}
					}
				}
			}
		}
		close RESULTFILE;
		
		my $resultString = "passed at $maxPassUsers";
		if (!$passed) {
			$resultString = "failed";
		}
		
		$console_logger->info("Workload $workloadNum, appInstance $appInstanceName: $resultString");
		
	}
	
	$self->resultsValid(1);
	return 1;

}

__PACKAGE__->meta->make_immutable;

1;

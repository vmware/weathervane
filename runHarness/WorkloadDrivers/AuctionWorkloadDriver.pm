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
package AuctionWorkloadDriver;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use WorkloadDrivers::WorkloadDriver;
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

extends 'WorkloadDriver';

has 'secondaries' => (
	is      => 'rw',
	isa     => 'ArrayRef[WorkloadDriver]',
	default => sub { [] },
);

has 'appInstances' => (
	is      => 'rw',
	isa     => 'ArrayRef[AppInstance]',
	default => sub { [] },
);

has 'operations' => (
	is      => 'ro',
	isa     => 'ArrayRef',
	default => sub {
		[
			"HomePage",           "Register",
			"Login",              "GetActiveAuctions",
			"GetAuctionDetail",   "GetUserProfile",
			"UpdateUserProfile",  "JoinAuction",
			"GetCurrentItem",     "GetNextBid",
			"PlaceBid",           "LeaveAuction",
			"GetBidHistory",      "GetAttendanceHistory",
			"GetPurchaseHistory", "GetItemDetail",
			"GetImageForItem",    "AddItem",
			"AddImageForItem",    "Logout",
			"NoOperation"
		];
	},
);

# Variables used to cache the results of parsing
# the results.
has 'resultsValid' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

has 'opsSec' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'reqSec' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'maxPassUsers' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'passAll' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'passRT' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'passFailure' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'overallAvgRT' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'rtAvg' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'pctPassRT' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'successes' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'failures' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'rtFailures' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'proportion' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'suffix' => (
	is      => 'rw',
	isa     => 'Str',
	default => "",
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();
	my $workloadNum = $self->workload->instanceNum;
	my $instanceNum = $self->instanceNum;
	$self->name("driverW${workloadNum}I${instanceNum}");
};

override 'addSecondary' => sub {
	my ( $self, $secondary ) = @_;
	my $console_logger = get_logger("Console");

	#ToDo: Add test for running on same docker host
	push @{ $self->secondaries }, $secondary;

};

sub checkConfig {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $workloadNum    = $self->workload->instanceNum;
	
	# Validate the the CPU and Mem sizings are in valid Kubernetes format
	my @drivers =  @{ $self->secondaries };
	push @drivers, $self;
	foreach my $driver (@drivers) {
		# A K8S CPU limit should be either a real number (e.g. 1.5), which
		# is legal docker notation, or an integer followed an "m" to indicate a millicpu
		my $cpus = $driver->getParamValue("driverCpus");
		if (!(($cpus =~ /^\d*\.?\d+$/) || ($cpus =~ /^\d+m$/))) {
			$console_logger->error("Workload $workloadNum: $cpus is not a valid value for driverCpus.");
			$console_logger->error("CPU limit specifications must use Kubernetes notation.  See " . 
						"https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/");
			return 0;			
		} elsif ($cpus =~ /^(\d+)m$/) {
			# Convert all CPU specifications to numbers
			$cpus = ($1 * 1.0) / 1000.0;
			$driver->setParamValue("driverCpus", $cpus);
		}

		# K8s Memory limits are an integer followed by an optional suffix.
		# The legal suffixes in K8s are:
		#  * E, P, T, G, M, K (powers of 10)
		#  * Ei, Pi, Ti, Gi, Mi, Ki (powers of 2)
		my $mem = $driver->getParamValue("driverMem");
		if (!($mem =~ /^\d+(E|P|T|G|M|K|Ei|Pi|Ti|Gi|Mi|Ki)?$/)) {
			$console_logger->error("Workload $workloadNum: $mem is not a valid value for driverMem.");
			$console_logger->error("Memory limit specifications must use Kubernetes notation.  See " . 
						"https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/");
			return 0;			
		}
	}

	return 1;
}

sub setPortNumbers {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	my $portMultiplier = $self->getNextPortMultiplier();
	my $portOffset =
	  $self->getParamValue('workloadDriverPortStep') * $portMultiplier;

	$self->internalPortMap->{'http'} =
	  $self->getParamValue('workloadDriverPort') + $portOffset;
	$self->portMap->{'http'} = $self->internalPortMap->{'http'};

	$logger->debug( "setPortNumbers.  Set http port to "
		  . $self->internalPortMap->{'http'} );

}

sub setExternalPortNumbers {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	$self->portMap->{'http'} = $self->internalPortMap->{'http'};
	$logger->debug( "setExternalPortNumbers.  Set http port to "
		  . $self->portMap->{'http'} );

}

sub setPortNumber {
	my ( $self, $portNumber ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	$self->internalPortMap->{'http'} = $portNumber;
	$self->portMap->{'http'}         = $portNumber;

}

sub adjustUsersForLoadInterval {
	my ( $self, $users, $targetNum, $numTargets ) = @_;
	my $usersPerNode   = floor( $users / $numTargets );
	my $remainingUsers = $users % $numTargets;
	if ( $remainingUsers > $targetNum ) {
		$usersPerNode += 1;
	}
	return $usersPerNode;
}

sub printLoadInterval {
	my ( $self, $loadIntervalRef, $intervalListRef, $nextIntervalNumber) = @_;

	my $interval = {};

	$interval->{"duration"} = $loadIntervalRef->{"duration"};
	$interval->{"name"}     = "$nextIntervalNumber";

	if (   ( exists $loadIntervalRef->{"users"} )
		&& ( exists $loadIntervalRef->{"duration"} ) )
	{
		$interval->{"type"}  = "uniform";
		$interval->{"users"} = $loadIntervalRef->{"users"};
	}
	elsif (( exists $loadIntervalRef->{"endUsers"} )
		&& ( exists $loadIntervalRef->{"duration"} ) )
	{
		$interval->{"type"} = "ramp";
		if ( exists $loadIntervalRef->{"timeStep"} ) {
			$interval->{"timeStep"} = $loadIntervalRef->{"timeStep"};
		}
		if ( exists $loadIntervalRef->{"startUsers"} ) {
			$interval->{"startUsers"} = $loadIntervalRef->{"startUsers"};
		}
		$interval->{"endUsers"} = $loadIntervalRef->{"endUsers"};

	}

	push @$intervalListRef, $interval;

}

sub printLoadPath {
	my ( $self, $loadPathRef, $intervalListRef,	$totalTime ) = @_;
	my $accumulatedDuration = 0;
	my $nextIntervalNumber  = 1;

	do {
		foreach my $loadIntervalRef (@$loadPathRef) {
			$self->printLoadInterval( $loadIntervalRef, $intervalListRef,
				$nextIntervalNumber );
			$nextIntervalNumber++;

			$accumulatedDuration += $loadIntervalRef->{"duration"};
			if ( $accumulatedDuration >= $totalTime ) {
				return;
			}
		}
	} while ( $self->getParamValue('repeatUserLoadPath') );

}

sub getControllerURL {
	my ( $self ) = @_;
	my $port = $self->portMap->{'http'};
	my $hostname = $self->host->name;
	return "http://${hostname}:$port";
}

sub getHosts {
	my ( $self ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my @hosts;
	my $secondariesRef = $self->secondaries;
	push @hosts, $self->host->name;
	foreach my $secondary (@$secondariesRef) {
		$logger->debug("getHosts adding host " . $secondary->host->name);
		push @hosts, $secondary->host->name;
	}
	return \@hosts;
}

sub getHostPort {
	my ( $self ) = @_;
	return $self->portMap->{'http'};
}

sub getStatsHost {
	my ( $self ) = @_;
	return $self->host->name
}

sub createRunConfigHash {
	my ( $self, $appInstancesRef, $suffix ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $console_logger = get_logger("Console");
	my $workloadNum    = $self->workload->instanceNum;

	my $rampUp           = $self->getParamValue('rampUp');
	my $warmUp           = $self->getParamValue('warmUp');
	my $steadyState = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $rampDown         = $self->getParamValue('rampDown');
	my $totalTime        = $rampUp + $warmUp + $steadyState + $rampDown;
	my $usersScaleFactor = $self->getParamValue('usersScaleFactor');
	my $usersPerAuctionScaleFactor =
	  $self->getParamValue('usersPerAuctionScaleFactor');
	my $rampupInterval = $self->getParamValue('rampupInterval');
	my $secondariesRef = $self->secondaries;

	my $workloadProfile  = $self->getParamValue('workloadProfile');
	my $behaviorSpecName = "auctionMainUser";
	if ($workloadProfile eq "official2") {
		$behaviorSpecName = "auctionMainUser2";
	}


	$logger->debug("createRunConfigHash");
	my $runRef = {};

	$runRef->{"name"} = "runW${workloadNum}";

	$runRef->{"statsHost"}          = $self->getStatsHost();
	$runRef->{"statsOutputDirName"} = "/tmp";

	$runRef->{"workloads"} = [];

	my $numAppInstances = $#{$appInstancesRef} + 1;
	foreach my $appInstance (@$appInstancesRef) {
		my $instanceNum = $appInstance->instanceNum;
		my $users       = $appInstance->getUsers();

		my $workload = {};
		$workload->{'name'}             = "appInstance" . $instanceNum;
		$workload->{"behaviorSpecName"} = $behaviorSpecName;
		$workload->{"maxUsers"}         = $appInstance->getMaxLoadedUsers();

		if ( $self->getParamValue('useThinkTime') ) {
			$workload->{"useThinkTime"} = JSON::true;
		}
		else {
			$workload->{"useThinkTime"} = JSON::false;
		}

		$workload->{"type"}             = "auction";
		$workload->{"usersScaleFactor"} = $usersScaleFactor;
		$workload->{"usersPerAuction"}  = $usersPerAuctionScaleFactor;
		$workload->{"pageSize"}         = 5;

		$logger->debug("createRunConfigHash configuring workload " . $workload->{'name'});
		

		# Add the loadPath to the workload
		my $loadPathType = $appInstance->getParamValue('loadPathType');
		my $loadPath     = {};
		$loadPath->{'name'}            = "loadPath" . $instanceNum;
		$loadPath->{"isStatsInterval"} = JSON::true;
		$loadPath->{"printSummary"}    = JSON::true;
		$loadPath->{"printIntervals"}  = JSON::false;
		$loadPath->{"printCsv"}        = JSON::true;

		if ( $loadPathType eq "fixed" ) {
			$logger->debug(
"configure for workload $workloadNum, appInstance $instanceNum has load path type fixed"
			);
			$loadPath->{"type"}        = 'fixed';
			$loadPath->{"rampUp"}      = $rampUp;
			$loadPath->{"warmUp"}      = $warmUp;
			$loadPath->{"numQosPeriods"} = $self->getParamValue('numQosPeriods');
			$loadPath->{"qosPeriodSec"} = $self->getParamValue('qosPeriodSec');
			$loadPath->{"exitOnFirstFailure"} = $self->getParamValue('exitOnFirstFailure');
			$loadPath->{"rampDown"}    = $rampDown;
			$loadPath->{"users"}       = $users;
			$loadPath->{"timeStep"}    = 15;
		}
		elsif ( $loadPathType eq "interval" ) {
			$logger->debug(
"configure for workload $workloadNum, appInstance $instanceNum has load path type interval"
			);
			$loadPath->{"type"}          = "interval";
			$loadPath->{"loadIntervals"} = [];
			if ( $appInstance->hasLoadPath() ) {
				$logger->debug(
"configure for workload $workloadNum, appInstance has load path"
				);
				$self->printLoadPath($appInstance->getLoadPath(),
					$loadPath->{"loadIntervals"}, $totalTime);
			}
			else {
				$logger->error(
"Workload $workloadNum, appInstance $instanceNum has an interval loadPathType but no userLoadPath."
				);
				exit -1;
			}

		}
		elsif ( $loadPathType eq "findmax" ) {
			$logger->debug(
"configure for workload $workloadNum, appInstance $instanceNum has load path type findmax"
			);
			$loadPath->{"type"}          = "findmax";
			$loadPath->{"maxUsers"} = $appInstance->getMaxLoadedUsers();
			$loadPath->{"minUsers"} = $self->getParamValue('minimumUsers');
			$loadPath->{"numQosPeriods"} = $self->getParamValue('numQosPeriods');
			$loadPath->{"qosPeriodSec"} = $self->getParamValue('qosPeriodSec');
		}
		elsif ( $loadPathType eq "ramptomax" ) {
			$logger->debug(
"configure for workload $workloadNum, appInstance $instanceNum has load path type ramptomax"
			);
			$loadPath->{"startUsers"} = $appInstance->getMaxLoadedUsers() / 10;
			$loadPath->{"maxUsers"}   = $appInstance->getMaxLoadedUsers();
			$loadPath->{"stepSize"}   = $appInstance->getMaxLoadedUsers() / 10;
			$loadPath->{"intervalDuration"}     = 600;
			$loadPath->{"rampIntervalDuration"} = 300;
		}

		$workload->{"loadPath"} = $loadPath;

		# Add periodic statsIntervalSpec
		my $statsIntervalSpecs = [];
		my $statsIntervalSpec  = {};
		$statsIntervalSpec->{'name'} = "periodic";
		$statsIntervalSpec->{'type'} = "periodic"; 
		$statsIntervalSpec->{"printSummary"} = JSON::false;
		$statsIntervalSpec->{"printIntervals"} = JSON::true;
		$statsIntervalSpec->{"printCsv"}       = JSON::true;
		$statsIntervalSpec->{"period"} = $self->getParamValue('statsInterval');
		push @$statsIntervalSpecs, $statsIntervalSpec;
		$workload->{"statsIntervalSpecs"} = $statsIntervalSpecs;
		$logger->debug("createRunConfigHash configuring statsIntervalSpec " . $statsIntervalSpec->{'name'});

		# There should be one target for each IP address
		# associated with the edge service for each appInstance
		my $edgeIpAddrsRef = $appInstance->getEdgeAddrsRef();
		my $numVIPs = $#{$edgeIpAddrsRef} + 1;
	    $logger->debug("createRunConfigHash appInstance $instanceNum has $numVIPs targets");

		$workload->{"targets"} = [];
		my @targetNames;
		my $uniquifier = 1;
		for ( my $vipNum = 0 ; $vipNum < $numVIPs ; $vipNum++ ) {
			my $target = {};

			my $serverName = $edgeIpAddrsRef->[$vipNum]->[0];
			my $httpPort   = $edgeIpAddrsRef->[$vipNum]->[1];
			my $httpsPort  = $edgeIpAddrsRef->[$vipNum]->[2];

			$target->{"type"}      = "http";
			$target->{"hostname"}  = "$serverName";
			$target->{"httpPort"}  = "$httpPort";
			$target->{"httpsPort"} = "$httpsPort";
			if ( $self->getParamValue('ssl') ) {
				$target->{"sslEnabled"} = JSON::true;
			}
			else {
				$target->{"sslEnabled"} = JSON::false;
			}

			my $targetName = $serverName;
			while ( $target ~~ @targetNames ) {
				$targetName = "$targetName-$uniquifier";
				$uniquifier++;
			}
			$target->{"name"} = $targetName;
			push @targetNames, $targetName;
		$logger->debug("createRunConfigHash adding target " . $targetName);

			push @{ $workload->{"targets"} }, $target;

		}
		
		push @{ $runRef->{"workloads"} }, $workload;
		
	}

	return $runRef;
}

override 'configure' => sub {
	my ( $self, $appInstancesRef, $suffix, $tmpDir ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $console_logger = get_logger("Console");
	my $workloadNum    = $self->workload->instanceNum;
	$logger->debug("configure for workload $workloadNum, suffix = $suffix");
	$self->suffix($suffix);
	$self->appInstances($appInstancesRef);

	my $workloadProfileHome = $self->getParamValue('workloadProfileDir');
	my $rampUp              = $self->getParamValue('rampUp');
	my $warmUp              = $self->getParamValue('warmUp');
	my $steadyState = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $rampDown            = $self->getParamValue('rampDown');
	my $totalTime           = $rampUp + $warmUp + $steadyState + $rampDown;
	my $usersScaleFactor    = $self->getParamValue('usersScaleFactor');
	my $rampupInterval      = $self->getParamValue('rampupInterval');

	$self->portMap->{'http'} = $self->internalPortMap->{'http'};
	
	# Customize the behaviorSpecs for this run
	my $sourceBehaviorSpecDirName = "$workloadProfileHome/behaviorSpecs";
	my $targetBehaviorSpecDirName =
	  "$tmpDir/configuration/workloadDriver/workload${workloadNum}";
	`mkdir -p $targetBehaviorSpecDirName`;
	my $rtPassingPct = $self->getParamValue('responseTimePassingPercentile');
	if ( ( $rtPassingPct < 0 ) || ( $rtPassingPct > 100 ) ) {
		$console_logger->error(
"The responseTimePassingPercentile for workload $workloadNum must be between 0.0 and 100.0"
		);
		exit -1;
	}
	if ( !$rtPassingPct ) {

		# The passingPct was not set, just use the default that is in the
		# behaviorSpec by copying the specs
`cp $sourceBehaviorSpecDirName/auction.mainUser.behavior.json $targetBehaviorSpecDirName/. `;
`cp $sourceBehaviorSpecDirName/auction.mainUser2.behavior.json $targetBehaviorSpecDirName/. `;
`cp $sourceBehaviorSpecDirName/auction.followAuction.behavior.json $targetBehaviorSpecDirName/.`;
`cp $sourceBehaviorSpecDirName/auction.followAuction2.behavior.json $targetBehaviorSpecDirName/.`;
	}
	else {
		my @behaviorSpecFiles = (
			'auction.mainUser.behavior.json',
			'auction.mainUser2.behavior.json',
			'auction.followAuction.behavior.json',
			'auction.followAuction2.behavior.json'
		);
		foreach my $behaviorSpec (@behaviorSpecFiles) {
			open( FILEIN, "$sourceBehaviorSpecDirName/$behaviorSpec" )
			  or die
			  "Can't open file $sourceBehaviorSpecDirName/$behaviorSpec: $!";
			open( FILEOUT, ">$targetBehaviorSpecDirName/$behaviorSpec" )
			  or die
			  "Can't open file $targetBehaviorSpecDirName/$behaviorSpec: $!";
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /responseTimeLimitsPercentile/ ) {
					my @defaults = split /,/, $inline;
					print FILEOUT
					  "\t\"responseTimeLimitsPercentile\" : [ $rtPassingPct, ";
					for ( my $i = 2 ; $i < $#defaults ; ++$i ) {
						print FILEOUT "$rtPassingPct, ";
					}
					print FILEOUT "$rtPassingPct],\n";
				}
				else {
					print FILEOUT $inline;
				}
			}
			close FILEIN;
			close FILEOUT;
		}
	}

	return 1;

};

override 'redeploy' => sub {
	my ( $self, $logfile, $hostsRef ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	# Update the docker image here
	$self->host->dockerPull( $logfile, "auctionworkloaddriver");
	my $secondariesRef = $self->secondaries;
	foreach my $server (@$secondariesRef) {
		$server->host->dockerPull( $logfile, "auctionworkloaddriver");	
	}

};

sub killOld {
	my ($self, $setupLogDir)           = @_;
	my $logger           = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum    = $self->workload->instanceNum;
	my $console_logger = get_logger("Console");

	my $logName = "$setupLogDir/killOld$workloadNum.log";
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

	# Now stop and remove all of the driver containers
	foreach my $driver (@$driversRef) {
		$self->stopAuctionWorkloadDriverContainer($logHandle, $driver);
	}

	close $logHandle;
}

sub clearResults {
	my ($self) = @_;

	# Clear out the results of parsing any previous run
	$self->resultsValid(0);
	$self->opsSec(       {} );
	$self->maxPassUsers(   {} );
	$self->reqSec(       {} );
	$self->passAll(      {} );
	$self->passRT(       {} );
	$self->passFailure( {} );
	$self->overallAvgRT( {} );
	$self->rtAvg(        {} );
	$self->pctPassRT(    {} );
	$self->successes(    {} );
	$self->failures(     {} );
	$self->rtFailures(     {} );
	$self->proportion(   {} );
}

sub followLogs {
	my ( $self, $logDir, $suffix, $logHandle) = @_;
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $pid              = fork();
		if ( $pid == 0 ) {
			my $hostname = $secondary->host->name;
			my $secondaryName  = $secondary->name;
			$secondary->host->dockerFollowLogs($logHandle, $secondaryName, "$logDir/run_$hostname$suffix.log" );
			exit;
		}
	}

	# start the primary
	my $pid = fork();
	if ( $pid == 0 ) {
		my $name        = $self->name;
		$self->host->dockerFollowLogs($logHandle, $name, "$logDir/run$suffix.log" );
		exit;
	}	
}

sub startDrivers {
	my ( $self, $logDir, $suffix, $logHandle) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum    = $self->workload->instanceNum;
	$logger->debug("Starting workload driver containers");

	# Start the driver on all of the secondaries
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $pid              = fork();
		if ( $pid == 0 ) {
			my $hostname = $secondary->host->name;
			$logger->debug("Starting secondary driver for workload $workloadNum on $hostname");
			$self->startAuctionWorkloadDriverContainer($secondary, $logHandle);
			exit;
		}
	}

	# start the primary
	$logger->debug("Starting primary driver for workload $workloadNum");
	$self->startAuctionWorkloadDriverContainer($self, $logHandle);

	$logger->debug("Sleeping for 30 sec to let primary driver start");
	sleep 30;	
}

sub startAuctionWorkloadDriverContainer {
	my ( $self, $driver, $applog ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum    = $driver->workload->instanceNum;
	my $name        = $driver->name;
		
	$driver->host->dockerStopAndRemove( $applog, $name );

	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $driverThreads                       = $driver->getParamValue('driverThreads');
	my $driverHttpThreads                   = $driver->getParamValue('driverHttpThreads');
	my $maxConnPerUser                      = $driver->getParamValue('driverMaxConnPerUser');

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
	my $port = $self->portMap->{'http'};
	$envVarMap{"PORT"} = $port;	
	$envVarMap{"JVMOPTS"} = "\"$driverJvmOpts\"";	
	$envVarMap{"WORKLOADNUM"} = $workloadNum;	
	
	# Start the  auctionworkloaddriver container
	my %volumeMap;
	my %portMap;
	$portMap{$port} = $port;
	
	my $directMap = 1;
	my $cmd        = "";
	my $entryPoint = "";
	my $dockerConfigHashRef = {};	
	$dockerConfigHashRef->{'net'} = "bridge";

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

sub stopDrivers {
	my ( $self, $logHandle) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("Stopping workload driver containers");

	# Now stop and remove all of the driver containers
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		$self->stopAuctionWorkloadDriverContainer($logHandle, $secondary);
	}
	$self->stopAuctionWorkloadDriverContainer($logHandle, $self);
}

sub stopAuctionWorkloadDriverContainer {
	my ( $self, $applog, $driver ) = @_;
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $name        = $driver->name;

	$driver->host->dockerStopAndRemove( $applog, $name );

}

sub initializeRun {
	my ( $self, $runNum, $logDir, $suffix, $tmpDir ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$self->suffix($suffix);
	my $port = $self->portMap->{'http'};
	my $workloadNum    = $self->workload->instanceNum;
	my $runName = "runW${workloadNum}";

	my $logName = "$logDir/InitializeRun$suffix.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

    $self->startDrivers($logDir, $suffix, $logHandle);

	# Now keep checking whether the workload controller is up
	my $isUp      = 1;
	my $retryCount = 0;
	do {
		$isUp = $self->isUp();
		$logger->debug( "For driver "
				  . $self->host->name
				  . " isUp returned $isUp" );
		$retryCount++;
		if ( !$isUp ) {
			sleep 30;
		}
	} while ( ( !$isUp ) && ( $retryCount < 20 ) );

	if ( !$isUp ) {
		$console_logger->warn(
"The workload controller for workload $workloadNum did not start within 10 minutes. Exiting"
		);
		return 0;
	} else {
		$logger->debug("The workload controller is up.");
	}

	# Start following the driver logs
    $self->followLogs($logDir, $suffix, $logHandle);

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");
	my $req;
	my $res;
	my $baseUrl = $self->getControllerURL() . "/run";

	# Send the hosts and port number to the controller
	my $runContent = $json->encode($self->getHosts());
	my $url = $baseUrl . "/hosts";
	$logger->debug("Sending POST to $url.  content = $runContent");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($runContent);
	$res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: " . $res->content );
	}
	else {
		$console_logger->warn("Could not send hosts message to workload controller. Exiting");
		return 0;
	}
	
	my %portHash;
	$portHash{"port"} = $self->getHostPort();
	$runContent = $json->encode(\%portHash);
	$url = $baseUrl . "/port";
	$logger->debug("Sending POST to $url.  content = $runContent");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($runContent);
	$res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  " . $res->content );
	}
	else {
		$console_logger->warn("Could not send port message to workload controller. Exiting");
		return 0;
	}

	# Now keep checking whether the workload drivers is up
    $isUp      = 1;
	$retryCount = 0;
	do {
		$isUp = $self->areDriversUp();
		$logger->debug( "For driver "
				  . $self->host->name
				  . " isUp returned $isUp" );
		$retryCount++;
		if ( !$isUp ) {
			sleep 30;
		}
	} while ( ( !$isUp ) && ( $retryCount < 20 ) );

	if ( !$isUp ) {
		$console_logger->warn(
"The workload driver nodes for workload $workloadNum did not start within 10 minutes. Exiting"
		);
		return 0;
	} else {
		$logger->debug("All workload drivers are up.");
	}

	# Now send the run configuration to the controller
	my $runRef =
	  $self->createRunConfigHash( $self->workload->appInstancesRef, $suffix );

	# Save the configuration in file form
	open( my $configFile, ">$tmpDir/run$suffix.json" )
	  || die "Can't open $tmpDir/run$suffix.json for writing: $!";
	print $configFile $json->encode($runRef) . "\n";
	close $configFile;

	$runContent = $json->encode($runRef);
	$url = $baseUrl . "/$runName";
	$logger->debug("Run content for workload $workloadNum:\n$runContent\n");
	$logger->debug("Sending POST to $url");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($runContent);

	$res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: " . $res->content );
	}
	else {
		$console_logger->warn("Could not send configuration message to workload controller. Exiting");
		$logger->debug( "Response unsucessful.  Content: " . $res->content );
		return 0;
	}

	# Send the behaviorSpecs to the controller
	my $behaviorSpecDirName =
	  "$tmpDir/configuration/workloadDriver/workload${workloadNum}";
	my @behaviorSpecFiles = (
		'auction.mainUser.behavior.json',
		'auction.mainUser2.behavior.json',
		'auction.followAuction.behavior.json',
		'auction.followAuction2.behavior.json'
	);
	foreach my $behaviorSpec (@behaviorSpecFiles) {
      # Read the file
	  open( FILE, "$behaviorSpecDirName/$behaviorSpec" )
		  or die "Couldn't open $behaviorSpecDirName/$behaviorSpec: $!";
	  my $contents = "";
	  while ( my $inline = <FILE> ) {
	    $contents .= $inline;
	  }
      close FILE;

	  $url      = $baseUrl . "/behaviorSpec";
	  $logger->debug("Sending POST to $url with contents:\n$contents");
	  $req = HTTP::Request->new( POST => $url );
	  $req->content_type('application/json');
	  $req->header( Accept => "application/json" );
	  $req->content($contents);

	  $res = $ua->request($req);
	  $logger->debug( "Response status line: " . $res->status_line . " for url " . $url );
	  if ( $res->is_success ) {
	  	$logger->debug("Response sucessful.  Content: " . $res->content );
	  }	else {
		$console_logger->warn("Could not send behaviorSpec message to workload controller. Exiting");
		return 0;
	  }
	}

	# Now send the initialize message to the runService
	$url      = $baseUrl . "/$runName/initialize";
	$logger->debug("Sending POST to $url");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($runContent);
	$res = $ua->request($req);
	$logger->debug("Response status line: " . $res->status_line . " for url " . $url );

	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: " . $res->content );
	} else {
		$console_logger->warn("Could not send initialize message to workload controller. Exiting");
		return 0;
	}

	close $logHandle;
	return 1;
}

sub startRun {
	my ( $self, $runNum, $logDir, $suffix, $tmpDir ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	  
	my $driverJvmOpts           = $self->getParamValue('driverJvmOpts');
	my $workloadNum             = $self->workload->instanceNum;
	my $runName                 = "runW${workloadNum}";
	my $rampUp              = $self->getParamValue('rampUp');
	my $warmup              = $self->getParamValue('warmUp');
	my $steadyState = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $rampDown            = $self->getParamValue('rampDown');
	my $totalTime           = $rampUp + $warmUp + $steadyState + $rampDown;

	my $logName = "$logDir/StartRun$suffix.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");

	# Now send the start message to the runService
	my $req;
	my $res;
	my $runContent = "{}";
	my $pid1       = fork();
	if ( $pid1 == 0 ) {
		my $url      = $self->getControllerURL() . "/run/$runName/start";
		$logger->debug("Sending POST to $url");
		$req = HTTP::Request->new( POST => $url );
		$req->content_type('application/json');
		$req->header( Accept => "application/json" );
		$req->content($runContent);

		$res = $ua->request($req);
		$logger->debug(
			"Response status line: " . $res->status_line . " for url " . $url );
		if ( $res->is_success ) {
			$logger->debug( "Response sucessful.  Content: " . $res->content );
		}
		else {
			$console_logger->warn("Could not send start message to workload controller. Exiting");
			return 0;
		}
		exit;
	}

	# Let the appInstances know that the workload is running.
	callMethodOnObjectsParallel( 'workloadRunning',
		$self->workload->appInstancesRef );

# Now send the stats/start message the primary driver which is also the statsService host
	my $statsStartedMsg = {};
	$statsStartedMsg->{'timestamp'} = time;
	my $statsStartedContent = $json->encode($statsStartedMsg);

	my $url      = $self->getControllerURL() . "/stats/started/$runName";
	$logger->debug("Sending POST to $url");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($statsStartedContent);

	$res = $ua->request($req);
	$logger->debug(
		"Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$logger->debug( "Response sucessful.  Content: " . $res->content );
	}
	else {
		$console_logger->warn("Could not send stats/started message to workload controller. Exiting");
		return 0;
	}

	my $usingFindMaxLoadPathType = 0;
	my $usingFixedLoadPathType = 0;
	my $appInstancesRef = $self->workload->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $loadPathType = $appInstance->getParamValue('loadPathType');
		if ( $loadPathType eq "findmax" ) {
			$usingFindMaxLoadPathType = 1;
			last;
		}
		if ($loadPathType eq "fixed" ) {
			$usingFixedLoadPathType = 1;
			last;
		}
	}

	# Start a process to echo the log to the screen and start/stop the stats collection
	my $pid = fork();
	if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
	} elsif ( $pid == 0 ) {

		# open a pipe to follow progress
		my $pipeString = "tail -f $logDir/run$suffix.log |";
		$logger->debug("Command to follow workload progress: $pipeString");
		my $pipePid = open my $driverPipe, "$pipeString"
		  or die "Can't fork to follow driver at $logDir/run$suffix.log : $!";

		my $periodicOutputId   = "";
		if ( $suffix ne "" ) {
			$periodicOutputId = "W${workloadNum} ";
		}
		my $nextIsHeader = 0;
		my $startTime    = time();
		my $startedSteadyState = 0;
		my $startedRampDown = 0;
		my $inline;
		while ( $driverPipe->opened() &&  ($inline = <$driverPipe>) ) {
			if ($self->getParamValue('showPeriodicOutput')
			        && (( $inline =~ /^\|\s+\d+\|/ ) 
					|| ( $inline =~ /^\|\s+Time\|/ ) 
					|| ( $inline =~ /^\|\s+\(sec\)\|/ ))) {
			    if ($inline =~ /^(.*|)GetNextBid\:.*/) {
					$inline = $1 . "\n";
			    }
			    if ($inline =~ /^(.*|)Per\sOperation\:.*/) {
					$inline = $1 . "\n";
			    }
				print $periodicOutputId . $inline;
			}
		
			# The next line after ----- should be first header
			if ( $inline =~ /^-------------------/ ) {
				$nextIsHeader = 1;
				next;
			}

			if ($nextIsHeader) {
				if (!(($inline =~ /^\|\s*Time/ ) || ($inline =~ /^\d\d\:\d\d\:\d\d/))) {
					$console_logger->warn(
			"Workload driver did not start properly. Check run.log for errors. "
					);
					return 0;
				}
				else {
					$nextIsHeader = 0;
					my $runLengthMinutes = sprintf("%.0f", $totalTime / 60.0);
					my $impl             = $self->getParamValue('workloadImpl');

					if ($usingFixedLoadPathType) {
						$console_logger->info(
							"Running Workload $workloadNum: $impl.  Run will finish in approximately $runLengthMinutes minutes."
						);
						$logger->debug("Workload will ramp up for $rampUp. suffix = $suffix");
					}
				}
			}
		}
		kill(9, $pipePid);
		close $driverPipe;			
		exit;
	}

	# Now poll for a runState of COMPLETE 
	# once every minute
	my $runCompleted = 0;
	my $endRunStatus = "";
	my $endRunStatusRaw = "";
	$url = $self->getControllerURL() . "/run/$runName/state";
	my @curIntervalNames;
	my @lastIntervalNames;
	my @statsRunning;

	sleep 30; #initial sleep before getting state
	while (!$runCompleted) {
		$logger->debug("Sending get to $url");
		$req = HTTP::Request->new( GET => $url );
		$res = $ua->request($req);
		$logger->debug(
			"Response status line: " . $res->status_line . " for url " . $url );
		if ( $res->is_success ) {
			$endRunStatus = $json->decode( $res->content );

			my $workloadStati = $endRunStatus->{'workloadStati'};
			foreach my $workloadStatus (@$workloadStati) {
				my $wkldName = $workloadStatus->{'name'};
				my $curInterval = $workloadStatus->{'curInterval'};
				my $curIntervalName;
				if ($curInterval) {
					$curIntervalName = $curInterval->{'name'};
					$logger->debug("$wkldName: curInterval = $curIntervalName");
				}
				
				if ($usingFindMaxLoadPathType || $usingFixedLoadPathType) {
					$wkldName =~ /appInstance(\d+)/;
					my $appInstanceNum = $1;

					if (defined $statsRunning[$appInstanceNum] && $statsRunning[$appInstanceNum]) {
						$statsRunning[$appInstanceNum] = 0;
						$logger->debug("   [$wkldName] Stopping performance statistics on workload.");
						$self->workload->stopStatsCollection($tmpDir);
					}

					my $statsSummaries = $workloadStatus->{"intervalStatsSummaries"};
					my $lastIndexStatsSummaries = $#$statsSummaries;
					if ($lastIndexStatsSummaries >= 0) {
						my $statsSummary = $statsSummaries->[$lastIndexStatsSummaries];
						if (!(defined $lastIntervalNames[$appInstanceNum]) ||  !($statsSummary->{"intervalName"} eq $lastIntervalNames[$appInstanceNum])) {
							my $endIntervalName = $statsSummary->{"intervalName"};
							$lastIntervalNames[$appInstanceNum] = $endIntervalName;
							my $nameStr = $self->parseNameStr($endIntervalName);
							if ($endIntervalName =~ /InitialRamp\-(\d+)/) {
								# Don't print end message for InitialRamp intervals
								next;
							}
							my $tptStr = sprintf("%.2f", $statsSummary->{"throughput"});
							my $rtStr = sprintf("%.2f", $statsSummary->{"avgRT"});
							my $successStr;
							if ($statsSummary->{"intervalPassed"}) {
								$successStr = 'passed';
							} else {
								$successStr = 'failed: ';
								if (!$statsSummary->{"intervalPassedRT"}) {
									$successStr .= 'RT,';
								}
								if (!$statsSummary->{"intervalPassedMix"}) {
									$successStr .= 'Mix,';
								}
								if (!$statsSummary->{"intervalPassedFailure"}) {
									$successStr .= 'FailurePct,';
								}
								chop($successStr);
							}
							my $metricsStr = ", $successStr, throughput:$tptStr, avgRT:$rtStr";
							$console_logger->info("   [$wkldName] Ended: $nameStr${metricsStr}.");
						}
					}

					if ($curInterval && (!(defined $curIntervalNames[$appInstanceNum]) ||  !($curIntervalName eq $curIntervalNames[$appInstanceNum]))) {
						$curIntervalNames[$appInstanceNum] = $curIntervalName;
						my $nameStr = $self->parseNameStr($curIntervalName);
						$console_logger->info("   [$wkldName] Start: $nameStr, duration:" . $curInterval->{'duration'} . "s.");

						if ( ($curIntervalName =~ /VERIFYMAX\-(\d+)\-ITERATION\-(\d+)/)
								|| ($curIntervalName =~ /QOS\-(\d+)/)) {
							$statsRunning[$appInstanceNum] = 1;
							$logger->debug("   [$wkldName] Starting performance statistics on workload.");
							$self->workload->startStatsCollection($tmpDir);
						}
					}
				}
			}
			if ( $endRunStatus->{"state"} eq "COMPLETED") {
				$endRunStatusRaw = $res->content;
				$runCompleted = 1;
				last;
			}
		}
		sleep 60;
	}
	$console_logger->info("Run is complete");
	kill(9, $pid);
	
	my $destinationPath = $logDir . "/statistics/workloadDriver";
	if ( !( -e $destinationPath ) ) {
		my ($cmdFailed, $cmdOutput) = runCmd("mkdir -p $destinationPath");
		if ($cmdFailed) {
			die "AuctionWorkloadDriver startRun destinationPath mkdir failed: $cmdFailed";
		}
	}
	
	# Write the endRun status
	open( FILE, ">$destinationPath/FinalRunState.json" )
		 or die "Couldn't open $destinationPath/FinalRunState.json: $!";
	print FILE $endRunStatusRaw;
	close FILE;
	

	# Now send the stats/complete message the primary driver which is also the statsService host
	my $statsCompleteMsg = {};
	$statsCompleteMsg->{'timestamp'} = time;
	my $statsCompleteContent = $json->encode($statsCompleteMsg);
	$url      = $self->getControllerURL() . "/stats/complete/$runName";
	$logger->debug("Sending POST to $url");
	$req = HTTP::Request->new( POST => $url );
	$req->content_type('application/json');
	$req->header( Accept => "application/json" );
	$req->content($statsCompleteContent);

	$res = $ua->request($req);
	$logger->debug( "Response status line: "
		  . $res->status_line
		  . " for url "
		  . $url );
	if ( $res->is_success ) {
		$logger->debug("Response sucessful.  Content: " . $res->content );
	}	
	else {
		$console_logger->warn("Could not send stats/complete message to workload controller. Exiting");
		return 0;
	}
	close $logHandle;

	my $impl = $self->getParamValue('workloadImpl');
	$console_logger->info("Workload $workloadNum: $impl finished");

	return 1;
}

sub parseNameStr {
	my ( $self, $str ) = @_;
	my $nameStr;
	if ($str =~ /InitialRamp\-(\d+)/) {
		$nameStr = "initial ramp at $1 users";
	} elsif ($str =~ /FINDFIRSTMAX\-Warmup\-(\d+)/) {
		$nameStr = "finding maximum warmup at $1 users";
	} elsif ($str =~ /FINDFIRSTMAX\-RampTo\-(\d+)/) {
		$nameStr = "finding maximum ramp to $1 users";
	} elsif ($str =~ /FINDFIRSTMAX\-(\d+)/) {
		$nameStr = "finding maximum run at $1 users";
	} elsif ($str =~ /VERIFYMAX\-RampTo\-(\d+)/) {
		$nameStr = "verify maximum ramp to $1 users";
	} elsif ($str =~ /VERIFYMAX\-Warmup\-(\d+)/) {
		$nameStr = "verify maximum warmup at $1 users";
	} elsif ($str =~ /VERIFYMAX\-(\d+)\-ITERATION\-(\d+)/) {
		my $numRerun = $2 + 1;
		$nameStr = "verify maximum run at $1 users rerun $numRerun";
	} elsif ($str =~ /QOS\-(\d+)/) {
		$nameStr = "QoS period $1";
	} else {
		$nameStr = $str;
	}
	return $nameStr;
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

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");
	
	
	# Now send the shutdown message
	my $url      = $self->getControllerURL() . "/run/$runName/shutdown";
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
				
	$self->stopDrivers($logHandle);

	close $logHandle;
	return 1;
}

sub isUp {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my $json     = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");

	my $controllerUrl = $self->getControllerURL();
	my $url = "$controllerUrl/run/up";
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

sub areDriversUp {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->workload->instanceNum;
	my $runName     = "runW${workloadNum}";

	my $json     = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/0.95 ");

	my $controllerUrl = $self->getControllerURL();
	my $url = "$controllerUrl/run/driversUp";
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

	my $url = $self->getControllerURL() . "/run/$runName/start";
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

sub stopAppStatsCollection {
	my ($self) = @_;
	my $hostname = $self->host->name;

	# Collection of app stats is currently disabled
	return;

	my $pid = fork();
	if ( $pid != 0 ) {
		return;
	}

	open( LOG, ">/tmp/queryStats.txt" )
	  || die "Error opening /tmp/queryStats.txt:$!";
	my (
		$avgBidCompletionDelay,   $stddevBidCompletionDelay,
		$avgItemDuration,         $avgCompletionsPerBid,
		$stddevCompletionsPerBid, $numTimeoffsetsDeleted
	);

	my $rampUp      = $self->getParamValue('rampUp');
	my $steadyState = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $db          = $self->getParamValue('dbServer');

	# Get the name of the first dbServer
	my $servicesByTypeRef = $self->servicesByTypeRef;
	my $dbServicesRef     = $servicesByTypeRef->{"dbServer"};
	my $dbServer          = $dbServicesRef->[0];
	my $dbHostname        = $dbServer->host->name;

	my $appStartDate    = "2030-02-02";
	my $appStartHour    = 12;
	my $appStartMinute  = 0;
	my $appStartSeconds = 0;

	my $rampupHours = floor( $rampUp / ( 60 * 60 ) );
	my $rampupMinutes = floor( ( $rampUp - ( $rampupHours * 60 * 60 ) ) / 60 );
	my $rampupSeconds =
	  $rampUp - ( $rampupHours * 60 * 60 ) - ( $rampupMinutes * 60 );

	my $steadyStateHours = floor( $steadyState / ( 60 * 60 ) );
	my $steadyStateMinutes =
	  floor( ( $steadyState - ( $steadyStateHours * 60 * 60 ) ) / 60 );
	my $steadyStateSeconds =
	  $steadyState -
	  ( $steadyStateHours * 60 * 60 ) -
	  ( $steadyStateMinutes * 60 );

	my $startHours   = $appStartHour + $rampupHours;
	my $startMinutes = $appStartMinute + $rampupMinutes;
	my $startSeconds = $appStartSeconds + $rampupSeconds;
	if ( $startSeconds >= 60 ) {
		$startMinutes += $startSeconds / 60;
		$startSeconds %= 60;
	}
	if ( $startMinutes >= 60 ) {
		$startHours += $startMinutes / 60;
		$startMinutes %= 60;
	}

	my $endHours   = $startHours + $steadyStateHours;
	my $endMinutes = $startMinutes + $steadyStateMinutes;
	my $endSeconds = $startSeconds + $steadyStateSeconds;
	if ( $endSeconds >= 60 ) {
		$endMinutes += $endSeconds / 60;
		$endSeconds %= 60;
	}
	if ( $endMinutes >= 60 ) {
		$endHours += $endMinutes / 60;
		$endMinutes %= 60;
	}

	my $steadyStateStartTimestamp = sprintf "%sT%2d:%02d:%02d", $appStartDate,
	  $startHours, $startMinutes,
	  $startSeconds;
	my $steadyStateEndTimestamp = sprintf "%sT%2d:%02d:%02d", $appStartDate,
	  $endHours, $endMinutes, $endSeconds;

	print LOG
"In queryAppStats with startTime = $steadyStateStartTimestamp and endTime = $steadyStateEndTimestamp\n";

	my $connectString;
	if ( $db eq "postgresql" ) {
		$connectString = "psql -U auction -h $dbHostname -d auction -t -w -c";

		$avgBidCompletionDelay =
`PGPASSWORD=auction $connectString \"SELECT AVG(delay)/1000 FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND  timestamp < '$steadyStateEndTimestamp' ;\"`;
		$avgBidCompletionDelay =~ /(\d+\.?\d*)/;
		$avgBidCompletionDelay = $1;
		print LOG "avgBidCompletionDelay = $avgBidCompletionDelay\n";

		$stddevBidCompletionDelay =
`PGPASSWORD=auction $connectString \"SELECT STDDEV(delay)/1000 FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND  timestamp < '$steadyStateEndTimestamp' ;\"`;
		$stddevBidCompletionDelay =~ /(\d+\.?\d*)/;
		$stddevBidCompletionDelay = $1;
		print LOG "stddevBidCompletionDelay = $stddevBidCompletionDelay\n";

		$avgItemDuration =
`PGPASSWORD=auction $connectString \"SELECT avg(biddingEndTime - biddingStartTime) FROM highbid WHERE biddingEndTime IS NOT NULL AND biddingStartTime IS NOT NULL AND  '$steadyStateStartTimestamp'<  biddingEndTime AND biddingStartTime <  '$steadyStateEndTimestamp';\"`;
		if ( $avgItemDuration =~ /(\d\d):(\d\d):(\d\d)\.\d*/ ) {
			$avgItemDuration = ( $1 * 60 * 60 ) + ( $2 * 60 ) + $3;
		}
		else {
			$avgItemDuration = 0;
		}
		print LOG "avgItemDuration = $avgItemDuration\n";

		$avgCompletionsPerBid =
`PGPASSWORD=auction $connectString \"SELECT AVG(numCompletedBids) FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND timestamp < '$steadyStateEndTimestamp' ;\"`;
		$avgCompletionsPerBid =~ /(\d+\.?\d*)/;
		$avgCompletionsPerBid = $1;
		print LOG "avgCompletionsPerBid = $avgCompletionsPerBid\n";

		$stddevCompletionsPerBid =
`PGPASSWORD=auction $connectString \"SELECT STDDEV(numCompletedBids) FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND timestamp < '$steadyStateEndTimestamp' ;\"`;
		$stddevCompletionsPerBid =~ /(\d+\.?\d*)/;
		$stddevCompletionsPerBid = $1;
		print LOG "stddevCompletionsPerBid = $stddevCompletionsPerBid\n";

		$numTimeoffsetsDeleted =
		  `PGPASSWORD=auction $connectString \"DELETE FROM fixedtimeoffset;\"`;
		print LOG "numTimeoffsetsDeleted = $numTimeoffsetsDeleted\n";

	}
	close LOG;
	exit;
}

sub startAppStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

}

sub getAppStatsFiles {
	my ( $self, $destinationPath ) = @_;

	#`cp /tmp/queryStats.txt $destinationPath/.`;
}

sub cleanAppStatsFiles {
	my ($self) = @_;
}

sub stopStatsCollection {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("stopStatsCollection");

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $workloadNum = $self->workload->instanceNum;
# ToDo: Add a script to the docker image to do this:
#	my $hostname = $self->host->name;
#	`cp /tmp/gc-W${workloadNum}.log /tmp/gc-W${workloadNum}_rampup.log 2>&1`;
#
#	my $secondariesRef = $self->secondaries;
#	foreach my $secondary (@$secondariesRef) {
#		my $secHostname = $secondary->host->name;
#`ssh  -o 'StrictHostKeyChecking no'  root\@$secHostname cp /tmp/gc-W${workloadNum}.log /tmp/gc-W${workloadNum}_rampup.log 2>&1`;
#	}

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

sub cleanStatsFiles {
	my ( $self, $destinationPath ) = @_;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->name;

}

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
}

sub getResultMetrics {
	my ($self) = @_;
	tie( my %metrics, 'Tie::IxHash' );

	$metrics{"opsSec"}         = $self->opsSec;
	$metrics{"overallAvgRTRT"} = $self->overallAvgRT;

	return \%metrics;
}

sub getWorkloadStatsSummary {
	my ( $self, $csvRef, $tmpDir ) = @_;

	if (!$self->parseStats($tmpDir)) {
		return;	
	}

	my $totalUsers       = 0;
	my $opsSec       = 0;
	my $httpReqSec   = 0;
	my $overallAvgRT = 0;

	my $appInstancesRef = $self->workload->appInstancesRef;
	foreach my $appInstanceRef (@$appInstancesRef) {
		my $appInstanceNum = $appInstanceRef->instanceNum;
		$totalUsers       += $self->maxPassUsers->{$appInstanceNum};
		$opsSec       += $self->opsSec->{$appInstanceNum};
		$httpReqSec   += $self->reqSec->{$appInstanceNum};
		$overallAvgRT += $self->overallAvgRT->{$appInstanceNum};
	}
	
	my $numAppInstances = $#{$appInstancesRef} + 1;
	$overallAvgRT /= $numAppInstances;

	$csvRef->{"users-total"}       = $totalUsers;
	$csvRef->{"opsSec-total"}       = $opsSec;
	$csvRef->{"httpReqSec-total"}   = $httpReqSec;
	$csvRef->{"overallAvgRT-total"} = $overallAvgRT;

	$appInstancesRef = $self->workload->appInstancesRef;
	foreach my $appInstanceRef (@$appInstancesRef) {
		my $appInstanceNum = $appInstanceRef->instanceNum;
		my $prefix = "-AI${appInstanceNum}";

		my $isPassed = $self->isPassed( $appInstanceRef, $tmpDir );
		if ($isPassed) {
			$csvRef->{"pass$prefix"} = "Y";
		}
		else {
			$csvRef->{"pass$prefix"} = "N";
		}
		$csvRef->{"users$prefix"}       = $self->maxPassUsers->{$appInstanceNum};
		$csvRef->{"opsSec$prefix"}       = $self->opsSec->{$appInstanceNum};
		$csvRef->{"httpReqSec$prefix"}   = $self->reqSec->{$appInstanceNum};
		$csvRef->{"overallAvgRT$prefix"} = $self->overallAvgRT->{$appInstanceNum};
	}	
}

sub getWorkloadSummary {
	my ( $self, $csvRef, $logDir ) = @_;

	$csvRef->{"RampUp"}      = $self->getParamValue('rampUp');
	$csvRef->{"WarmUp"}      = $self->getParamValue('warmUp');
	$csvRef->{"numQosPeriods"} = $self->getParamValue('numQosPeriods');
	$csvRef->{"qosPeriodSec"} = $self->getParamValue('qosPeriodSec');
	$csvRef->{"RampDown"}    = $self->getParamValue('rampDown');

}

sub getHostStatsSummary {
	my ( $self, $csvRef, $baseDestinationPath, $filePrefix ) = @_;
	my $logger = get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	
}

sub getWorkloadAppStatsSummary {
	my ( $self, $tmpDir ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	tie( my %csv, 'Tie::IxHash' );

	if (!$self->parseStats($tmpDir)) {
		return \%csv;	
	}

	my $appInstancesRef = $self->workload->appInstancesRef;
	my $numAppInstances = $#$appInstancesRef + 1;
	my $passAll         = 1;
	my $opsSec          = 0;
	my $httpReqSec      = 0;
	my $overallAvgRT    = 0;

	my @operations = @{ $self->operations };
	$logger->debug(
"getWorkloadAppStatsSummary numAppInstances = $numAppInstances, operations: "
		  . join( ", ", @operations ) );

	for (
		my $appInstanceNum = 1 ;
		$appInstanceNum <= $numAppInstances ;
		$appInstanceNum++
	  )
	{
		$logger->debug(
			"getWorkloadAppStatsSummary printing stats for appInstance "
			  . $appInstanceNum );
		my $aiSuffix = "";
		if ( $numAppInstances > 1 ) {
			$aiSuffix = "I" . $appInstanceNum . "-";
		}

		foreach my $op (@operations) {
			if (   ( !exists $self->rtAvg->{"$op-$appInstanceNum"} )
				|| ( !defined $self->rtAvg->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_rtAvg"} =  $self->rtAvg->{"$op-$appInstanceNum"};

		}
		foreach my $op (@operations) {
			if (   ( !exists $self->pctPassRT->{"$op-$appInstanceNum"} )
				|| ( !defined $self->pctPassRT->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_pctPassRT"} =
			  $self->pctPassRT->{"$op-$appInstanceNum"};
		}

		foreach my $op (@operations) {
			if (   ( !exists $self->successes->{"$op-$appInstanceNum"} )
				|| ( !defined $self->successes->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_successes"} =
			  $self->successes->{"$op-$appInstanceNum"};
		}
		foreach my $op (@operations) {
			if (   ( !exists $self->rtFailures->{"$op-$appInstanceNum"} )
				|| ( !defined $self->rtFailures->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_RtFailures"} =
			  $self->rtFailures->{"$op-$appInstanceNum"};

		}
		foreach my $op (@operations) {
			if (   ( !exists $self->failures->{"$op-$appInstanceNum"} )
				|| ( !defined $self->failures->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_Failures"} =
			  $self->failures->{"$op-$appInstanceNum"};

		}
		foreach my $op (@operations) {
			if (   ( !exists $self->proportion->{"$op-$appInstanceNum"} )
				|| ( !defined $self->proportion->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_Proportion"} =
			  $self->proportion->{"$op-$appInstanceNum"};
		}
	}

	#	open( LOG, "$statsLogPath/queryStats.txt" )
	#	  || die "Error opening $statsLogPath/queryStats.txt:$!";
	#
	#	while ( my $inline = <LOG> ) {
	#		if ( $inline =~ /^(\S*)\s*=\s*(\S*)$/ ) {
	#			$csv{$1} = $2;
	#		}
	#	}
	#	close LOG;

	return \%csv;
}

sub getStatsSummary {
	my ( $self, $csvRef, $statsLogPath, $tmpDir ) = @_;

	if (!$self->parseStats($tmpDir)) {
		return;	
	}

	my $gcviewerDir     = $self->getParamValue('gcviewerDir');

	# Only parseGc if gcviewer is present
	if ( -f "$gcviewerDir/gcviewer-1.34-SNAPSHOT.jar" ) {
		my $workloadNum = $self->workload->instanceNum;
		open( HOSTCSVFILE,
">>$statsLogPath/workload${workloadNum}_workloadDriver_gc_summary.csv"
		  )
		  or die
"Can't open $statsLogPath/workload${workloadNum}_workloadDriver_gc_summary.csv: $!\n";

		tie( my %accumulatedCsv, 'Tie::IxHash' );

		my $hostname = $self->host->name;
		my $logPath  = $statsLogPath . "/" . $hostname;
		`mkdir -p $logPath`;
		my $csvHashRef =
		  ParseGC::parseGCLog( $logPath, "-W${workloadNum}", $gcviewerDir );
		print HOSTCSVFILE "Hostname";
		foreach my $key ( keys %$csvHashRef ) {
			print HOSTCSVFILE ", $key";
		}
		print HOSTCSVFILE "\n";
		print HOSTCSVFILE $hostname;
		foreach my $key ( keys %$csvHashRef ) {
			print HOSTCSVFILE ", " . $csvHashRef->{$key};
			if ( $csvHashRef->{$key} eq "na" ) {
				next;
			}
			if ( !( exists $accumulatedCsv{"workloadDriver_$key"} ) ) {
				$accumulatedCsv{"workloadDriver_$key"} = $csvHashRef->{$key};
			}
			else {
				$accumulatedCsv{"workloadDriver_$key"} += $csvHashRef->{$key};
			}
		}
		print HOSTCSVFILE "\n";

		my $secondariesRef = $self->secondaries;
		my $numServices    = $#{$secondariesRef} + 2;
		foreach my $secondary (@$secondariesRef) {
			my $secHostname = $secondary->host->name;
			my $logPath     = $statsLogPath . "/" . $secHostname;
			`mkdir -p $logPath`;
			$csvHashRef =
			  ParseGC::parseGCLog( $logPath, "-W${workloadNum}", $gcviewerDir );
			print HOSTCSVFILE $secHostname;

			foreach my $key ( keys %$csvHashRef ) {
				print HOSTCSVFILE ", " . $csvHashRef->{$key};
				if ( $csvHashRef->{$key} eq "na" ) {
					next;
				}
				if ( !( exists $accumulatedCsv{"workloadDriver_$key"} ) ) {
					$accumulatedCsv{"workloadDriver_$key"} =
					  $csvHashRef->{$key};
				}
				else {
					$accumulatedCsv{"workloadDriver_$key"} +=
					  $csvHashRef->{$key};
				}
			}
			print HOSTCSVFILE "\n";

		}

		# Now turn the total into averages
		foreach my $key ( keys %$csvHashRef ) {
			if ( exists $accumulatedCsv{"workloadDriver_$key"} ) {
				$accumulatedCsv{"workloadDriver_$key"} /= $numServices;
			}
		}

		# Now add the key/value pairs to the returned csv
		foreach my $key ( keys %accumulatedCsv ) {
			$csvRef->{$key} = $accumulatedCsv{$key};
		}

		close HOSTCSVFILE;
	}
}

sub getWorkloadDriverHosts {
	my ($self) = @_;

	my @hosts;
	my $secondariesRef = $self->secondaries;

	push @hosts, $self->host;
	foreach my $secondary (@$secondariesRef) {
		push @hosts, $secondary->host;
	}

	return \@hosts;
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

	my $url = $self->getControllerURL() . "/run/$runName/users";
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

		$url = $self->getControllerURL() . "/run/$runName/users";
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
		  $self->getControllerURL() . "/run/$runName/workload/$appInstanceName/users";
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

sub isPassed {
	my ( $self, $appInstanceRef, $tmpDir ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	if (!$self->parseStats($tmpDir)) {
		return;	
	}

	my $appInstanceNum = $appInstanceRef->instanceNum;

	my $usedLoadPath = 0;
	my $userLoadPath = $appInstanceRef->getLoadPath();
	if ( $#$userLoadPath >= 0 ) {
		$logger->debug( "AppInstance "
			  . $appInstanceNum
			  . " uses a user load path so not using proportions." );
		$usedLoadPath = 1;
	}

	if ($usedLoadPath) {

		# Using a load path in steady state, so ignore proportions
		return $self->passRT->{$appInstanceNum} && $self->passFailure->{$appInstanceNum};
	}
	return $self->passAll->{$appInstanceNum};
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
		$self->rtFailures->{ $operations[$opCounter] }   = 0;
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
	my $url = $self->getControllerURL() . "/run/$runName/state";
	$logger->debug("Sending get to $url");
	my $req = HTTP::Request->new( GET => $url );
	my $res = $ua->request($req);
	my $runStatus;
	$logger->debug("Response status line: " . $res->status_line . " for url " . $url );
	if ( $res->is_success ) {
		$logger->debug("Final status content: " . $res->content);
		$runStatus = $json->decode( $res->content );			
	} else {
		$console_logger->warn("Could not retrieve final run state for workload $workloadNum");
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
			$console_logger->warn("Could not find the max passing interval for appInstance " . $appInstanceName);
			next;
		}
		
		$self->maxPassUsers->{$appInstanceNum} = $maxPassUsers;
		$self->passAll->{$appInstanceNum} = $maxPassStatsSummary->{"intervalPassed"};
		$self->passRT->{$appInstanceNum} = $maxPassStatsSummary->{"intervalPassedRT"};
		$self->passFailure->{$appInstanceNum} = $maxPassStatsSummary->{"intervalPassedFailure"};
		$self->overallAvgRT->{$appInstanceNum} = $maxPassStatsSummary->{"avgRT"};
		$self->opsSec->{$appInstanceNum} = $maxPassStatsSummary->{"throughput"};
		$self->reqSec->{$appInstanceNum} = $maxPassStatsSummary->{"stepsThroughput"};
		
		# Get the statsSummary for the max passing interval
		my $loadPathName = $workloadStatus->{"loadPathName"};
		$url = $self->getControllerURL() . "/stats/run/$runName/workload/$appInstanceName/specName/$loadPathName/intervalName/$maxPassIntervalName/rollup";
		$logger->debug("Sending get to $url");
		$req = HTTP::Request->new( GET => $url );
		$res = $ua->request($req);
		my $statsSummaryRollup;
		$logger->debug("Response status line: " . $res->status_line . " for url " . $url );
		if ( $res->is_success ) {
			$logger->debug("MaxPassInterval statsSummary: " . $res->content);
			$statsSummaryRollup = $json->decode( $res->content )->{'statsSummaryRollup'};			
		} else {
			$console_logger->warn("Could not retrieve max passing interval summary for workload $workloadNum");
			return 0;
		}
		
		my $opNameToStatsMap = $statsSummaryRollup->{'computedOpStatsSummaries'};
		foreach my $operation (keys %$opNameToStatsMap) {
			my $opStats = $opNameToStatsMap->{$operation};
			my $opPassRT  = $opStats->{'passedRt'};
			my $opPassMix = $opStats->{'passedMixPct'};
			my $opPassFailure = $opStats->{'passedFailurePct'};
			$self->rtAvg->{"$operation-$appInstanceNum"} = $opStats->{'avgRt'};
			$self->proportion->{"$operation-$appInstanceNum"} = $opStats->{'mixPct'};
			$self->pctPassRT->{"$operation-$appInstanceNum"} = $opStats->{'passingPct'};
			$self->successes->{"$operation-$appInstanceNum"} = $opStats->{'successes'};
			$self->rtFailures->{"$operation-$appInstanceNum"} = $opStats->{'rtFailures'};
			$self->failures->{"$operation-$appInstanceNum"} = $opStats->{'failures'};

			if ( !$opPassRT ) {
				$console_logger->info("Workload $workloadNum AppInstance $appInstanceNum: Failed Response-Time metric for $operation");
			}
			if (!$opPassMix  && ($anyUsedLoadPath == 0)) {
				$console_logger->info("Workload $workloadNum AppInstance $appInstanceNum: Proportion check failed for $operation");
			}
			if ( !$opPassRT ) {
				$console_logger->info("Workload $workloadNum AppInstance $appInstanceNum: Failed Failure-Percent metric for $operation");
			}
		}
		
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

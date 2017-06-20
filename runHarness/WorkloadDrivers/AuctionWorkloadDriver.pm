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
  callMethodsOnObject1 callMethodOnObjects1);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

extends 'WorkloadDriver';

has '+name' => ( default => 'weathervane', );

has 'description' => (
	is  => 'ro',
	isa => 'Str',
);

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

# Holds the structure for the json run configuration
has 'runRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
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

my @secondaryIpAddresses = ();

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();

	# if the workloadProfileDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $weathervaneHome    = $self->getParamValue('weathervaneHome');
	my $workloadProfileDir = $self->getParamValue('workloadProfileDir');
	if ( !( $workloadProfileDir =~ /^\// ) ) {
		$workloadProfileDir = $weathervaneHome . "/" . $workloadProfileDir;
	}
	$self->setParamValue( 'workloadProfileDir', $workloadProfileDir );

};

override 'addSecondary' => sub {
	my ( $self, $secondary ) = @_;
	my $console_logger = get_logger("Console");

	my $myIpAddr = $self->host->ipAddr;
	my $ipAddr   = $secondary->host->ipAddr;
	if ( ( $myIpAddr eq $ipAddr ) || ( $ipAddr ~~ @secondaryIpAddresses ) ) {
		$console_logger->error(
"Multiple workloadDriver hosts are running on IP address $ipAddr.  This configuration is not supported."
		);
		exit(-1);
	}
	push @secondaryIpAddresses, $ipAddr;

	push @{ $self->secondaries }, $secondary;

};

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

sub createRunConfigHash {
	my ( $self, $appInstancesRef, $suffix ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $console_logger = get_logger("Console");
	my $workloadNum    = $self->getParamValue('workloadNum');

	my $tmpDir           = $self->getParamValue('tmpDir');
	my $workloadProfile  = $self->getParamValue('workloadProfile');
	my $rampUp           = $self->getParamValue('rampUp');
	my $steadyState      = $self->getParamValue('steadyState');
	my $rampDown         = $self->getParamValue('rampDown');
	my $totalTime        = $rampUp + $steadyState + $rampDown;
	my $usersScaleFactor = $self->getParamValue('usersScaleFactor');
	my $usersPerAuctionScaleFactor =
	  $self->getParamValue('usersPerAuctionScaleFactor');
	my $rampupInterval = $self->getParamValue('rampupInterval');
	my $useVirtualIp   = $self->getParamValue('useVirtualIp');
	my $secondariesRef = $self->secondaries;

	my $port = $self->portMap->{'http'};

	$logger->debug("createRunConfigHash");
	my $runRef = {};

	$runRef->{"name"} = "runW${workloadNum}";

	$runRef->{"statsHost"}          = $self->host->hostName;
	$runRef->{"portNumber"}         = $port;
	$runRef->{"statsOutputDirName"} = "/tmp";

	$runRef->{"hosts"} = [];
	push @{ $runRef->{"hosts"} }, $self->host->hostName;
	foreach my $secondary (@$secondariesRef) {
		$logger->debug("createRunConfigHash adding host " . $secondary->host->hostName);
		push @{ $runRef->{"hosts"} }, $secondary->host->hostName;
	}

	$runRef->{"workloads"} = [];

	my $numAppInstances = $#{$appInstancesRef} + 1;
	foreach my $appInstance (@$appInstancesRef) {
		my $instanceNum = $appInstance->getInstanceNum();
		my $users       = $appInstance->getUsers();

		my $workload = {};
		$workload->{'name'}             = "appInstance" . $instanceNum;
		$workload->{"behaviorSpecName"} = "auctionMainUser";
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
			$loadPath->{"steadyState"} = $steadyState;
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
			$loadPath->{"maxUsers"} = $appInstance->getMaxLoadedUsers();
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
		# associated with the www hostname for each appInstance
		my $wwwIpAddrsRef = [];
		if ( $appInstance->getParamValue('useVirtualIp') ) {
			$logger->debug(
"configure for workload $workloadNum, appInstance uses virtualIp"
			);
			my $wwwHostname = $appInstance->getWwwHostname();
			my $wwwIpsRef   = Utils::getIpAddresses($wwwHostname);
			foreach my $ip (@$wwwIpsRef) {

		   # When using virtualIP addresses, all edge services must use the same
		   # default port numbers
				push @$wwwIpAddrsRef, [ $ip, 80, 443 ];
			}
		}
		else {
			my $edgeService = $appInstance->getEdgeService();
			my $edgeServices =
			  $appInstance->getActiveServicesByType($edgeService);
			$logger->debug(
"configure for workload $workloadNum, appInstance does not use virtualIp. edgeService is $edgeService"
			);
			foreach my $service (@$edgeServices) {
				push @$wwwIpAddrsRef,
				  [
					$service->host->ipAddr, $service->portMap->{"http"},
					$service->portMap->{"https"}
				  ];
			}
		}
		my $numVIPs = $#{$wwwIpAddrsRef} + 1;
		$logger->debug("createRunConfigHash numVIPs = " .$numVIPs);

		$workload->{"targets"} = [];
		my @targetNames;
		my $uniquifier = 1;
		for ( my $vipNum = 0 ; $vipNum < $numVIPs ; $vipNum++ ) {
			my $target = {};

			my $serverName = $wwwIpAddrsRef->[$vipNum]->[0];
			my $httpPort   = $wwwIpAddrsRef->[$vipNum]->[1];
			my $httpsPort  = $wwwIpAddrsRef->[$vipNum]->[2];

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
	my ( $self, $appInstancesRef, $suffix ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $console_logger = get_logger("Console");
	my $workloadNum    = $self->getParamValue('workloadNum');
	$logger->debug("configure for workload $workloadNum, suffix = $suffix");
	$self->suffix($suffix);
	$self->appInstances($appInstancesRef);

	my $workloadProfileHome = $self->getParamValue('workloadProfileDir');
	my $workloadProfile     = $self->getParamValue('workloadProfile');
	my $rampUp              = $self->getParamValue('rampUp');
	my $steadyState         = $self->getParamValue('steadyState');
	my $rampDown            = $self->getParamValue('rampDown');
	my $totalTime           = $rampUp + $steadyState + $rampDown;
	my $usersScaleFactor    = $self->getParamValue('usersScaleFactor');
	my $rampupInterval      = $self->getParamValue('rampupInterval');
	my $useVirtualIp        = $self->getParamValue('useVirtualIp');
	my $tmpDir              = $self->getParamValue('tmpDir');

	$self->portMap->{'http'} = $self->internalPortMap->{'http'};
	$self->registerPortsWithHost();

	# configure the java DNS cache TTL on all drivers
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $javaHome         = $ENV{'JAVA_HOME'};
	if ( !( defined $javaHome ) ) {
		$console_logger->warn(
"The environment variable JAVA_HOME must be defined in order for Weathervane to run."
		);
		return 0;
	}

`$scpConnectString root\@$scpHostString:$javaHome/jre/lib/security/java.security /tmp/java.security.orig `;
	open( JAVASEC, "/tmp/java.security.orig" )
	  || die "Can't open /tmp/java.security.orig for reading: $!";
	open( JAVASECTMP, ">/tmp/java.security" )
	  || die "Can't open /tmp/java.security for writing: $!";
	while ( my $inline = <JAVASEC> ) {

		if ( $inline =~ /networkaddress.cache.ttl/ ) {
			if ($useVirtualIp) {
				print JAVASECTMP "networkaddress.cache.ttl = "
				  . $self->getParamValue('driverJvmDnsTtl') . "\n";
			}
			else {
				print JAVASECTMP "#networkaddress.cache.ttl = "
				  . $self->getParamValue('driverJvmDnsTtl') . "\n";
			}
		}
		elsif ( $inline =~ /networkaddress.cache.negative.ttl/ ) {
			if ($useVirtualIp) {
				print JAVASECTMP "networkaddress.cache.negative.ttl = "
				  . $self->getParamValue('driverJvmDnsTtl') . "\n";
			}
			else {
				print JAVASECTMP "#networkaddress.cache.negative.ttl = "
				  . $self->getParamValue('driverJvmDnsTtl') . "\n";
			}
		}
		else {
			print JAVASECTMP $inline;
		}
	}
	close JAVASEC;
	close JAVASECTMP;

`$scpConnectString /tmp/java.security root\@$scpHostString:$javaHome/jre/lib/security/java.security`;

	my $secondariesRef = $self->secondaries;
	foreach my $server (@$secondariesRef) {
		$scpConnectString = $server->host->scpConnectString;
		$scpHostString    = $server->host->scpHostString;
`$scpConnectString /tmp/java.security root\@$scpHostString:$javaHome/jre/lib/security/java.security`;
	}

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
`cp $sourceBehaviorSpecDirName/auction.followAuction.behavior.json $targetBehaviorSpecDirName/.`;
	}
	else {
		my @behaviorSpecFiles = (
			'auction.mainUser.behavior.json',
			'auction.followAuction.behavior.json'
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

	# Create the run.json structure for this workload
	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $runRef = $self->createRunConfigHash( $appInstancesRef, $suffix );
	$self->runRef($runRef);

	# Save the configuration in file form
	open( my $configFile, ">$tmpDir/run$suffix.json" )
	  || die "Can't open $tmpDir/run$suffix.json for writing: $!";
	print $configFile $json->encode($runRef) . "\n";
	close $configFile;

	$scpConnectString = $self->host->scpConnectString;
	$scpHostString    = $self->host->scpHostString;
`$scpConnectString $tmpDir/run$suffix.json root\@$scpHostString:/tmp/run$suffix.json`;

	# make sure nscd is not running
	$self->host->stopNscd();
	$secondariesRef = $self->secondaries;
	foreach my $server (@$secondariesRef) {
		$server->host->stopNscd();
	}

	return 1;

};

override 'redeploy' => sub {
	my ( $self, $logfile, $hostsRef ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $distDir         = $self->getParamValue('distDir');
	my $localHostname   = `hostname`;
	my $localIpsRef     = Utils::getIpAddresses($localHostname);
	$logger->debug(
		"Redeploying.  Local IPs = " . join( ", ", @$localIpsRef ) );

	# Get this host's version number
	my $sshConnectString = $self->host->sshConnectString;
	my $localVersion =
	  `$sshConnectString \"cat $weathervaneHome/version.txt\" 2>&1`;
	$logger->debug("For redeploy.  localVersion is $localVersion");

	foreach my $host (@$hostsRef) {

		# Get the host's version number
		my $hostname = $host->hostName;

		my $ip = Utils::getIpAddress($hostname);
		$logger->debug("Redeploying to $hostname.  IPs = $ip");

		if ( $ip ~~ @$localIpsRef ) {
			$logger->debug(
				"Don't redeploy to $hostname as it is the runHarness host");

			# Don't redeploy on the run harness host
			next;
		}

		my $sshConnectString = $host->sshConnectString;
		my $scpConnectString = $host->scpConnectString;
		my $scpHostString    = $host->scpHostString;

		my $version =
		  `$sshConnectString \"cat $weathervaneHome/version.txt\" 2>&1`;
		if ( $version =~ /No route/ ) {

			# This host is not up so can't redeploy
			$logger->debug("Don't redeploy to $hostname as it is not up.");
			next;
		}
		$logger->debug("For redeploy.  Version on $hostname is $version");

		# If different, update the weathervane directory on that host
		if ( $localVersion ne $version ) {

# Copy the entire weathervane directory to every host that has a different version number
			$logger->debug("Redeploying to $hostname");
`$scpConnectString -r $weathervaneHome/auctionConfigManager/* root\@$scpHostString:$weathervaneHome/auctionConfigManager/.`;
`$scpConnectString -r $weathervaneHome/auctionApp/* root\@$scpHostString:$weathervaneHome/auctionApp/.`;
`$scpConnectString -r $weathervaneHome/auctionWeb/* root\@$scpHostString:$weathervaneHome/auctionWeb/.`;
`$scpConnectString -r $weathervaneHome/autoSetup.pl root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/buildDockerImages.pl root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/build.gradle root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/configFiles/* root\@$scpHostString:$weathervaneHome/configFiles/.`;
`$scpConnectString -r $weathervaneHome/dbLoader/* root\@$scpHostString:$weathervaneHome/dbLoader/.`;
`$scpConnectString -r $weathervaneHome/doc/* root\@$scpHostString:$weathervaneHome/doc/.`;
`$scpConnectString -r $weathervaneHome/dockerImages/* root\@$scpHostString:$weathervaneHome/dockerImages/.`;
`$scpConnectString -r $weathervaneHome/gradlew root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/gradle.properties root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/images/* root\@$scpHostString:$weathervaneHome/images/.`;
`$scpConnectString -r $weathervaneHome/runHarness/* root\@$scpHostString:$weathervaneHome/runHarness/.`;
`$scpConnectString -r $weathervaneHome/settings.gradle root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/weathervane.pl root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/weathervane_users_guide.docx root\@$scpHostString:$weathervaneHome/.`;
`$scpConnectString -r $weathervaneHome/workloadDriver/* root\@$scpHostString:$weathervaneHome/workloadDriver/.`;
`$scpConnectString -r $weathervaneHome/workloadConfiguration/* root\@$scpHostString:$weathervaneHome/workloadConfiguration/.`;
`$scpConnectString -r $weathervaneHome/version.txt root\@$scpHostString:$weathervaneHome/.`;
		}

		# Always update the excutables
		my $cmdString = "$sshConnectString rm -r $distDir/* 2>&1";
		$logger->debug("Redeploy: $cmdString");
		`$cmdString`;
		$cmdString =
		  "$scpConnectString -r $distDir/* root\@$scpHostString:$distDir/.";
		$logger->debug("Redeploy: $cmdString");
		`$cmdString`;

	}

	# also always update the workload profiles on the drivers
	my $workloadProfileDir = $self->getParamValue('workloadProfileDir');
	my $scpConnectString   = $self->host->scpConnectString;
	my $scpHostString      = $self->host->scpHostString;
	$sshConnectString = $self->host->sshConnectString;
	my $hostname = $self->host->hostName;
	my $ip       = Utils::getIpAddress($hostname);
	if ( !( $ip ~~ @$localIpsRef ) ) {
		my $cmdString = "$sshConnectString rm -r $workloadProfileDir/* 2>&1";
		$logger->debug("Redeploy: $cmdString");
		`$cmdString`;
		$cmdString =
"$scpConnectString -r $workloadProfileDir/* root\@$scpHostString:$workloadProfileDir/.";
		$logger->debug("Redeploy: $cmdString");
		`$cmdString`;
	}
	my $secondariesRef = $self->secondaries;
	foreach my $server (@$secondariesRef) {

		my $hostname = $server->host->hostName;
		my $ip       = Utils::getIpAddress($hostname);
		if ( !( $ip ~~ @$localIpsRef ) ) {
			$sshConnectString = $server->host->sshConnectString;
			$scpConnectString = $server->host->scpConnectString;
			$scpHostString    = $server->host->scpHostString;
			my $cmdString =
			  "$sshConnectString rm -r $workloadProfileDir/* 2>&1";
			$logger->debug("Redeploy: $cmdString");
			`$cmdString`;
			$cmdString =
"$scpConnectString -r $workloadProfileDir/* root\@$scpHostString:$workloadProfileDir/.";
			$logger->debug("Redeploy: $cmdString");
			`$cmdString`;
		}
	}

# Future: When workload driver is dockerized, need to update the docker image here

};

sub killOld {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $sshConnectString = $self->host->sshConnectString;

	my $secondariesRef = $self->secondaries;
	my $hostname       = $self->host->hostName;
	$logger->debug("killOld");
	my $cmdOut = `$sshConnectString jps`;
	$logger->debug("killOld: jps output: $cmdOut");
	my @cmdOut = split /\n/, $cmdOut;
	foreach $cmdOut (@cmdOut) {
		$logger->debug("killOld: jps output line: $cmdOut");
		if ( $cmdOut =~ /^(\d+)\s+WorkloadDriverApplication/ ) {
			$logger->debug("killOld: killing pid $1");
			`ssh  -o 'StrictHostKeyChecking no'  root\@$hostname kill -9 $1`;
		}
	}

	# Make sure that no previous Benchmark processes are still running
	foreach my $secondary (@$secondariesRef) {
		my $hostname = $secondary->host->hostName;

		$cmdOut = `ssh  -o 'StrictHostKeyChecking no'  root\@$hostname jps`;
		$logger->debug("killOld: secondary $hostname jps output: $cmdOut");
		@cmdOut = split /\n/, $cmdOut;
		foreach $cmdOut (@cmdOut) {
			$logger->debug(
				"killOld: secondary $hostname jps output line: $cmdOut");
			if ( $cmdOut =~ /^(\d+)\s+WorkloadDriverApplication/ ) {
				$logger->debug(
					"killOld: secondary $hostname jps killing pid $1");
`ssh  -o 'StrictHostKeyChecking no'  root\@$hostname kill -9 $1 2>&1`;
			}
		}
	}

}

sub clearResults {
	my ($self) = @_;

	# Clear out the results of parsing any previous run
	$self->resultsValid(0);
	$self->opsSec(       {} );
	$self->reqSec(       {} );
	$self->passAll(      {} );
	$self->passRT(       {} );
	$self->overallAvgRT( {} );
	$self->rtAvg(        {} );
	$self->pctPassRT(    {} );
	$self->successes(    {} );
	$self->failures(     {} );
	$self->proportion(   {} );
}

sub initializeRun {
	my ( $self, $runNum, $logDir, $suffix ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$self->suffix($suffix);

	my $driverJvmOpts           = $self->getParamValue('driverJvmOpts');
	my $weathervaneWorkloadHome = $self->getParamValue('workloadDriverDir');
	my $workloadProfileHome     = $self->getParamValue('workloadProfileDir');
	my $workloadNum             = $self->getParamValue('workloadNum');

	my $runName = "runW${workloadNum}";

	my $driverThreads     = $self->getParamValue('driverThreads');
	my $driverHttpThreads = $self->getParamValue('driverHttpThreads');
	my $maxConnPerUser    = $self->getParamValue('driverMaxConnPerUser');

	my $port = $self->portMap->{'http'};

	if ( $self->getParamValue('logLevel') >= 3 ) {
		$driverJvmOpts .=
" -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:/tmp/gc-W${workloadNum}.log";
	}
	if ( $self->getParamValue('driverEnableJprofiler') ) {
		$driverJvmOpts .=
"  -agentpath:/opt/jprofiler8/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m ";
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

	my $driverClasspath =
" $weathervaneWorkloadHome/workloadDriver.jar:$weathervaneWorkloadHome/workloadDriverLibs/*:$weathervaneWorkloadHome/workloadDriverLibs/";

	# Create a list of all of the workloadDriver nodes including the primary
	my $driversRef     = [];
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		push @$driversRef, $secondary;
		$secondary->setPortNumber($port);
		$secondary->registerPortsWithHost();
	}
	push @$driversRef, $self;

	# Start the driver on all of the secondaries
	foreach my $secondary (@$secondariesRef) {
		my $sshConnectString = $secondary->host->sshConnectString;
		my $hostname         = $secondary->host->hostName;
		my $pid              = fork();
		if ( $pid == 0 ) {
			my $cmdString =
"$sshConnectString \"java $driverJvmOpts -DwkldNum=$workloadNum -cp $driverClasspath com.vmware.weathervane.workloadDriver.WorkloadDriverApplication --port=$port | tee /tmp/run_$hostname$suffix.log\" > $logDir/run_$hostname$suffix.log 2>&1";
			$logger->debug(
"Starting secondary driver for workload $workloadNum on $hostname: $cmdString"
			);
			`$cmdString`;
			exit;
		}
	}

	# start the primary
	my $pid              = fork();
	my $sshConnectString = $self->host->sshConnectString;
	if ( $pid == 0 ) {
		my $cmdString =
"$sshConnectString \"java $driverJvmOpts -DwkldNum=$workloadNum -cp $driverClasspath com.vmware.weathervane.workloadDriver.WorkloadDriverApplication --port=$port | tee /tmp/run$suffix.log\" > $logDir/run$suffix.log 2>&1 ";
		$logger->debug(
			"Running primary driver for workload $workloadNum: $cmdString");
		`$cmdString`;
		exit;
	}

	$logger->debug("Sleeping for 30 sec to let primary driver start");
	sleep 30;

	# Now keep checking whether the workload driver nodes are up
	my $allUp      = 1;
	my $retryCount = 0;
	do {
		$allUp = 1;
		foreach my $driver (@$driversRef) {
			my $isUp = $driver->isUp();
			$logger->debug( "For driver "
				  . $driver->host->hostName
				  . " isUp returned $isUp" );
			if ( !$isUp ) {
				$allUp = 0;
			}
		}

		$retryCount++;
		if ( !$allUp ) {
			sleep 24;
		}
	} while ( ( !$allUp ) && ( $retryCount < 10 ) );

	if ( !$allUp ) {
		$console_logger->warn(
"The workload driver nodes for workload $workloadNum did not start within 4 minutes. Exiting"
		);
		return 0;
	} else {
		$logger->debug("All workload drivers are up.");
	}

	# Now send the run configuration to all of the drivers
	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	my $ua = LWP::UserAgent->new;
	$ua->agent("Weathervane/1.0 ");

	my $runRef =
	  $self->createRunConfigHash( $self->workload->appInstancesRef, $suffix );
	my $runContent = $json->encode($runRef);

	$logger->debug("Run content for workload $workloadNum:\n$runContent\n");

	my $req;
	my $res;
	my $hostname = $self->host->hostName;
	my $url      = "http://$hostname:$port/run/$runName";
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
		$console_logger->warn(
"Could not send configuration message to workload driver node on $hostname. Exiting"
		);
		return 0;
	}

	# Send the behaviorSpecs to all of the drivers
	my $tmpDir = $self->getParamValue('tmpDir');
	my $behaviorSpecDirName =
	  "$tmpDir/configuration/workloadDriver/workload${workloadNum}";
	my @behaviorSpecFiles = (
		'auction.mainUser.behavior.json',
		'auction.followAuction.behavior.json'
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

		foreach my $driver (@$driversRef) {
			my $hostname = $driver->host->hostName;
			my $url      = "http://$hostname:$port/behaviorSpec";
			$logger->debug("Sending POST to $url with contents:\n$contents");
			$req = HTTP::Request->new( POST => $url );
			$req->content_type('application/json');
			$req->header( Accept => "application/json" );
			$req->content($contents);

			$res = $ua->request($req);
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
"Could not send behaviorSpec message to workload driver node on $hostname. Exiting"
				);
				return 0;
			}
		}
	}

	# Now send the initialize message to the runService
	$hostname = $self->host->hostName;
	$url      = "http://$hostname:$port/run/$runName/initialize";
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
		$console_logger->warn(
"Could not send initialize message to workload driver node on $hostname. Exiting"
		);
		return 0;
	}

	return 1;
}

sub startRun {
	my ( $self, $runNum, $logDir, $suffix ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	my $driverJvmOpts           = $self->getParamValue('driverJvmOpts');
	my $weathervaneWorkloadHome = $self->getParamValue('workloadDriverDir');
	my $workloadProfileHome     = $self->getParamValue('workloadProfileDir');
	my $workloadNum             = $self->getParamValue('workloadNum');
	my $runName                 = "runW${workloadNum}";
	my $rampUp              = $self->getParamValue('rampUp');
	my $steadyState         = $self->getParamValue('steadyState');
	my $rampDown            = $self->getParamValue('rampDown');
	my $totalTime           = $rampUp + $steadyState + $rampDown;

	# Create a list of all of the workloadDriver nodes including the primary
	my $driversRef     = [];
	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		push @$driversRef, $secondary;
	}
	push @$driversRef, $self;

	my $port = $self->portMap->{'http'};

	# get the pid of the java process
	my $sshConnectString = $self->host->sshConnectString;
	my $pid;
	my $out = `$sshConnectString ps x`;
	$logger->debug("Looking for pid of driver$suffix: $out");
	if ( $out =~
/^\s*(\d+)\s\?.*\d\d\sjava.*-DwkldNum=$workloadNum.*WorkloadDriverApplication/m
	  )
	{
		$pid = $1;
		$logger->debug("Found pid $pid for workload driver$suffix");
	}
	else {
		$logger->error("Can't find pid for workload driver$suffix");
		return 0;
	}

	# open a pipe to follow progress
	my $pipeString =
	  "$sshConnectString \"tail -f --pid=$pid /tmp/run$suffix.log\" |";
	$logger->debug("Command to follow workload progress: $pipeString");
	open my $driverPipe, "$pipeString"
	  or die "Can't fork to follow driver at /tmp/run$suffix.log : $!";

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
		my $hostname = $self->host->hostName;
		my $url      = "http://$hostname:$port/run/$runName/start";
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
			$console_logger->warn(
"Could not send start message to workload driver node on $hostname. Exiting"
			);
			return 0;
		}
		exit;
	}

	# Let the appInstances know that the workload is running.
	# The elasticityService needs to know.
	callMethodOnObjectsParallel( 'workloadRunning',
		$self->workload->appInstancesRef );

# Now send the stats/start message the primary driver which is also the statsService host
	my $statsStartedMsg = {};
	$statsStartedMsg->{'timestamp'} = time;
	my $statsStartedContent = $json->encode($statsStartedMsg);

	my $hostname = $self->host->hostName;
	my $url      = "http://$hostname:$port/stats/started/$runName";
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
		$console_logger->warn(
"Could not send stats/started message to workload driver node on $hostname. Exiting"
		);
		return 0;
	}

	my $periodicOutputId   = "";
	if ( $suffix ne "" ) {
		$periodicOutputId = "W${workloadNum} ";
	}
	my $nextIsHeader = 0;
	my $startTime    = time();
	my $startedSteadyState = 0;
	my $startedRampDown = 0;
	while ( my $inline = <$driverPipe> ) {
		if ( $inline =~ /^\d\d\:\d\d\:\d\d/ ) {
			# Ingore logging output
			next;	
		}
		chomp($inline);
		
		if ( $inline =~ /^\|/ ) {
			if ( $self->getParamValue('showPeriodicOutput') ) {
				print $periodicOutputId . $inline;
			}
		}

		# The next line after ----- should be first header
		if ( $inline =~ /^-------------------/ ) {
			$nextIsHeader = 1;
			next;
		}

		if ($nextIsHeader) {
			if (!( $inline =~ /^\|\s*Time/ )) {
				$console_logger->warn(
"Workload driver did not start properly. Check run.log for errors. "
				);
				return 0;
			}
			else {
				$nextIsHeader = 0;
				my $runLengthMinutes = $totalTime / 60;
				my $impl             = $self->getParamValue('workloadImpl');
				$console_logger->info(
"Running Workload $workloadNum: $impl.  Run will finish in approximately $runLengthMinutes minutes."
				);
				$logger->debug("Workload will ramp up for $rampUp. suffix = $suffix");
			}
		}
		
		if (!($inline =~ /^\|\s*\d/)) {
			# Don't do anything with header lines
			next;
		} elsif ($inline =~ /^\|[^\d]*(\d+)\|/) {
			my $curTime = $1;
			
			if (!$startedSteadyState && ($curTime >= $rampUp) && ($curTime < ($rampUp + $steadyState))) {

				$console_logger->info("Steady-State Started");

				$startedSteadyState = 1;
				
				# Start collecting statistics on all hosts and services
				$self->workload->startStatsCollection();
			} elsif (!$startedRampDown && ($curTime > ($rampUp + $steadyState))) { 

				$console_logger->info("Steady-State Complete");
				$startedRampDown = 1;
				$self->workload->stopStatsCollection();
			} elsif ($startedRampDown and  ($curTime > $totalTime)) {

				# Now send the stop message to the runService
				$hostname = $self->host->hostName;
				my $url      = "http://$hostname:$port/run/$runName/stop";
				$logger->debug("Sending POST to $url");
				$req = HTTP::Request->new( POST => $url );
				$req->content_type('application/json');
				$req->header( Accept => "application/json" );
				$req->content($runContent);
	
				$res = $ua->request($req);
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
	"Could not send stop message to workload driver node on $hostname. Exiting"
					);
					return 0;
				}

				sleep 30;

				# Now send the stats/complete message the primary driver which is also the statsService host
				my $statsCompleteMsg = {};
				$statsCompleteMsg->{'timestamp'} = time;
				my $statsCompleteContent = $json->encode($statsCompleteMsg);

				$hostname = $self->host->hostName;
				$url      = "http://$hostname:$port/stats/complete/$runName";
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
					$logger->debug(
						"Response sucessful.  Content: " . $res->content );
				}	
				else {
					$console_logger->warn(
					"Could not send stats/complete message to workload driver node on $hostname. Exiting"
					);
					return 0;
				}

				# Now send the shutdown message
				$hostname = $self->host->hostName;
				$url      = "http://$hostname:$port/run/$runName/shutdown";
				$logger->debug("Sending POST to $url");
				$req = HTTP::Request->new( POST => $url );
				$req->content_type('application/json');
				$req->header( Accept => "application/json" );
				$req->content($runContent);

				$res = $ua->request($req);
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
				
				last;
			}
		}
	}
	close $driverPipe;

	foreach my $driver (@$driversRef) {
		$driver->unRegisterPortsWithHost();
	}

	my $impl = $self->getParamValue('workloadImpl');
	$console_logger->info("Workload $workloadNum: $impl finished");
	return 1;
}

sub isUp {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->getParamValue('workloadNum');
	my $runName     = "runW${workloadNum}";

	my $hostname = $self->host->hostName;
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

	my $workloadNum = $self->getParamValue('workloadNum');
	my $runName     = "runW${workloadNum}";

	my $hostname = $self->host->hostName;
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

sub stopAppStatsCollection {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

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
	my $steadyState = $self->getParamValue('steadyState');
	my $db          = $self->getParamValue('dbServer');

	# Get the name of the first dbServer
	my $servicesByTypeRef = $self->servicesByTypeRef;
	my $dbServicesRef     = $servicesByTypeRef->{"dbServer"};
	my $dbServer          = $dbServicesRef->[0];
	my $dbHostname        = $dbServer->host->hostName;

	my $appStartDate    = "2020-02-02";
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
	else {
		$connectString =
"mysql  -u auction -pauction -h $dbHostname --database=auction --skip-column-names -s -e ";
		$avgBidCompletionDelay =
`$connectString \"SELECT AVG(delay)/1000 FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND  timestamp < '$steadyStateEndTimestamp' ;\"`;
		chomp($avgBidCompletionDelay);
		print LOG "avgBidCompletionDelay = $avgBidCompletionDelay\n";

		$stddevBidCompletionDelay =
`$connectString \"SELECT STDDEV(delay)/1000 FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND  timestamp < '$steadyStateEndTimestamp' ;\"`;
		chomp($stddevBidCompletionDelay);
		print LOG "stddevBidCompletionDelay = $stddevBidCompletionDelay\n";

		$avgItemDuration =
`$connectString \"SELECT avg(TIMESTAMPDIFF(SECOND, biddingStartTime, biddingEndTime)) FROM highbid WHERE biddingEndTime IS NOT NULL AND biddingStartTime IS NOT NULL AND  '$steadyStateStartTimestamp'<  biddingEndTime AND biddingStartTime <  '$steadyStateEndTimestamp';\"`;
		chomp($avgItemDuration);
		print LOG "avgItemDuration = $avgItemDuration\n";

		$avgCompletionsPerBid =
`$connectString \"SELECT AVG(numCompletedBids) FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND timestamp < '$steadyStateEndTimestamp' ;\"`;
		chomp($avgCompletionsPerBid);
		print LOG "avgCompletionsPerBid = $avgCompletionsPerBid\n";

		$stddevCompletionsPerBid =
`$connectString \"SELECT STDDEV(numCompletedBids) FROM bidcompletiondelay WHERE '$steadyStateStartTimestamp' < timestamp AND timestamp < '$steadyStateEndTimestamp' ;\"`;
		chomp($stddevCompletionsPerBid);
		print LOG "stddevCompletionsPerBid = $stddevCompletionsPerBid\n";

		$numTimeoffsetsDeleted =
		  `$connectString \"DELETE FROM fixedtimeoffset;\"`;
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
	my $sshConnectString = $self->host->sshConnectString;

	`$sshConnectString \"rm -f /tmp/queryStats.txt 2>&1\"`;
}

sub stopStatsCollection {
	my ($self) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	$logger->debug("stopStatsCollection");
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $workloadNum = $self->getParamValue('workloadNum');

	my $hostname = $self->host->hostName;
	`cp /tmp/gc-W${workloadNum}.log /tmp/gc-W${workloadNum}_rampup.log 2>&1`;

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $secHostname = $secondary->host->hostName;
`ssh  -o 'StrictHostKeyChecking no'  root\@$secHostname cp /tmp/gc-W${workloadNum}.log /tmp/gc-W${workloadNum}_rampup.log 2>&1`;
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $destinationPath  = $baseDestinationPath . "/" . $hostname;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $sshConnectString = $self->host->sshConnectString;
	my $workloadNum      = $self->getParamValue('workloadNum');

	`mkdir -p $destinationPath 2>&1`;
`$scpConnectString root\@$scpHostString:/tmp/gc-W${workloadNum}*.log $destinationPath/. 2>&1`;
`$scpConnectString root\@$scpHostString:/tmp/appInstance*.csv $destinationPath/. 2>&1`;
`$scpConnectString root\@$scpHostString:/tmp/appInstance*-summary.txt $destinationPath/. 2>&1`;

	`$sshConnectString rm -f /tmp/gc-W${workloadNum}*.log  2>&1`;
	`$sshConnectString rm -f /tmp/appInstance*.csv  2>&1`;
	`$sshConnectString rm -f /tmp/appInstance*-summary.txt  2>&1`;

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $secHostname     = $secondary->host->hostName;
		my $destinationPath = $baseDestinationPath . "/" . $secHostname;
		`mkdir -p $destinationPath 2>&1`;
`scp root\@$secHostname:/tmp/gc-W${workloadNum}*.log $destinationPath/. 2>&1`;
	}

}

sub cleanStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $workloadNum      = $self->getParamValue('workloadNum');

	`$sshConnectString rm -f /tmp/gc-W${workloadNum}*.log 2>&1`;

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $secHostname = $secondary->host->hostName;
`ssh  -o 'StrictHostKeyChecking no'  root\@$secHostname  \"rm -f /tmp/gc-W${workloadNum}*.log 2>&1\"`;
	}
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

}

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $suffix = $self->suffix;

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $sshConnectString = $secondary->host->sshConnectString;
		my $hostname         = $secondary->host->hostName;
		my $cmdString =
		  "$sshConnectString \"rm /tmp/run_$hostname$suffix.log\" 2>&1";
		`$cmdString`;
	}

	my $sshConnectString = $self->host->sshConnectString;
	my $cmdString = "$sshConnectString \"rm /tmp/run$suffix.log\"  2>&1 ";
	`$cmdString`;

}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $suffix           = $self->suffix;

	`mkdir -p $destinationPath`;
`$scpConnectString root\@$scpHostString:/tmp/run${suffix}.json $destinationPath/.`;
}

sub getResultMetrics {
	my ($self) = @_;
	tie( my %metrics, 'Tie::IxHash' );

	$metrics{"opsSec"}         = $self->opsSec;
	$metrics{"overallAvgRTRT"} = $self->overallAvgRT;

	return \%metrics;
}

sub getWorkloadStatsSummary {
	my ( $self, $csvRef, $logDir ) = @_;

	$self->parseStats($logDir);

	my $appInstancesRef = $self->workload->appInstancesRef;
	my $numAppInstances = $#{$appInstancesRef} + 1;
	foreach my $appInstanceRef (@$appInstancesRef) {
		my $appInstanceNum = $appInstanceRef->getParamValue("appInstanceNum");
		my $isPassed = $self->isPassed( $appInstanceRef, $logDir );
		if ($isPassed) {
			$csvRef->{"pass-I$appInstanceNum"} = "Y";
		}
		else {
			$csvRef->{"pass-I$appInstanceNum"} = "N";
		}
	}

	my $opsSec       = 0;
	my $httpReqSec   = 0;
	my $overallAvgRT = 0;
	for (
		my $appInstanceNum = 1 ;
		$appInstanceNum <= $numAppInstances ;
		$appInstanceNum++
	  )
	{
		$opsSec       += $self->opsSec->{$appInstanceNum};
		$httpReqSec   += $self->reqSec->{$appInstanceNum};
		$overallAvgRT += $self->overallAvgRT->{$appInstanceNum};
	}
	$overallAvgRT /= $numAppInstances;

	$csvRef->{"opsSec"}       = $opsSec;
	$csvRef->{"httpReqSec"}   = $httpReqSec;
	$csvRef->{"overallAvgRT"} = $overallAvgRT;

}

sub getWorkloadSummary {
	my ( $self, $csvRef, $logDir ) = @_;

	$csvRef->{"RampUp"}      = $self->getParamValue('rampUp');
	$csvRef->{"SteadyState"} = $self->getParamValue('steadyState');
	$csvRef->{"RampDown"}    = $self->getParamValue('rampDown');

}

sub getHostStatsSummary {
	my ( $self, $csvRef, $baseDestinationPath, $filePrefix ) = @_;
	tie( my %csvRefByHostname, 'Tie::IxHash' );
	my $headers = "";

	my $workloadDriverHostsRef = $self->getWorkloadDriverHosts();
	foreach my $host (@$workloadDriverHostsRef) {
		my $hostname        = $host->hostName;
		my $destinationPath = $baseDestinationPath . "/" . $hostname;
		if (   ( !exists $csvRefByHostname{$hostname} )
			|| ( !defined $csvRefByHostname{$hostname} ) )
		{
			$csvRefByHostname{$hostname} =
			  $host->getStatsSummary($destinationPath);
		}
	}

	# put the headers and values into the summary file
	my $hostname    = $self->host->hostName;
	my $csvHashRef  = $csvRefByHostname{$hostname};
	my $workloadNum = $self->getParamValue('workloadNum');
	open( HOSTCSVFILE,
		">>$baseDestinationPath/${filePrefix}host_stats_summary.csv" )
	  or die
"Can't open $baseDestinationPath/${filePrefix}host_stats_summary.csv: $!\n";
	print HOSTCSVFILE "Service Type,Hostname,IP Addr";
	foreach my $key ( keys %$csvHashRef ) {
		print HOSTCSVFILE ",$key";
	}
	print HOSTCSVFILE "\n";

	print HOSTCSVFILE "workloadDriver,"
	  . $self->host->hostName . ","
	  . $self->host->ipAddr;

	my @avgKeys = ( "cpuUT", "cpuIdle_stdDev", "avgWait" );
	foreach my $key ( keys %$csvHashRef ) {
		if ( $key ~~ @avgKeys ) {
			$csvRef->{"wkldDriver_average_$key"} = $csvHashRef->{$key};
		}
		else {
			$csvRef->{"wkldDriver_total_$key"} = $csvHashRef->{$key};
		}
		print HOSTCSVFILE "," . $csvHashRef->{$key};
	}
	print HOSTCSVFILE "\n";

	my $secondariesRef = $self->secondaries;
	foreach my $secondary (@$secondariesRef) {
		my $secHost = $secondary->host;
		$csvHashRef = $csvRefByHostname{ $secHost->hostName };
		print HOSTCSVFILE "workloadDriver,"
		  . $secHost->hostName . ","
		  . $secHost->ipAddr;
		foreach my $key ( keys %$csvHashRef ) {

			if ( $key ~~ @avgKeys ) {
				$csvRef->{"wkldDriver_average_$key"} += $csvHashRef->{$key};
			}
			else {
				$csvRef->{"wkldDriver_total_$key"} += $csvHashRef->{$key};
			}
			print HOSTCSVFILE "," . $csvHashRef->{$key};
		}
		print HOSTCSVFILE "\n";
	}

# Now turn the total into averages for the "cpuUT", "cpuIdle_stdDev", and "avgWait"
	foreach my $key (@avgKeys) {
		$csvRef->{"wkldDriver_average_$key"} /= ( $#{$secondariesRef} + 2 );
	}

	close HOSTCSVFILE;

}

sub getWorkloadAppStatsSummary {
	my ( $self, $statsLogPath ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	tie( my %csv, 'Tie::IxHash' );
	$self->parseStats($statsLogPath);

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
			if (   ( !exists $self->successes->{"$op-$appInstanceNum"} )
				|| ( !defined $self->successes->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_rtAvg"} =
			  $self->rtAvg->{"$op-$appInstanceNum"};

		}
		foreach my $op (@operations) {
			if (   ( !exists $self->successes->{"$op-$appInstanceNum"} )
				|| ( !defined $self->successes->{"$op-$appInstanceNum"} ) )
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
			if (   ( !exists $self->successes->{"$op-$appInstanceNum"} )
				|| ( !defined $self->successes->{"$op-$appInstanceNum"} ) )
			{
				next;
			}
			$csv{"${aiSuffix}${op}_Failures"} =
			  $self->failures->{"$op-$appInstanceNum"};

		}
		foreach my $op (@operations) {
			if (   ( !exists $self->successes->{"$op-$appInstanceNum"} )
				|| ( !defined $self->successes->{"$op-$appInstanceNum"} ) )
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
	my ( $self, $csvRef, $statsLogPath ) = @_;

	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $gcviewerDir     = $self->getParamValue('gcviewerDir');
	if ( !( $gcviewerDir =~ /^\// ) ) {
		$gcviewerDir = $weathervaneHome . "/" . $gcviewerDir;
	}

	# Only parseGc if gcviewer is present
	if ( -f "$gcviewerDir/gcviewer-1.34-SNAPSHOT.jar" ) {
		my $workloadNum = $self->getParamValue('workloadNum');
		open( HOSTCSVFILE,
">>$statsLogPath/workload${workloadNum}_workloadDriver_gc_summary.csv"
		  )
		  or die
"Can't open $statsLogPath/workload${workloadNum}_workloadDriver_gc_summary.csv: $!\n";

		tie( my %accumulatedCsv, 'Tie::IxHash' );

		my $hostname = $self->host->hostName;
		my $logPath  = $statsLogPath . "/" . $hostname;
		`mkdir -p $logPath`;
		my $csvHashRef =
		  ParseGC::parseGCLog( $logPath, "-W${workloadNum}", $gcviewerDir );
		print HOSTCSVFILE "Hostname, IP Addr";
		foreach my $key ( keys %$csvHashRef ) {
			print HOSTCSVFILE ", $key";
		}
		print HOSTCSVFILE "\n";
		print HOSTCSVFILE $hostname . ", " . $self->host->ipAddr;
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
			my $secHostname = $secondary->host->hostName;
			my $logPath     = $statsLogPath . "/" . $secHostname;
			`mkdir -p $logPath`;
			$csvHashRef =
			  ParseGC::parseGCLog( $logPath, "-W${workloadNum}", $gcviewerDir );
			print HOSTCSVFILE $secHostname . ", " . $secondary->host->ipAddr;

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
	my $workloadNum = $self->getParamValue('workloadNum');
	my $runName     = "runW${workloadNum}";

	my %appInstanceToUsersHash;

	my $ua = LWP::UserAgent->new;

	$ua->timeout(300);
	$ua->agent("Weathervane/1.0");

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);

	# Get the number of users on the primary driver
	my $hostname = $self->host->hostName;
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
		$hostname = $secondary->host->hostName;
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
	my $workloadNum = $self->getParamValue('workloadNum');
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
		my $hostname = $driver->host->hostName;
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

sub isPassed {
	my ( $self, $appInstanceRef, $logDir ) = @_;
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");

	$self->parseStats($logDir);
	my $appInstanceNum = $appInstanceRef->getParamValue('appInstanceNum');

	my $usedLoadPath = 0;
	my $userLoadPath = $appInstanceRef->getLoadPath();
	if ( $#$userLoadPath >= 0 ) {
		$logger->debug( "AppInstance "
			  . $appInstanceNum
			  . " uses a user load path so not using proportions." );
		$usedLoadPath = 1;
	}
	my $configPath = $appInstanceRef->getConfigPath();
	if ( $#$configPath >= 0 ) {
		$logger->debug( "AppInstance "
			  . $appInstanceNum
			  . " uses a config path so not using proportions." );
		$usedLoadPath = 1;
	}

	if ($usedLoadPath) {

		# Using a load path in steady state, so ignore proportions
		return $self->passRT->{$appInstanceNum};
	}
	return $self->passAll->{$appInstanceNum};
}

sub parseStats {
	my ( $self, $logDir ) = @_;
	my $console_logger = get_logger("Console");
	my $logger =
	  get_logger("Weathervane::WorkloadDrivers::AuctionWorkloadDriver");
	my $workloadNum = $self->getParamValue('workloadNum');

	# If already have parsed results, don't do it again
	if ( $self->resultsValid ) {
		return;
	}

	my $anyUsedLoadPath = 0;
	my $appInstancesRef = $self->workload->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $userLoadPath = $appInstance->getLoadPath();
		if ( $#$userLoadPath >= 0 ) {
			$anyUsedLoadPath = 1;
		}
		my $configPath = $appInstance->getConfigPath();
		if ( $#$configPath >= 0 ) {
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
	my $suffix          = "";
	if ( $self->workload->useSuffix ) {
		$suffix = $self->workload->suffix;
	}
	open( RESULTFILE, "$logDir/run$suffix.log" )
	  or die "Can't open $logDir/run$suffix.log: $!";

	while ( my $inline = <RESULTFILE> ) {

		if ( $inline =~ /Summary Statistics for workload appInstance(\d+)\s*$/ )
		{

			my $appInstanceNum = $1;

			# This is the section with the operation response-time data
			# for appInstance $1
			while ( $inline = <RESULTFILE> ) {

				if ( $inline =~ /Interval: rampDown/ ) {
					last;
				}
				elsif ( $inline =~ /Interval: steadyState/ ) {

					# parse the steadystate results for appInstance $1
					while ( $inline = <RESULTFILE> ) {
						if ( $inline =~ /Passed:\strue/ ) {
							$self->passAll->{$appInstanceNum} = 1;
						}
						elsif ( $inline =~ /Passed:\sfalse/ ) {
							$self->passAll->{$appInstanceNum} = 0;
						}
						elsif ( $inline =~ /Passed Response-Time:\strue/ ) {
							$self->passRT->{$appInstanceNum} = 1;
						}
						elsif ( $inline =~ /Passed Response-Time:\sfalse/ ) {
							$self->passRT->{$appInstanceNum} = 0;
						}
						elsif ( $inline =~
							/Average Response-Time:\s(\d+\.\d+)\ssec/ )
						{
							$self->overallAvgRT->{$appInstanceNum} = $1;
						}
						elsif ( $inline =~ /^\s*Throughput:\s(\d+\.\d+)\sops/ )
						{
							$self->opsSec->{$appInstanceNum} = $1;
						}
						elsif ( $inline =~
							/^\s*Http\sOperation\sThroughput:\s+(\d+\.\d+)\sops/
						  )
						{
							$logger->debug(
								"Found Http Operation Throughput line: $1");
							$self->reqSec->{$appInstanceNum} = $1;
						}
						elsif ( $inline =~ /\|\s+Name/ ) {

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

	$self->resultsValid(1);
}

__PACKAGE__->meta->make_immutable;

1;

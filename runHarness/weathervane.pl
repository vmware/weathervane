#!/usr/bin/perl
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
#
# Created by: Hal Rosenberg
#
# This is the entrypoint to Weathervane
#
package Weathervane;
use strict;
use Getopt::Long;
use JSON;
use POSIX;
use List::Util qw[min max];
use String::Util qw(trim);
use FileHandle;
use Statistics::Descriptive;
use Switch;
use Log::Log4perl qw(get_logger :levels);

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use lib '/root/weathervane/runHarness';

use Factories::ServiceFactory;
use Factories::HostFactory;
use Factories::ClusterFactory;
use Factories::VIFactory;
use Factories::RunManagerFactory;
use Factories::DataManagerFactory;
use Factories::WorkloadDriverFactory;
use Factories::WorkloadFactory;
use Factories::AppInstanceFactory;
use Parameters
  qw(getParamDefault getParamType getParamKeys getParamValue setParamValue mergeParameters usage fullUsage);
use Utils qw(getIpAddresses getIpAddress);

# Turn on auto flushing of output
BEGIN { $| = 1 }

sub createHost {
	my ( $hostParamHashRef, $runProcedure, $instance, $ipToHostHashRef ) = @_;
	my $weathervane_logger = get_logger("Weathervane");
	my $console_logger     = get_logger("Console");

	if ( ( !exists $hostParamHashRef->{'hostName'} ) || ( !defined $hostParamHashRef->{'hostName'} ) ) {
		$console_logger->error("Hosts defined under the hosts keyword must define a hostName");
		exit(-1);
	}
	my $hostname = $hostParamHashRef->{'hostName'};
	$weathervane_logger->debug("Creating host for host $hostname\n");

	my $hostIP = getIpAddress($hostname);
	$weathervane_logger->debug("IP address for host $hostname is $hostIP\n");

	my $host       = 0;
	my $createdNew = 0;
	if ( exists $ipToHostHashRef->{$hostIP} ) {
		$host = $ipToHostHashRef->{$hostIP};
		if ( $host->isGuest ) {
			$host->addVmName($hostname);
			if ( $hostParamHashRef->{'vmName'} ) {
				$host->addVmName( $hostParamHashRef->{'vmName'} );
			}
		}
	}
	else {
		$createdNew = 1;
		$host       = HostFactory->getHost($hostParamHashRef);
		if ( $host->isGuest ) {
			$host->addVmName($hostname);
			if ( $hostParamHashRef->{'vmName'} ) {
				$host->addVmName( $hostParamHashRef->{'vmName'} );
			}
		}
		$runProcedure->addHost($host);
		$ipToHostHashRef->{$hostIP} = $host;
	}

	if ($instance) {
		$instance->setHost($host);
	}

	my @retVal = ($createdNew, $host);

	return \@retVal;
}


sub createCluster {
	my ( $clusterParamHashRef, $runProcedure, $instance, $clusterNameToClusterHashRef ) = @_;
	my $weathervane_logger = get_logger("Weathervane");
	my $console_logger     = get_logger("Console");

	if ( ( !exists $clusterParamHashRef->{'clusterName'} ) || ( !defined $clusterParamHashRef->{'clusterName'} ) ) {
		$console_logger->error("Clusters defined under the clusters keyword must define a clusterName");
		exit(-1);
	}
	my $clusterName = $clusterParamHashRef->{'clusterName'};
	$weathervane_logger->debug("Creating cluster for cluster $clusterName\n");

	my $cluster = 0;
	my $createdNew = 0;
	if ( exists $clusterNameToClusterHashRef->{$clusterName} ) {
		$cluster = $clusterNameToClusterHashRef->{$clusterName}
	}
	else {
		$createdNew = 1;
		$cluster = ClusterFactory->getCluster($clusterParamHashRef);
		$runProcedure->addCluster($cluster);
		$clusterNameToClusterHashRef->{$clusterName} = $cluster;
	}

	if ($instance) {
		$instance->setHost($cluster);
	}

	my @retVal = ($createdNew, $cluster);

	return \@retVal;
}

sub createComputeResource {
	my ($paramsHashRef, $instanceParamHashRef, $runProcedure, $instance, $clusterNameToClusterHashRef, $ipToHostHashRef, $useAllSuffixes, $isNonDocker) = @_;
	my $weathervane_logger = get_logger("Weathervane");

	my $json = JSON->new;
	$json = $json->relaxed(1);
	$json = $json->pretty(1);
	$json = $json->max_depth(4096);

	$weathervane_logger->debug("createComputeResource  ");
	
	my $retArrayRef;
	if ($instanceParamHashRef->{"clusterName"}) {
		my $clusterParamHashRef = Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $instanceParamHashRef,
			"clusters", $useAllSuffixes );
		$weathervane_logger->debug( "For cluster ", $instanceParamHashRef->{'clusterName'}, " the Param hash ref is:" );
		my $tmp = $json->encode($clusterParamHashRef);
		$weathervane_logger->debug($tmp);
		$retArrayRef = createCluster( $clusterParamHashRef, $runProcedure, $instance, $clusterNameToClusterHashRef );		
	} else {
		my $hostParamHashRef = Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $instanceParamHashRef,
			"hosts", $useAllSuffixes );
		$weathervane_logger->debug( "For host ", $hostParamHashRef->{'hostName'}, " the Param hash ref is:" );
		my $tmp = $json->encode($hostParamHashRef);
		$weathervane_logger->debug($tmp);
		$retArrayRef = createHost( $hostParamHashRef, $runProcedure, $instance, $ipToHostHashRef );

		my ($createdNew, $host) = @$retArrayRef;
		$host->isNonDocker($isNonDocker);
	}
	
	return $retArrayRef;
	
}

# read in the command-line options
my %paramCommandLine = ();
my @paramStrings     = ();
my @validParams      = ();
my $keysRef          = getParamKeys();
foreach my $key (@$keysRef) {
	my $type = getParamType($key);
	push @validParams, $key;
	if ( ( $type eq "hash" ) || ( $type eq "list" ) ) {
		next;
	}
	push @paramStrings, $key . $type;
}
GetOptions( \%paramCommandLine, @paramStrings );

# If there is a "users" parameter on the command-line, turn it
# into list of values for the different appInstances.  The values are
# assigned to the appInstances in order.  If there are too few, then
# the remaining appInstances get the values from the configFile or the default.
# If there are too many then the extras are ignored.
my @usersList;
if ( exists $paramCommandLine{'users'} ) {
	@usersList = split( ',', $paramCommandLine{'users'} );
}

# Figure out where to read the config file
my $configFileName;
if ( exists( $paramCommandLine{'configFile'} ) ) {
	$configFileName = $paramCommandLine{'configFile'};
}
else {
	$configFileName = getParamDefault('configFile');
}

# Read in the config file
open( CONFIGFILE, "<$configFileName" ) or die "Couldn't Open $configFileName: $!\n";
my $json = JSON->new;
$json = $json->relaxed(1);
$json = $json->pretty(1);
$json = $json->max_depth(4096);

my $paramJson = "";
while (<CONFIGFILE>) {
	$paramJson .= $_;
}
close CONFIGFILE;

my $paramConfig = $json->decode($paramJson);

# Make sure that all of the parameters read from the config file are valid
foreach my $key ( keys %$paramConfig ) {
	if ( !( $key ~~ @validParams ) ) {
		die "Parameter $key in configuration file $configFileName is not a valid parameter";
	}
}

my $paramsHashRef = mergeParameters( \%paramCommandLine, $paramConfig );

# Set up the loggers
my $weathervaneHome = getParamValue( $paramsHashRef, 'weathervaneHome' );
my $console_logger = get_logger("Console");
$console_logger->level($INFO);
my $layout   = Log::Log4perl::Layout::PatternLayout->new("%d{E MMM d HH:mm:ss yyyy}: %m%n");
my $appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::File",
	name     => "rootConsoleFile",
	filename => "$weathervaneHome/console.log",
	mode     => "append",
);
$appender->layout($layout);
$console_logger->add_appender($appender);
$appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::Screen",
	name   => "rootConsoleScreen",
	stderr => 0,
);
$appender->layout($layout);
$console_logger->add_appender($appender);

my $weathervane_logger = get_logger("Weathervane");
$weathervane_logger->level($WARN);
$layout   = Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M - %m%n");
$appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::File",
	name     => "rootDebugFile",
	filename => "$weathervaneHome/debug.log",
	mode     => "write",
);
$weathervane_logger->add_appender($appender);
$appender->layout($layout);
$appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::Screen",
	name      => "rootWeathervaneScreen",
	stderr    => 0,
	threshold => "WARN",
);
$weathervane_logger->add_appender($appender);
$appender->layout($layout);

if ( getParamValue( $paramsHashRef, "loggers" ) ) {
	my $loggersHashRef = getParamValue( $paramsHashRef, "loggers" );
	my @keys = keys %$loggersHashRef;
	foreach my $loggerName ( keys %$loggersHashRef ) {
		my $logger = get_logger($loggerName);
		$logger->level( $loggersHashRef->{$loggerName} );
	}
}

my $logger = get_logger("Weathervane");

# set the run length parameters properly
my $runLength   = getParamValue( $paramsHashRef, "runLength" );
my $rampUp      = getParamValue( $paramsHashRef, "rampUp" );
my $steadyState = getParamValue( $paramsHashRef, "steadyState" );
my $rampDown    = getParamValue( $paramsHashRef, "rampDown" );

if ( $rampUp eq "" ) {
	if ( $runLength eq "short" ) {
		$rampUp = 120;
	}
	elsif ( $runLength eq "medium" ) {
		$rampUp = 720;
	}
	elsif ( $runLength eq "long" ) {
		$rampUp = 720;
	}
	else {
		print "runLength must be either short, medium, or long, not $runLength\n";
		usage();
		exit;
	}
}

if ( $steadyState eq "" ) {
	if ( $runLength eq "short" ) {
		$steadyState = 180;
	}
	elsif ( $runLength eq "medium" ) {
		$steadyState = 900;
	}
	elsif ( $runLength eq "long" ) {
		$steadyState = 1800;
	}
	else {
		print "runLength must be either short, medium, or long, not $runLength\n";
		usage();
		exit;
	}
}

if ( $rampDown eq "" ) {
	if ( $runLength eq "short" ) {
		$rampDown = 60;
	}
	elsif ( $runLength eq "medium" ) {
		$rampDown = 60;
	}
	elsif ( $runLength eq "long" ) {
		$rampDown = 120;
	}
	else {
		print "runLength must be either short, medium, or long, not $runLength\n";
		usage();
		exit;
	}
}
setParamValue( $paramsHashRef, "rampUp",      $rampUp );
setParamValue( $paramsHashRef, "steadyState", $steadyState );
setParamValue( $paramsHashRef, "rampDown",    $rampDown );


# make sure that JAVA_HOME is defined
my $javaHome         = $ENV{'JAVA_HOME'};
if ( !( defined $javaHome ) ) {
	$console_logger->warn("The environment variable JAVA_HOME must be defined in order for Weathervane to run.");
	return 0;
}

# Check for a request for the help text
my $help = getParamValue( $paramsHashRef, "help" );
if ($help) {
	usage();
	exit;
}

# Check for a request for the help text
my $fullHelp = getParamValue( $paramsHashRef, "fullHelp" );
if ($fullHelp) {
	fullUsage();
	exit;
}

my $version = getParamValue( $paramsHashRef, "version" );
if ($version) {
	$console_logger->warn( "Weathervane Version " . $Parameters::version );
}

$console_logger->info("Command-line parameters:");
foreach my $key ( keys %paramCommandLine ) {
	$console_logger->info( "\t$key: " . $paramCommandLine{$key} );
}

# if we are stopping a run, then use the singlefixed run manager
my $stop = getParamValue( $paramsHashRef, "stop" );
if ($stop) {
	setParamValue( $paramsHashRef, "runStrategy",  'single' );
	setParamValue( $paramsHashRef, "runProcedure", 'stop' );
}

# hash to build up the as-run parameter output
my $paramsAsRun = \%$paramsHashRef;

# Create a file for logging the output
my $runLog;
open( $runLog, ">>$weathervaneHome/console.log" ) || die "Error opening $weathervaneHome/console.log:$!";

if ( $logger->is_debug() ) {
	my $tmp = $json->encode($paramsHashRef);
	$logger->debug( "The paramsHashRef after command-line and configfile is :\n" . $tmp );
}

# Start by building the runManager.  It holds the entire structure needed for the run(s)
my $runManagerParamHashRef =
  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $paramsHashRef, "runManagerInstance", 0 );
if ( $logger->is_debug() ) {
	my $tmp = $json->encode($runManagerParamHashRef);
	$logger->debug( "The runManager instance paramHashRef is:\n" . $tmp );
}
my $runManager = RunManagerFactory->getRunManager($runManagerParamHashRef);

# Start by building the runManager.  It holds the entire structure needed for the run(s)
my $runProcedureParamHashRef =
  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $runManagerParamHashRef, "runProcInstance",
	$runManagerParamHashRef->{'useAllSuffixes'} );

if ( $logger->is_debug() ) {
	my $tmp = $json->encode($runProcedureParamHashRef);
	$logger->debug( "The runProcedure instance paramHashRef is:\n" . $tmp );
}
my $runProcedure = RunProcedureFactory->getRunProcedure($runProcedureParamHashRef);
$runProcedure->origParamHashRef($paramsHashRef);

# Set the run Procedure in the runmanager
$runManager->setRunProcedure($runProcedure);

# Get the parameters for the hosts that are explicitly defined in
# The configuration parameters
my %ipToHostHash;
my $instancesListRef = $runProcedureParamHashRef->{"hosts"};
my $hostsParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "hosts", 1,
	$runProcedureParamHashRef->{'useAllSuffixes'} );
foreach my $paramHashRef (@$hostsParamHashRefs) {
	$logger->debug( "For host ", $paramHashRef->{'hostName'}, " the Param hash ref is:" );
	my $tmp = $json->encode($paramHashRef);
	$logger->debug($tmp);
	my $retArrayRef = createHost( $paramHashRef, $runProcedure, 0, \%ipToHostHash );
	my ($createdNew, $host) = @$retArrayRef;
	if ( !$createdNew ) {
		$console_logger->warn( "Warning: Have defined multiple host instances in the host block which point "
			  . "to the same IP address.\nOnly the parameters for the first such host will be used." );
	}
}

# Get the parameters for the clusters that are explicitly defined in
# The configuration parameters
my %clusterNameToClusterHash;
$instancesListRef = $runProcedureParamHashRef->{"clusters"};
my $clustersParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "clusters", 1,
	$runProcedureParamHashRef->{'useAllSuffixes'} );
foreach my $paramHashRef (@$clustersParamHashRefs) {
	$logger->debug( "For cluster ", $paramHashRef->{'clusterName'}, " the Param hash ref is:" );
	my $tmp = $json->encode($paramHashRef);
	$logger->debug($tmp);
	my $retArrayRef = createCluster( $paramHashRef, $runProcedure, 0, \%clusterNameToClusterHash );
	my ($createdNew, $host) = @$retArrayRef;
	if ( !$createdNew ) {
		$console_logger->error( "Error: Have defined multiple cluster instances in the cluster block with the same clusterName. This is not allowed." );
		exit 1;
	}
}

# Get the parameters for the workload instances
my $nextInstanceNum = 1;
my $numDefault      = $runProcedureParamHashRef->{"numWorkloads"};
my $workloadsParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $numDefault, "workloads",
	$nextInstanceNum, $runProcedureParamHashRef > {'useAllSuffixes'} );
$nextInstanceNum += $numDefault;
$instancesListRef = $runProcedureParamHashRef->{"workloads"};
my $instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "workloads",
	$nextInstanceNum, $runProcedureParamHashRef > {'useAllSuffixes'} );
push @$workloadsParamHashRefs, @$instancesParamHashRefs;

my $numWorkloads = $#{$workloadsParamHashRefs} + 1;
if ( $logger->is_debug() ) {
	$logger->debug("Have $numWorkloads workloads");
	$logger->debug("Their Param hash refs are:");
	foreach my $paramHashRef (@$workloadsParamHashRefs) {
		my $tmp = $json->encode($paramHashRef);
		$logger->debug($tmp);
	}
}
$console_logger->info("Run Configuration has $numWorkloads workloads.");

# Figure out how many appInstances in each workload to that can
# decide whether we need to use all suffixes.
my $maxNumAppInstances = 0;
my $workloadNum        = 1;
foreach my $workloadParamHashRef (@$workloadsParamHashRefs) {

	# Get the paramHashRefs for the appInstances

	my $numAppInstances = $workloadParamHashRef->{"numAppInstances"};
	$instancesListRef = $workloadParamHashRef->{"appInstances"};
	$numAppInstances += $#{$instancesListRef} + 1;
	if ( $numAppInstances > $maxNumAppInstances ) {
		$maxNumAppInstances = $numAppInstances;
	}
	$logger->debug("The number of appInstances for workload $workloadNum is $numAppInstances");
	$workloadNum++;
}
$logger->debug("The max number of appInstances is $maxNumAppInstances");

# Decide whether to use all suffixes in the hostnames
my $useAllSuffixes = 0;
if ( ( $numWorkloads > 1 ) || ( $maxNumAppInstances > 1 ) ) {
	$logger->debug(
		"Setting useAllSuffixes to 1.  numWorkloads = $numWorkloads, maxNumAppInstances = $maxNumAppInstances");
	$useAllSuffixes = 1;
}

# Create the workload instances and all of their sub-parts
$workloadNum = 1;
my @workloads;
foreach my $workloadParamHashRef (@$workloadsParamHashRefs) {
	$workloadParamHashRef->{'workloadNum'} = $workloadNum;
	my $workloadImpl = $workloadParamHashRef->{'workloadImpl'};

	my $workload = WorkloadFactory->getWorkload($workloadParamHashRef);
	if ( $numWorkloads > 1 ) {
		$workload->useSuffix(1);
	}
	push @workloads, $workload;

	# Get the paramHashRefs for the appInstances
	$nextInstanceNum = 1;
	$numDefault      = $workloadParamHashRef->{"numAppInstances"};
	my $appInstanceParamHashRefs =
	  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault, "appInstances",
		$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
	$nextInstanceNum += $numDefault;
	$instancesListRef = $workloadParamHashRef->{"appInstances"};
	$instancesParamHashRefs =
	  Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef, "appInstances",
		$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
	push @$appInstanceParamHashRefs, @$instancesParamHashRefs;

	my $numAppInstances = $#{$appInstanceParamHashRefs} + 1;
	if ( $logger->is_debug() ) {
		$logger->debug("For workload $workloadNum, have $numAppInstances appInstances");
		$logger->debug("Their Param hash refs are:");
		foreach my $paramHashRef (@$appInstanceParamHashRefs) {
			my $tmp = $json->encode($paramHashRef);
			$logger->debug($tmp);
		}
	}

	# Get the parameters for the driver instances
	$nextInstanceNum = 1;
	$numDefault      = $workloadParamHashRef->{"numDrivers"};
	my $driversParamHashRefs =
	  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault,
		"drivers", $nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
	$nextInstanceNum += $numDefault;
	$instancesListRef = $workloadParamHashRef->{"drivers"};
	$instancesParamHashRefs =
	  Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef,
		"drivers", $nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
	push @$driversParamHashRefs, @$instancesParamHashRefs;

	if ( $#$driversParamHashRefs < 0 ) {
		$console_logger->error(
"Workload $workloadNum does not have any drivers.  Specify at least one workload driver using either the numDrivers or drivers parameters."
		);
		exit(-1);
	}

	# The first driver is the primary driver.  The others are secondaries
	my $primaryDriverParamHashRef = shift @$driversParamHashRefs;
	if ( $logger->is_debug() ) {
		my $tmp = $json->encode($primaryDriverParamHashRef);
		$logger->debug( "For workload $workloadNum, the primary driver instance paramHashRef is:\n" . $tmp );
	}

	# Create the primary workload driver
	my $workloadDriver = WorkloadDriverFactory->getWorkloadDriver($primaryDriverParamHashRef);

	# Create the computeResource for the primary driver
	my $retArrayRef = createComputeResource( $paramsHashRef, $primaryDriverParamHashRef, $runProcedure, $workloadDriver, \%clusterNameToClusterHash, \%ipToHostHash, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes, 1 );

	# Add the primary driver to the workload
	$workload->setPrimaryDriver($workloadDriver);
	$workloadDriver->setWorkload($workload);

	my $numSecondaries = $#{$driversParamHashRefs} + 1;
	if ( $logger->is_debug() ) {
		$logger->debug("For workload $workloadNum, have $numSecondaries secondary drivers");
		$logger->debug("Their Param hash refs are:");
		foreach my $paramHashRef (@$driversParamHashRefs) {
			my $tmp = $json->encode($paramHashRef);
			$logger->debug($tmp);
		}
	}

	my $numDrivers = $numSecondaries + 1;
	$console_logger->info("Workload $workloadNum has $numDrivers workload-driver nodes");
	$console_logger->info("Workload $workloadNum has $numAppInstances application instances.");

	# Create the secondary drivers and add them to the primary driver
	foreach my $secondaryDriverParamHashRef (@$driversParamHashRefs) {
		my $secondary = WorkloadDriverFactory->getWorkloadDriver($secondaryDriverParamHashRef);

		# Create the host for the secondary driver
		my $retArrayRef = createComputeResource( $paramsHashRef, $secondaryDriverParamHashRef, $runProcedure, $secondary, \%clusterNameToClusterHash, \%ipToHostHash, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes, 1 );

		# Add the secondary driver to the primary
		$workloadDriver->addSecondary($secondary);
	}

	# Create the appInstances and add them to the workload
	my @appInstances;
	my $appInstanceNum = 1;    # Count appInstances so that each gets a unique suffix
	foreach my $appInstanceParamHashRef (@$appInstanceParamHashRefs) {
		$console_logger->info("Workload $workloadNum, Application Instance $appInstanceNum configuration:");

		my $users = shift @usersList;
		if ( defined $users ) {
			$appInstanceParamHashRef->{'users'} = $users;
		}
		$appInstanceParamHashRef->{'instanceNum'}    = $appInstanceNum;
		$appInstanceParamHashRef->{'appInstanceNum'} = $appInstanceNum;
		my $appInstance = AppInstanceFactory->getAppInstance($appInstanceParamHashRef);
		push @appInstances, $appInstance;

		# Create and add all of the services for the appInstance.
		my $serviceTypesRef = $WeathervaneTypes::serviceTypes{$workloadImpl};
		foreach my $serviceType (@$serviceTypesRef) {

			# Need to create IP manager last once we know which is the edge service
			if ( $serviceType eq 'ipManager' ) {
				next;
			}

			my @services;

			# Get the service instance parameters
			$nextInstanceNum = 1;
			$numDefault      = $appInstanceParamHashRef->{ "num" . ucfirst($serviceType) . "s" };
			my $svcInstanceParamHashRefs =
			  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $numDefault,
				$serviceType . "s",
				$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
			$nextInstanceNum += $numDefault;
			$instancesListRef = $appInstanceParamHashRef->{ $serviceType . "s" };
			$instancesParamHashRefs =
			  Parameters::getInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $instancesListRef,
				$serviceType . "s",
				$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
			push @$svcInstanceParamHashRefs, @$instancesParamHashRefs;

			my $numScvInstances = $#{$svcInstanceParamHashRefs} + 1;
			if ( $logger->is_debug() ) {
				$logger->debug(
					"For workload $workloadNum and appInstance $appInstanceNum, have $numScvInstances ${serviceType}s."
				);
				$logger->debug("Their Param hash refs are:");
				foreach my $paramHashRef (@$svcInstanceParamHashRefs) {
					my $tmp = $json->encode($paramHashRef);
					$logger->debug($tmp);
				}
			}
			$console_logger->info( "\t$numScvInstances " . ucfirst($serviceType) . "s" );

			# Create the service instances and add them to the appInstance
			my $svcNum = 1;
			foreach my $svcInstanceParamHashRef (@$svcInstanceParamHashRefs) {
				$svcInstanceParamHashRef->{"instanceNum"} = $svcNum;
				$svcInstanceParamHashRef->{"serviceType"} = $serviceType;
				my $service =
				  ServiceFactory->getServiceByType( $svcInstanceParamHashRef, $serviceType, $numScvInstances,
					$appInstance, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
				push @services, $service;
				# Create the ComputeResource for the service
				my $retArrayRef = createComputeResource( $paramsHashRef, $svcInstanceParamHashRef, $runProcedure, $service, \%clusterNameToClusterHash, \%ipToHostHash, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes, !$service->getParamValue('useDocker') );
				
				$svcNum++;
			}

			$appInstance->setServicesByType( $serviceType, \@services );
		}

		# Let the appInstance set up the number of services active at start
		$appInstance->initializeServiceConfig();

		# Ask the application which service is the edge service that is directly used by clients.
		# This may affect the configuration of port numbers
		my $edgeService = $appInstance->getEdgeService();
		$weathervane_logger->debug(
			"EdgeService for application $appInstanceNum in workload $workloadNum is $edgeService");
		$appInstanceParamHashRef->{'edgeService'} = $edgeService;

		# Only configure IP manager services if we are using virtual IPs for this appInstance
		my $useVirtualIp = $appInstanceParamHashRef->{'useVirtualIp'};
		if ($useVirtualIp) {
			$weathervane_logger->debug("Configuring IP Managers for virtualIp");
			$appInstanceParamHashRef->{'numIpManagers'}   = $appInstance->getNumActiveOfServiceType($edgeService);
			$appInstanceParamHashRef->{"ipManagerSuffix"} = $appInstanceParamHashRef->{ $edgeService . "Suffix" };

			my @services;
			my $serviceType = 'ipManager';

			# Get the service instance parameters
			$nextInstanceNum = 1;
			$numDefault      = $appInstanceParamHashRef->{ "num" . ucfirst($serviceType) . "s" };
			my $svcInstanceParamHashRefs =
			  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $numDefault,
				$serviceType . "s",
				$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
			$nextInstanceNum += $numDefault;
			$instancesListRef = $appInstanceParamHashRef->{ $serviceType . "s" };
			$instancesParamHashRefs =
			  Parameters::getInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $instancesListRef,
				$serviceType . "s",
				$nextInstanceNum, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
			push @$svcInstanceParamHashRefs, @$instancesParamHashRefs;

			my $numScvInstances = $#{$svcInstanceParamHashRefs} + 1;
			if ( $logger->is_debug() ) {
				$logger->debug(
					"For workload $workloadNum and appInstance $appInstanceNum, have $numScvInstances ${serviceType}s."
				);
				$logger->debug("Their Param hash refs are:");
				foreach my $paramHashRef (@$svcInstanceParamHashRefs) {
					my $tmp = $json->encode($paramHashRef);
					$logger->debug($tmp);
				}
			}

			# Create the service instances and add them to the appInstance
			my $svcNum = 1;
			foreach my $svcInstanceParamHashRef (@$svcInstanceParamHashRefs) {
				$svcInstanceParamHashRef->{"instanceNum"} = $svcNum;
				$svcInstanceParamHashRef->{"serviceType"} = $serviceType;
				my $service =
				  ServiceFactory->getServiceByType( $svcInstanceParamHashRef, $serviceType, $numScvInstances,
					$appInstance, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
				push @services, $service;

				# Create the ComputeResource for the service
				my $retArrayRef = createComputeResource( $paramsHashRef, $svcInstanceParamHashRef, $runProcedure, $service, \%clusterNameToClusterHash, \%ipToHostHash, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes, !$service->getParamValue('useDocker') );

				$svcNum++;
			}

			$appInstance->setServicesByType( $serviceType, \@services );

			# Let the appInstance set up the number of services active at start
			$appInstance->initializeServiceConfig();

		}
		else {
			$appInstanceParamHashRef->{'numIpManagers'} = 0;
		}

		# Create and add the dataManager
		my $dataManagerParamHashRef =
		  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $appInstanceParamHashRef,
			"dataManagerInstance", $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes );
		if ( $logger->is_debug() ) {
			my $tmp = $json->encode($dataManagerParamHashRef);
			$logger->debug(
				"For workload $workloadNum and appInstance $appInstanceNum, the dataManager instance paramHashRef is:\n"
				  . $tmp );
		}

		my $dataManager = DataManagerFactory->getDataManager( $dataManagerParamHashRef, $appInstance );
		$appInstance->setDataManager($dataManager);
		$dataManager->setWorkloadDriver($workloadDriver);

		# Create the ComputeResource for the dataManager
		my $retArrayRef = createComputeResource( $paramsHashRef, $dataManagerParamHashRef, $runProcedure, $dataManager, \%clusterNameToClusterHash, \%ipToHostHash, $workloadParamHashRef->{'useAllSuffixes'} || $useAllSuffixes, 1);

		$console_logger->info( "\tmaxDuration = " . $dataManager->getParamValue('maxDuration') );

		# Now that the configuration of the appInstance is complete, ask it to check whether the
		# configuration is valid for its workload type
		if ( !$appInstance->checkConfig() ) {
			$console_logger->error(
				"The configuration of appInstance $appInstanceNum is invalid for workload type $workloadImpl");
			exit(-1);
		}

		$appInstanceNum++;

	}
	$workload->setAppInstances( \@appInstances );
	$workload->setPortNumbers();

	$workloadNum++;
}

$runProcedure->setWorkloads( \@workloads );

# Tell the hosts to configure the information that they need for pinning
# containers to CPUs on docker hosts
#$runProcedure->configureDockerHostCpuPinning();

# Create the Virtual Infrastructure
my $viParamHashRef = Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $runProcedureParamHashRef,
	"virtualInfrastructureInstance", 0 );
if ( $logger->is_debug() ) {
	my $tmp = $json->encode($viParamHashRef);
	$logger->debug( "The virtualInfrastructure instance paramHashRef is:\n" . $tmp );
}

my $vi = VIFactory->getVI($viParamHashRef);
$runProcedure->setVirtualInfrastructure($vi);

# Set up the virtualInfrastructure Management Hosts
$nextInstanceNum = 1;
$numDefault      = $viParamHashRef->{"numViMgmtHosts"};
my $viMgmtHostInstanceParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viMgmtHosts",
	$nextInstanceNum, 0 );
$nextInstanceNum += $numDefault;
$instancesListRef = $viParamHashRef->{"viMgmtHosts"};
$instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viMgmtHosts",
	$nextInstanceNum, 0 );
push @$viMgmtHostInstanceParamHashRefs, @$instancesParamHashRefs;

if ( $logger->is_debug() ) {
	my $numViMgmtHosts = $#{$viMgmtHostInstanceParamHashRefs} + 1;
	$logger->debug("Have $numViMgmtHosts viMgmtHosts.");
	$logger->debug("Their Param hash refs are:");
	foreach my $paramHashRef (@$viMgmtHostInstanceParamHashRefs) {
		my $tmp = $json->encode($paramHashRef);
		$logger->debug($tmp);
	}
}

foreach my $viMgmtHostInstanceParamHashRef (@$viMgmtHostInstanceParamHashRefs) {
	my $viMgmtHost = HostFactory->getVIMgmtHost($viMgmtHostInstanceParamHashRef);
	$vi->addManagementHost($viMgmtHost);
	$viMgmtHost->setVirtualInfrastructure($vi);
}

# Create all of the virtual infrastructure Hosts
$nextInstanceNum = 1;
$numDefault      = $viParamHashRef->{"numViHosts"};
my $viHostInstanceParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viHosts",
	$nextInstanceNum, 0 );
$nextInstanceNum += $numDefault;
$instancesListRef = $viParamHashRef->{"viHosts"};
$instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viHosts",
	$nextInstanceNum, 0 );
push @$viHostInstanceParamHashRefs, @$instancesParamHashRefs;

if ( $logger->is_debug() ) {
	my $numViHosts = $#{$viHostInstanceParamHashRefs} + 1;
	$logger->debug("Have $numViHosts viHosts.");
	$logger->debug("Their Param hash refs are:");
	foreach my $paramHashRef (@$viHostInstanceParamHashRefs) {
		my $tmp = $json->encode($paramHashRef);
		$logger->debug($tmp);
	}
}

foreach my $viHostInstanceParamHashRef (@$viHostInstanceParamHashRefs) {
	my $viHost = HostFactory->getVIHost($viHostInstanceParamHashRef);
	$vi->addHost($viHost);
	$viHost->setVirtualInfrastructure($vi);
}

# Tell the virtualInfrastructure to initialize its knowledge of the VMs it contains
$vi->initializeVmInfo();

# start the run(s)
$console_logger->info( "Running Weathervane with "
	  . $runManager->name
	  . " using "
	  . $runManager->runProcedure->name
	  . " RunProcedure.\n" );
$runManager->start();

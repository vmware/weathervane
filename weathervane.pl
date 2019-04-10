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
use Factories::VIFactory;
use Factories::RunManagerFactory;
use Factories::DataManagerFactory;
use Factories::WorkloadDriverFactory;
use Factories::WorkloadFactory;
use Factories::AppInstanceFactory;
use Parameters
  qw(getParamDefault getParamType getParamKeys getParamValue setParamValue mergeParameters usage fullUsage);
use StderrToLogerror;

# Turn on auto flushing of output
BEGIN { $| = 1 }

sub createDockerHost {
	my ($hostParamHashRef, $runProcedure, $nameToComputeResourceHashRef) = @_;
	my $weathervane_logger = get_logger("Weathervane");
	my $console_logger     = get_logger("Console");

	if ( ( !exists $hostParamHashRef->{'name'} ) || ( !defined $hostParamHashRef->{'name'} ) ) {
		$console_logger->error("All DockerHost definitions must include a name.");
		exit(-1);
	}
	my $hostname = $hostParamHashRef->{'name'};
	if ( exists $nameToComputeResourceHashRef->{$hostname} ) {
		$console_logger->error("All DockerHost definitions must have a unique name.  $hostname is used for more than one DockerHost or KubernetesCluster.");
		exit(-1);
	}

	$weathervane_logger->debug("Creating dockerHost for host $hostname\n");
	my $host = HostFactory->getDockerHost($hostParamHashRef);
	$runProcedure->addHost($host);
	$nameToComputeResourceHashRef->{$hostname} = $host;

	return $host;
}


sub createKubernetesCluster {
	my ($clusterParamHashRef, $runProcedure, $nameToComputeResourceHashRef) = @_;
	my $weathervane_logger = get_logger("Weathervane");
	my $console_logger     = get_logger("Console");

	if ( ( !exists $clusterParamHashRef->{'name'} ) || ( !defined $clusterParamHashRef->{'name'} ) ) {
		$console_logger->error("All KubernetesCluster definitions must include a name.");
		exit(-1);
	} 
	my $clusterName = $clusterParamHashRef->{'name'};
	if ( ( !exists $clusterParamHashRef->{'kubernetesConfigFile'} ) || ( !defined $clusterParamHashRef->{'kubernetesConfigFile'} ) ) {
		$console_logger->error("KubernetesCluster $clusterName does not have a kubernetesConfigFile parameter.  This parameter points to the kubectl config file for the desired context.");
		exit(-1);
	}	
	if ( exists $nameToComputeResourceHashRef->{$clusterName} ) {
		$console_logger->error("All KubernetesCluster definitions must have a unique name.  $clusterName is used for more than one DockerHost or KubernetesCluster.");
		exit(-1);
	}	
	$weathervane_logger->debug("Creating cluster for cluster $clusterName\n");

	my $cluster = HostFactory->getKubernetesCluster($clusterParamHashRef);
	$runProcedure->addCluster($cluster);
	$nameToComputeResourceHashRef->{$clusterName} = $cluster;
	return $cluster;
}

# Get the host to use for an Instance (driver, dataManager, service, etc) 
sub getComputeResourceForInstance {
	my ($instanceParamHashRef, $instanceNum, $serviceType, $nameToComputeResourceHashRef) = @_;
	my $console_logger = get_logger("Console");

	# If the instance defines a hostname, then we must use that to find the host.
	if ($instanceParamHashRef->{"hostname"}) {
		my $hostname = $instanceParamHashRef->{"hostname"};
		if ( !exists $nameToComputeResourceHashRef->{$hostname} ) {
		  $console_logger->error("Instance $instanceNum of type $serviceType specified hostname $hostname, but no DockerHost or KubernetesCluster with that name was defined.");
		  exit(-1);
		}
		return $nameToComputeResourceHashRef->{$hostname};
	}
	
	# If the xxxServerHosts was defined for this serviceType, then use 
	# the right host from that list as determined by the instanceNum.
	# The assignment of host to instance wraps if the instanceNum is greater
	# than the number of hot names specified.
	if ($instanceParamHashRef->{"${serviceType}Hosts"}) {
		my $hostListRef = $instanceParamHashRef->{"${serviceType}Hosts"};
		my $hostListLength = $#{$hostListRef} + 1;
		my $hostListIndex = ($instanceNum - 1) % $hostListLength;
		my $hostname = $hostListRef->[$hostListIndex];
		if ( !exists $nameToComputeResourceHashRef->{$hostname} ) {
		  $console_logger->error("Instance $instanceNum of type $serviceType was assigned hostname $hostname from ${serviceType}Hosts, but no DockerHost or KubernetesCluster with that name was defined.");
		  exit(-1);
		}
		return $nameToComputeResourceHashRef->{$hostname};		
	}
	
	# At this point we should use the value of appInstanceHost.  If it is not defined, then 
	# there is an error.
	my $hostname = $instanceParamHashRef->{"appInstanceHost"};
	if ($hostname) {
		if ( !exists $nameToComputeResourceHashRef->{$hostname} ) {
		  $console_logger->error("Instance $instanceNum of type $serviceType was assigned hostname $hostname from appInstanceHost, but no DockerHost or KubernetesCluster with that name was defined.");
		  exit(-1);
		}
		return $nameToComputeResourceHashRef->{$hostname};		
	} else {
		  $console_logger->error("Instance $instanceNum of type $serviceType does not have a hostname defined.\n" . 
		     "You must specify the hostname by defining either appInstanceHost or ${serviceType}Hosts.\n") .
		     "If using a custom configurationSize, you can also specify the host name using the hostname parameter for this instance";
		  exit(-1);	
	}
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

# Read in the fixed configuration
open( FIXEDCONFIGFILE, "<./runHarness/fixedConfigs.json" ) or die "Couldn't Open fixedConfigs.json: $!\n";
$paramJson = "";
while (<FIXEDCONFIGFILE>) {
	$paramJson .= $_;
}
close FIXEDCONFIGFILE;
my $fixedConfigs = $json->decode($paramJson);

my $weathervaneHome = getParamValue( $paramsHashRef, 'weathervaneHome' );

# if the tmpDir doesn't start with a / then it
# is relative to weathervaneHome
my $tmpDir = getParamValue( $paramsHashRef, 'tmpDir');
if ( !( $tmpDir =~ /^\// ) ) {
	$tmpDir = $weathervaneHome . "/" . $tmpDir;
}
setParamValue( $paramsHashRef, 'tmpDir', $tmpDir );

# if the outputDir doesn't start with a / then it
# is relative to weathervaneHome
my $outputDir = getParamValue( $paramsHashRef, 'outputDir' );
if ( !( $outputDir =~ /^\// ) ) {
	$outputDir = $weathervaneHome . "/" . $outputDir;
}
setParamValue( $paramsHashRef, 'outputDir', $outputDir );

# if the distDir doesn't start with a / then it
# is relative to weathervaneHome
my $distDir         = getParamValue( $paramsHashRef, 'distDir' );
if ( !( $distDir =~ /^\// ) ) {
	$distDir = $weathervaneHome . "/" . $distDir;
}
setParamValue( $paramsHashRef, 'distDir', $distDir );

# if the sequenceNumberFile doesn't start with a / then it
# is relative to weathervaneHome
my $sequenceNumberFile = getParamValue( $paramsHashRef, 'sequenceNumberFile' );
if ( !( $sequenceNumberFile =~ /^\// ) ) {
	$sequenceNumberFile = $weathervaneHome . "/" . $sequenceNumberFile;
}
setParamValue( $paramsHashRef, 'sequenceNumberFile', $sequenceNumberFile );

# make sure the directories exist
if ( !( -e $tmpDir ) ) {
	`mkdir $tmpDir`;
}

if ( !( -e $outputDir ) ) {
	`mkdir -p $outputDir`;
}

# Get the sequence number of the next run
my $seqnum;
if ( -e "$sequenceNumberFile" ) {
	open SEQFILE, "<$sequenceNumberFile";
	$seqnum = <SEQFILE>;
	close SEQFILE;
	if ( -e "$outputDir/$seqnum" ) {
		print "Next run number is $seqnum, but directory for run $seqnum already exists in $outputDir\n";
		exit -1;
	}
	open SEQFILE, ">$sequenceNumberFile";
	my $nextSeqNum = $seqnum + 1;
	print SEQFILE $nextSeqNum;
	close SEQFILE;
}
else {
	if ( -e "$outputDir/0" ) {
		print "Sequence number file is missing, but run 0 already exists in $outputDir\n";
		exit -1;
	}
	$seqnum = 0;
	open SEQFILE, ">$sequenceNumberFile";
	my $nextSeqNum = 1;
	print SEQFILE $nextSeqNum;
	close SEQFILE;
}

#clean out the tmp directory
`rm -r $tmpDir/* 2>&1`;

# Copy the version file into the output directory
`cp $weathervaneHome/version.txt $tmpDir/version.txt`;

# Save the original config file and processed command line parameters 
`cp $configFileName $tmpDir/$configFileName.save`;

open PARAMCOMMANDLINEFILE, ">$tmpDir/paramCommandLine.save";
print PARAMCOMMANDLINEFILE $json->encode(\%paramCommandLine);
close PARAMCOMMANDLINEFILE;

# Set up the loggers
my $console_logger = get_logger("Console");
$console_logger->level($INFO);
my $layout   = Log::Log4perl::Layout::PatternLayout->new("%d{E MMM d HH:mm:ss yyyy}: %m%n");
my $appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::File",
	name     => "rootConsoleFile",
	filename => "$tmpDir/console.log",
	mode     => "write",
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
$weathervane_logger->level($DEBUG);
$layout   = Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M - %m%n");
$appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::File",
	name     => "rootDebugFile",
	filename => "$tmpDir/debug.log",
	mode     => "write",
);
$console_logger->add_appender($appender); #also send console_logger output to debug log
$weathervane_logger->add_appender($appender);
$appender->layout($layout);
$appender = Log::Log4perl::Appender->new(
	"Log::Dispatch::Screen",
	name      => "rootWeathervaneScreen",
	stderr    => 0,
);
$appender->threshold($WARN); #don't spam screen with DEBUG/INFO levels if they are enabled
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

tie *STDERR, "StderrToLogerror", category => "Console";

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
	setParamValue( $paramsHashRef, "runStrategy",  'fixed' );
	setParamValue( $paramsHashRef, "runProcedure", 'stop' );
}

# hash to build up the as-run parameter output
my $paramsAsRun = \%$paramsHashRef;

if ( $logger->is_debug() ) {
	my $tmp = $json->encode($paramsHashRef);
	$logger->debug( "The paramsHashRef after command-line and configfile is :\n" . $tmp );
}

# Start by building the runManager.  It holds the entire structure needed for the run(s)
my $runManagerParamHashRef =
  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $paramsHashRef, "runManagerInstance" );
if ( $logger->is_debug() ) {
	my $tmp = $json->encode($runManagerParamHashRef);
	$logger->debug( "The runManager instance paramHashRef is:\n" . $tmp );
}
my $runManager = RunManagerFactory->getRunManager($runManagerParamHashRef);

# Build the runProcedure
my $runProcedureParamHashRef =
  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $runManagerParamHashRef, "runProcInstance" );

if ( $logger->is_debug() ) {
	my $tmp = $json->encode($runProcedureParamHashRef);
	$logger->debug( "The runProcedure instance paramHashRef is:\n" . $tmp );
}
my $runProcedure = RunProcedureFactory->getRunProcedure($runProcedureParamHashRef);
$runProcedure->origParamHashRef($paramsHashRef);

# Set the run Procedure in the runmanager
$runManager->setRunProcedure($runProcedure);

# Create the dockerHosts
my %nameToComputeResourceHash;
my $instancesListRef = $runProcedureParamHashRef->{"dockerHosts"};
my $hostsParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "dockerHosts" );
foreach my $paramHashRef (@$hostsParamHashRefs) {
	$logger->debug( "For dockerHost ", $paramHashRef->{'name'}, " the Param hash ref is:" );
	my $tmp = $json->encode($paramHashRef);
	$logger->debug($tmp);
	my $host = createDockerHost( $paramHashRef, $runProcedure, \%nameToComputeResourceHash );
}

# Create the kubernetesClusters
$instancesListRef = $runProcedureParamHashRef->{"kubernetesClusters"};
my $clustersParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "kubernetesClusters");
foreach my $paramHashRef (@$clustersParamHashRefs) {
	$logger->debug( "For kubernetesCluster ", $paramHashRef->{'name'}, " the Param hash ref is:" );
	my $tmp = $json->encode($paramHashRef);
	$logger->debug($tmp);
	my $cluster = createCluster( $paramHashRef, $runProcedure, 0, \%nameToComputeResourceHash );
}

# Get the parameters for the workload instances
my $numDefault      = $runProcedureParamHashRef->{"numWorkloads"};
my $workloadsParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $numDefault, "workloads" );
$instancesListRef = $runProcedureParamHashRef->{"workloads"};
my $instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "workloads" );
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

# Create the workload instances and all of their sub-parts
my $workloadNum = 1;
my @workloads;
foreach my $workloadParamHashRef (@$workloadsParamHashRefs) {
	my $workloadImpl = $workloadParamHashRef->{'workloadImpl'};

	my $workload = WorkloadFactory->getWorkload($workloadParamHashRef);
	$workload->instanceNum($workloadNum);
	if ( $numWorkloads > 1 ) {
		$workload->useSuffix(1);
	}
	push @workloads, $workload;

	# Get the paramHashRefs for the appInstances
	$numDefault      = $workloadParamHashRef->{"numAppInstances"};
	my $appInstanceParamHashRefs =
	  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault, "appInstances");
	$instancesListRef = $workloadParamHashRef->{"appInstances"};
	$instancesParamHashRefs =
	  Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef, "appInstances");
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
	$numDefault      = $workloadParamHashRef->{"numDrivers"};
	my $driversParamHashRefs =
	  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault, "drivers");
	$instancesListRef = $workloadParamHashRef->{"drivers"};
	$instancesParamHashRefs =
	  Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef, "drivers");
	push @$driversParamHashRefs, @$instancesParamHashRefs;

	if ( $#$driversParamHashRefs < 0 ) {
		$console_logger->error(
"Workload $workloadNum does not have any drivers.  Specify at least one workload driver using either the numDrivers or drivers parameters."
		);
		exit(-1);
	}

	# The first driver is the primary driver.  The others are secondaries
	my $driverNum = 1;
	my $primaryDriverParamHashRef = shift @$driversParamHashRefs;
	if ( $logger->is_debug() ) {
		my $tmp = $json->encode($primaryDriverParamHashRef);
		$logger->debug( "For workload $workloadNum, the primary driver instance paramHashRef is:\n" . $tmp );
	}

	# Create the primary workload driver
	my $host = getComputeResourceForInstance( $primaryDriverParamHashRef, $driverNum, "driver", \%nameToComputeResourceHash);
	my $workloadDriver = WorkloadDriverFactory->getWorkloadDriver($primaryDriverParamHashRef, $host);
	$workloadDriver->host($host);
	$workloadDriver->setWorkload($workload);
	$workloadDriver->instanceNum($driverNum);
	$driverNum++;

	# Add the primary driver to the workload
	$workload->setPrimaryDriver($workloadDriver);

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
		$host = getComputeResourceForInstance( $secondaryDriverParamHashRef, $driverNum, "driver", \%nameToComputeResourceHash);
		my $secondary = WorkloadDriverFactory->getWorkloadDriver($secondaryDriverParamHashRef, $host);
		$secondary->host($host);
		$secondary->instanceNum($driverNum);
		$secondary->setWorkload($workload);
		$driverNum++;

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
		my $appInstance = AppInstanceFactory->getAppInstance($appInstanceParamHashRef);
		$appInstance->instanceNum($appInstanceNum);
		$appInstance->workload($workload);
		push @appInstances, $appInstance;

		# Overwrite the appInstance's parameters with those specified by the configuration size.
		my $configSize = $appInstanceParamHashRef->{'configurationSize'};
		if ($configSize ne "custom") {
			if (!($configSize ~~ (keys $fixedConfigs))) {
				$console_logger->error("Error: For appInstance " . $appInstanceNum 
					.  " configurationSize " . $configSize + " does not exist.");
			}
			my $config = $fixedConfigs->{$configSize};
			foreach my $key (keys %$config) {
				$appInstanceParamHashRef->{$key} = $config->{$key};
			}
		}
		
		# Create and add all of the services for the appInstance.
		my $serviceTypesRef = $WeathervaneTypes::serviceTypes{$workloadImpl};
		foreach my $serviceType (@$serviceTypesRef) {
			my @services;

			# Get the service instance parameters
			$numDefault      = $appInstanceParamHashRef->{ "num" . ucfirst($serviceType) . "s" };
			my $svcInstanceParamHashRefs =
			  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $numDefault, $serviceType . "s");
			$instancesListRef = $appInstanceParamHashRef->{ $serviceType . "s" };
			$instancesParamHashRefs =
			  Parameters::getInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $instancesListRef, $serviceType . "s" );
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
				$svcInstanceParamHashRef->{"serviceType"} = $serviceType;
				# Create the ComputeResource for the service
				$host = getComputeResourceForInstance( $svcInstanceParamHashRef, $svcNum, $serviceType, \%nameToComputeResourceHash);
				my $service =
				  ServiceFactory->getServiceByType( $svcInstanceParamHashRef, $serviceType, $numScvInstances, $appInstance, $host );
				$service->instanceNum($svcNum);
				$service->host($host);
				push @services, $service;
				
				$svcNum++;
			}

			$appInstance->setServicesByType( $serviceType, \@services );
		}

		# Ask the application which service is the edge service that is directly used by clients.
		# This may affect the configuration of port numbers
		my $edgeService = $appInstance->getEdgeService();
		$weathervane_logger->debug(
			"EdgeService for application $appInstanceNum in workload $workloadNum is $edgeService");
		$appInstanceParamHashRef->{'edgeService'} = $edgeService;

		# Create and add the dataManager
		my $dataManagerParamHashRef =
		  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $appInstanceParamHashRef, "dataManagerInstance");
		if ( $logger->is_debug() ) {
			my $tmp = $json->encode($dataManagerParamHashRef);
			$logger->debug(
				"For workload $workloadNum and appInstance $appInstanceNum, the dataManager instance paramHashRef is:\n"
				  . $tmp );
		}
	
		
		$host = getComputeResourceForInstance( $dataManagerParamHashRef, 1, "dataManager", \%nameToComputeResourceHash);
		my $dataManager = DataManagerFactory->getDataManager( $dataManagerParamHashRef, $appInstance, $host );
		$appInstance->setDataManager($dataManager);
		$dataManager->setAppInstance($appInstance);
		$dataManager->setWorkloadDriver($workloadDriver);
		$dataManager->host($host);

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

# Create the Virtual Infrastructure
my $viParamHashRef = Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $runProcedureParamHashRef, "virtualInfrastructureInstance");
if ( $logger->is_debug() ) {
	my $tmp = $json->encode($viParamHashRef);
	$logger->debug( "The virtualInfrastructure instance paramHashRef is:\n" . $tmp );
}

my $vi = VIFactory->getVI($viParamHashRef);
$runProcedure->setVirtualInfrastructure($vi);

# Set up the virtualInfrastructure Management Hosts
$numDefault      = $viParamHashRef->{"numViMgmtHosts"};
my $viMgmtHostInstanceParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viMgmtHosts");
$instancesListRef = $viParamHashRef->{"viMgmtHosts"};
$instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viMgmtHosts");
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
	my $viMgmtHost = HostFactory->getVIHost($viMgmtHostInstanceParamHashRef);
	$vi->addManagementHost($viMgmtHost);
	$viMgmtHost->setVirtualInfrastructure($vi);
}

# Create all of the virtual infrastructure Hosts
$numDefault      = $viParamHashRef->{"numViHosts"};
my $viHostInstanceParamHashRefs =
  Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viHosts");
$instancesListRef = $viParamHashRef->{"viHosts"};
$instancesParamHashRefs =
  Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viHosts");
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

my $resultsDir = "$outputDir/$seqnum";
`mkdir -p $resultsDir`;
`mv $tmpDir/* $resultsDir/.`;

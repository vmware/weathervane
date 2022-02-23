#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
use Cwd qw();

no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use File::Basename;
use lib dirname (__FILE__) . '/runHarness';

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
use Utils qw(runCmd);

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
	$host->name($hostname);
	$host->initialize();
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
	if ( ( !exists $clusterParamHashRef->{'kubeconfigFile'} ) || ( !defined $clusterParamHashRef->{'kubeconfigFile'} ) ) {
		$console_logger->error("KubernetesCluster $clusterName does not have a kubeconfigFile parameter.  This parameter points to the kubectl config file for the desired context.");
		exit(-1);
	}	
	if ( exists $nameToComputeResourceHashRef->{$clusterName} ) {
		$console_logger->error("All KubernetesCluster definitions must have a unique name.  $clusterName is used for more than one DockerHost or KubernetesCluster.");
		exit(-1);
	}	
	$weathervane_logger->debug("Creating cluster for cluster $clusterName\n");

	my $cluster = HostFactory->getKubernetesCluster($clusterParamHashRef);
	$cluster->name($clusterName);
	$cluster->initialize();
	$runProcedure->addCluster($cluster);
	$nameToComputeResourceHashRef->{$clusterName} = $cluster;
	return $cluster;
}

# This method is used to create the DockerHost when a host is 
# specified for a service but has not been previously created.
sub createDockerHostFromName {
	my ($hostname, $paramsHashRef, $runProcedureParamHashRef, $runProcedure, $nameToComputeResourceHashRef) = @_;
	my $console_logger = get_logger("Console");
	
	my @instancesList = ({ "name" => $hostname,});
    my $hostsParamHashRefs =
  		Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, \@instancesList, "dockerHosts" );
  	my $hostParamHashRef;
  	if (@$hostsParamHashRefs) {
  		$hostParamHashRef = $hostsParamHashRefs->[0];
  	} else {
  		die("Error when trying to create internal structures for host $hostname\n");
  	}

	return createDockerHost($hostParamHashRef, $runProcedure, $nameToComputeResourceHashRef);
}

sub getAppInstanceHostOrCluster {
	my ($appInstanceParamHashRef, $nameToComputeResourceHashRef, $paramsHashRef, $runProcedureParamHashRef, $runProcedure) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane");

	# Get the values for appInstanceHost and appInstanceCluster.
	# There should not be values for both.
	my $appInstanceHostname = $appInstanceParamHashRef->{"appInstanceHost"};
	my $appInstanceClustername = $appInstanceParamHashRef->{"appInstanceCluster"};
	if ($appInstanceHostname && $appInstanceClustername) {
		  $console_logger->error("Both appInstanceHost and appInstanceCluster were specified for an appInstance. You must specify only one.");
		  exit(-1);
	}
	
	if ($appInstanceHostname) {
		if ( ($appInstanceHostname eq "localhost") || ($appInstanceHostname eq "127.0.0.1") ) {
		  $console_logger->error("Hostname $appInstanceHostname was specified for appInstanceHost, but a remotely accessible address must be used.");
		  exit(-1);
		}
		if ( !exists $nameToComputeResourceHashRef->{$appInstanceHostname} ) {
		  $logger->debug("Creating dockerHost $appInstanceHostname specified in appInstanceHost but not in dockerHosts.");
		  return createDockerHostFromName($appInstanceHostname, $paramsHashRef, 
		  		$runProcedureParamHashRef, $runProcedure, $nameToComputeResourceHashRef);
		}
		my $appInstanceHost = $nameToComputeResourceHashRef->{$appInstanceHostname};
		if ((ref $appInstanceHost) eq "KubernetesCluster") {
		  $console_logger->error("Hostname $appInstanceHostname was specified for appInstanceHost, but that host is a KubernetesCluster.");
		  exit(-1);			
		}
		return $appInstanceHost;
	} elsif ($appInstanceClustername) {
		if ( !exists $nameToComputeResourceHashRef->{$appInstanceClustername} ) {
		  $console_logger->error("Cluster $appInstanceClustername was specified for appInstanceCluster, but no KubernetesCluster with that name was defined.");
		  exit(-1);
		}
		my $appInstanceCluster = $nameToComputeResourceHashRef->{$appInstanceClustername};
		if ((ref $appInstanceCluster) eq "DockerHost") {
		  $console_logger->error("Hostname $appInstanceClustername was specified for appInstanceCluster, but that host is a DockerHost.");
		  exit(-1);			
		}
		return $appInstanceCluster;
	} else {
		return "";
	}
}

sub getDriverCluster {
	my ($driverParamHashRef, $nameToComputeResourceHashRef, $paramsHashRef, $runProcedureParamHashRef, $runProcedure) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane");

	# Get the value for driverCluster.
	my $driverClustername = $driverParamHashRef->{"driverCluster"};
    if ($driverClustername) {
		if ( !exists $nameToComputeResourceHashRef->{$driverClustername} ) {
		  $console_logger->error("Cluster $driverClustername was specified for driverCluster, but no KubernetesCluster with that name was defined.");
		  exit(-1);
		}
		my $driverCluster = $nameToComputeResourceHashRef->{$driverClustername};
		if ((ref $driverCluster) eq "DockerHost") {
		  $console_logger->error("Hostname $driverClustername was specified for driverCluster, but that host is a DockerHost.");
		  exit(-1);			
		}
		return $driverCluster;
	} else {
		return "";
	}
}

# Get the host to use for an Instance (driver, dataManager, service, etc) 
sub getComputeResourceForInstance {
	my ($instanceParamHashRef, $instanceNum, $serviceType, 
		$nameToComputeResourceHashRef, $appInstanceHostOrCluster,
		$paramsHashRef, $runProcedureParamHashRef, $runProcedure) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane");
	
	my $appInstanceK8s = "";
	if ($appInstanceHostOrCluster) {
		$appInstanceK8s = (ref $appInstanceHostOrCluster) eq "KubernetesCluster";
	}

	# If the xxxServerHosts was defined for this serviceType, then use 
	# the right host from that list as determined by the instanceNum.
	# The assignment of host to instance wraps if the instanceNum is greater
	# than the number of host names specified.
	if ($instanceParamHashRef->{"${serviceType}Hosts"} && ($#{$instanceParamHashRef->{"${serviceType}Hosts"}} >= 0)) {
		if ($appInstanceK8s) {
			if ($serviceType eq "driver") {
		  		$console_logger->error("Cannot specify ${serviceType}Hosts for instances of type $serviceType when driverCluster is specified.");
			} else {
		  		$console_logger->error("Cannot specify ${serviceType}Hosts for instances of type $serviceType when appInstanceCluster is specified.\n" .
		  							"When running on Kubernetes, all services for an appInstance must run on the same cluster.");				
			}
		  	exit(-1);			
		}

		$logger->debug("getComputeResourceForinstance: For $serviceType instance $instanceNum selecting host from ${serviceType}Hosts");
		my $hostListRef = $instanceParamHashRef->{"${serviceType}Hosts"};
		my $hostListLength = $#{$hostListRef} + 1;
		my $hostListIndex = ($instanceNum - 1) % $hostListLength;
		my $hostname = $hostListRef->[$hostListIndex];
		if ( ($serviceType ne "driver") && (($hostname eq "localhost") || ($hostname eq "127.0.0.1")) ) {
			$console_logger->error("Hostname $hostname was specified in ${serviceType}Hosts, but a remotely accessible address must be used.");
			exit(-1);
		}
		if ( !exists $nameToComputeResourceHashRef->{$hostname} ) {
		  $logger->debug("Creating dockerHost $hostname specified in ${serviceType}Hosts but not in dockerHosts.");
		  return createDockerHostFromName($hostname, $paramsHashRef, 
		  		$runProcedureParamHashRef, $runProcedure, $nameToComputeResourceHashRef);
		}
		$logger->debug("getComputeResourceForinstance: For $serviceType instance $instanceNum selected $hostname from ${serviceType}Hosts");
		my $host = $nameToComputeResourceHashRef->{$hostname};
		if ((ref $host) eq "KubernetesCluster") {
		  $console_logger->error("Hostname $hostname was specified for instance $instanceNum of type $serviceType, but that host is a KubernetesCluster.");
		  exit(-1);			
		}
				
		return $host;		
	}
	
	# At this point we should use the value of appInstanceHostOrCluster.  
	# If not defined, then there is an error.
	if ($appInstanceHostOrCluster) {
		my $hostname = $appInstanceHostOrCluster->name;
		$logger->debug("getComputeResourceForinstance: For $serviceType instance $instanceNum returning $hostname");		
		return $appInstanceHostOrCluster;		
	} else {
		  $console_logger->error("Instance $instanceNum of type $serviceType does not have a hostname defined.\n" . 
		     "You must specify the hostname by defining appInstanceCluster, appInstanceHost, or ${serviceType}Hosts.\n");
		  exit(-1);	
	}
}

# Set weathervaneHome to the current working directory
my $weathervaneHome = Cwd::cwd();
if ( !( -e "$weathervaneHome/weathervane.pl" ) ) {
	die "weathervane.pl does not exist in the current working directory.\n"
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
GetOptions( \%paramCommandLine, @paramStrings )
or die("Error in command line options.\n");

# Check for a request for the help text
if ( exists $paramCommandLine{'help'} ) {
	usage();
	exit;
}

# Check for a request for the help text
if ( exists $paramCommandLine{'fullHelp'} ) {
	fullUsage();
	exit;
}

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
	$configFileName = $weathervaneHome . "/" . $configFileName;
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
		die "Parameter $key in configuration file is not a valid parameter.\n";
	}
}

my $paramsHashRef = mergeParameters( \%paramCommandLine, $paramConfig );

# Read in the fixed configuration
open( FIXEDCONFIGFILE, "<$weathervaneHome/runHarness/fixedConfigs.json" ) or die "Couldn't Open fixedConfigs.json: $!\n";
$paramJson = "";
while (<FIXEDCONFIGFILE>) {
	$paramJson .= $_;
}
close FIXEDCONFIGFILE;
my $fixedConfigs = $json->decode($paramJson);

# Set dirs relative to weathervaneHome
my $outputDir = getParamValue( $paramsHashRef, 'outputDir' );
$outputDir = $weathervaneHome . "/" . $outputDir;
setParamValue( $paramsHashRef, 'outputDir', $outputDir );

my $distDir         = getParamValue( $paramsHashRef, 'distDir' );
$distDir = $weathervaneHome . "/" . $distDir;
setParamValue( $paramsHashRef, 'distDir', $distDir );

my $sequenceNumberFile = getParamValue( $paramsHashRef, 'sequenceNumberFile' );
$sequenceNumberFile = $outputDir . "/" . $sequenceNumberFile;
setParamValue( $paramsHashRef, 'sequenceNumberFile', $sequenceNumberFile );

my $configDir = getParamValue( $paramsHashRef, 'configDir');
$configDir = $weathervaneHome . "/" . $configDir;
setParamValue( $paramsHashRef, 'configDir', $configDir);

my $dbLoaderDir = getParamValue( $paramsHashRef, 'dbLoaderDir' );
$dbLoaderDir = $weathervaneHome . "/" . $dbLoaderDir;
setParamValue( $paramsHashRef, 'dbLoaderDir', $dbLoaderDir);

my $resultsFileDir = getParamValue( $paramsHashRef, 'resultsFileDir' );
if ( $resultsFileDir eq "" ) {
	$resultsFileDir = $weathervaneHome;
}
else {
	$resultsFileDir = $weathervaneHome . "/" . $resultsFileDir;
}
setParamValue( $paramsHashRef,  'resultsFileDir', $resultsFileDir );

my $workloadDriverDir = getParamValue( $paramsHashRef, 'workloadDriverDir');
$workloadDriverDir = $weathervaneHome . "/" . $workloadDriverDir;
setParamValue( $paramsHashRef,  'workloadDriverDir', $workloadDriverDir );

my $workloadProfileDir = getParamValue( $paramsHashRef, 'workloadProfileDir');
$workloadProfileDir = $weathervaneHome . "/" . $workloadProfileDir;
setParamValue( $paramsHashRef,  'workloadProfileDir', $workloadProfileDir );

my $gcviewerDir = getParamValue( $paramsHashRef, 'gcviewerDir');
$gcviewerDir = $weathervaneHome . "/" . $gcviewerDir;
setParamValue( $paramsHashRef,  'gcviewerDir', $gcviewerDir );

# Make sure required directories exist
if ( !( -e $outputDir ) ) {
	my ($cmdFailed, $cmdOutput) = runCmd("mkdir -p $outputDir");
	if ($cmdFailed) {
		die "outputDir mkdir failed: $cmdFailed\n";
	}
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

my $tmpDir = "$outputDir/$seqnum";
setParamValue( $paramsHashRef, 'tmpDir', $tmpDir );
my ($cmdFailed, $cmdOutput) = runCmd("mkdir -p $tmpDir");
if ($cmdFailed) {
	die "tmpDir mkdir failed: $cmdFailed\n";
}

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

tie *STDERR, "StderrToLogerror", category => "Console";
my $logger = get_logger("Weathervane");

# Update logger levels based on config
if ( getParamValue( $paramsHashRef, "loggers" ) ) {
	my $loggersHashRef = getParamValue( $paramsHashRef, "loggers" );
	my @keys = keys %$loggersHashRef;
	foreach my $loggerName ( keys %$loggersHashRef ) {
		my $loggerInst = get_logger($loggerName);
		$loggerInst->level( $loggersHashRef->{$loggerName} );
	}
}

if ($resultsFileDir != $weathervaneHome) {
	if ( !( -e $resultsFileDir ) ) {
		my ($cmdFailed, $cmdOutput) = runCmd("mkdir -p $resultsFileDir");
		if ($cmdFailed) {
			die "resultFileDir mkdir failed: $cmdFailed\n";
		}
	}
}

# Copy the version file into the output directory
my ($cmdFailed, $cmdOutput) = runCmd("cp $weathervaneHome/version.txt $tmpDir/version.txt");
if ($cmdFailed) {
	die "version cp failed: $cmdFailed\n";
}

# Save the original config file and processed command line parameters
my $saveConfigFile = $tmpDir . "/" . basename($configFileName) . ".save";
my ($cmdFailed, $cmdOutput) = runCmd("cp $configFileName $saveConfigFile");
if ($cmdFailed) {
	die "config cp failed: $cmdFailed\n";
}
open PARAMCOMMANDLINEFILE, ">$tmpDir/paramCommandLine.save";
print PARAMCOMMANDLINEFILE $json->encode(\%paramCommandLine);
close PARAMCOMMANDLINEFILE;

# Save the fixedConfigs.conf file
$saveConfigFile = $tmpDir . "/fixedConfigs.json.save";
($cmdFailed, $cmdOutput) = runCmd("cp $weathervaneHome/runHarness/fixedConfigs.json $saveConfigFile");
if ($cmdFailed) {
	die "fixedConfigs cp failed: $cmdFailed\n";
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

my $version = `cat $weathervaneHome/version.txt`;
chomp($version);
$console_logger->warn( "Weathervane Version $version" );
if (!getParamValue($paramsHashRef, "dockerWeathervaneVersion")) {	
	setParamValue( $paramsHashRef, "dockerWeathervaneVersion",  $version );
}

$console_logger->info("Command-line parameters:");
foreach my $key ( keys %paramCommandLine ) {
	$console_logger->info( "\t$key: " . $paramCommandLine{$key} );
}

$console_logger->warn( "Writing output to $tmpDir" );

# if we are stopping a run, then use the singlefixed run manager
my $stop = getParamValue( $paramsHashRef, "stop" );
if ($stop) {
	setParamValue( $paramsHashRef, "runProcedure", 'stop' );
}

# If we are running the findMax or findMaxMultiRun runStrategy (they are the same thing)
# then set exitOnFirstFailure to true
if ((getParamValue($paramsHashRef, "runStrategy") eq 'findMax') 
		|| (getParamValue($paramsHashRef, "runStrategy") eq 'findMaxMultiRun')) {
	setParamValue( $paramsHashRef, "exitOnFirstFailure",  1);
}

if (getParamValue($paramsHashRef, "numQosPeriods") <= 0) {
	die("The value for the numQosPeriods parameter must be greater than 0.\n");
}

if (getParamValue($paramsHashRef, "qosPeriodSec") <= 0) {
	die("The value for the qosPeriodSec parameter must be greater than 0.\n");
}

if (getParamValue( $paramsHashRef, "findMaxStopPct" ) <= 0) {
	die "The value for findMaxStopPct must be greater than 0.\n";
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
my @clusters;
foreach my $paramHashRef (@$clustersParamHashRefs) {
	$logger->debug( "For kubernetesCluster ", $paramHashRef->{'name'}, " the Param hash ref is:" );
	my $tmp = $json->encode($paramHashRef);
	$logger->debug($tmp);
	my $cluster = createKubernetesCluster( $paramHashRef, $runProcedure, \%nameToComputeResourceHash );
	push @clusters, $cluster;
}

# If using clusterip for appIngressMethod, make sure that all specified
# kubernetesClusters actually refer to the same cluster
if (getParamValue( $paramsHashRef, "appIngressMethod" ) eq "clusterip") {
	foreach my $thisCluster (@clusters) {
		foreach my $thatCluster (@clusters) {
			if (!($thisCluster->equals($thatCluster))) {
				$console_logger->error("When using clusterip for appIngressMethod, all components must run on the same Kubernetes cluster.\n");
				exit(1);
			}
		}
	}	
}

# Get the parameters for the workload instances
my $numDefault      = $runProcedureParamHashRef->{"numWorkloads"};
$instancesListRef = $runProcedureParamHashRef->{"workloads"};
my $workloadsParamHashRefs;
if ($numDefault > 0) {
	if ($#{$instancesListRef} >= 0) {
		$console_logger->info("Specifying both numWorkloads > 1 and the workloads parameter is not supported.\n"
				. "In order to specify workload instances with the workloads parameter, you must explicitly set numWorkloads to 0.");
		exit -1;
	}
  	$workloadsParamHashRefs =
  		Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $numDefault, "workloads" );
} else {
  	$workloadsParamHashRefs =
    	Parameters::getInstanceParamHashRefs( $paramsHashRef, $runProcedureParamHashRef, $instancesListRef, "workloads" );
}

my $numWorkloads = $#{$workloadsParamHashRefs} + 1;
if ( $logger->is_debug() ) {
	$logger->debug("Have $numWorkloads workloads");
	$logger->debug("Their Param hash refs are:");
	foreach my $paramHashRef (@$workloadsParamHashRefs) {
		my $tmp = $json->encode($paramHashRef);
		$logger->debug($tmp);
	}
}
$console_logger->info("Run Configuration has $numWorkloads workload(s).");

# Create the workload instances and all of their sub-parts
my $workloadNum = 1;
my @workloads;
foreach my $workloadParamHashRef (@$workloadsParamHashRefs) {
	my $outputWorkloadNum = ($numWorkloads == 1 ? undef : $workloadNum);
	
	my $configSize = $workloadParamHashRef->{'configurationSize'};
	# Check that the configurationSize is one of those allowed for this workload
	my $workloadImpl = $workloadParamHashRef->{'workloadImpl'};
	my $validSizesRef = $WeathervaneTypes::appInstanceSizes{$workloadImpl};
	if (!($configSize ~~  @$validSizesRef)) {
			$console_logger->error("Error: For workload " . $outputWorkloadNum . ", "
				. $configSize . " is not a valid configurationSize.  Valid sizes are: @$validSizesRef");
			exit(1);		
	}
	# Overwrite the workload's parameters with those specified by the configuration size.
	if ($configSize ne "custom") {
		my @configKeys = keys $fixedConfigs;
		if (!($configSize ~~ @configKeys)) {
			$console_logger->error("Error: For workload " . $outputWorkloadNum 
				.  " configurationSize " . $configSize . " does not exist.");
			exit(1);
		}
		my $config = $fixedConfigs->{$configSize};
		foreach my $key (keys %$config) {
			if ($key eq "numDrivers") {
				# If the user set the number of drivers, then use that value.
				# Otherwise the number of drivers is the number in the
				# fixed config times the number of appInstances
				if (!$workloadParamHashRef->{"numDrivers"} && ($#{$workloadParamHashRef->{"drivers"}} < 0)) {
					my $numAppInstances = $workloadParamHashRef->{"numAppInstances"};
					if (!$numAppInstances) {
						my $instancesListRef = $workloadParamHashRef->{"appInstances"};
						$numAppInstances = $#{$instancesListRef} + 1;					
					}
					$workloadParamHashRef->{$key} = $config->{$key} * $numAppInstances;
				}
			} elsif (($key ne "users") && ($key ne "maxUsers")){
				$workloadParamHashRef->{$key} = $config->{$key};
			}
		}
	}

	my $workload = WorkloadFactory->getWorkload($workloadParamHashRef);

	$workload->{workloadCount} = $numWorkloads; # DELETE
	my $TEST = $workload->workloadCount; # DELETE
	print "TESTing $TEST\n"; # DELETE

	$workload->instanceNum($workloadNum);
	$workload->initialize();
	push @workloads, $workload;

	# Get the paramHashRefs for the appInstances
	$numDefault      = $workloadParamHashRef->{"numAppInstances"};
	$instancesListRef = $workloadParamHashRef->{"appInstances"};
	my $appInstanceParamHashRefs;
	if ($numDefault > 0) {
		if ($#{$instancesListRef} >= 0) {
			$console_logger->info("Specifying both numAppInstances > 1 and the appInstances parameter is not supported.");
			$console_logger->info("If using appInstances, you must set numAppInstances to 0.");
			exit -1;
		}
		$appInstanceParamHashRefs = 
	  		Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault, "appInstances");
	} else {
		$appInstanceParamHashRefs =
		  Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef, "appInstances");
	}
	
	my $numAppInstances = $#{$appInstanceParamHashRefs} + 1;
	if ( $logger->is_debug() ) {
		$logger->debug("For workload $outputWorkloadNum, have $numAppInstances appInstances");
		#$logger->debug("Their Param hash refs are:");
		#foreach my $paramHashRef (@$appInstanceParamHashRefs) {
		#	my $tmp = $json->encode($paramHashRef);
		#	$logger->debug($tmp);
		#}
	}

	# Get the parameters for the driver instances
	$numDefault      = $workloadParamHashRef->{"numDrivers"};
	$instancesListRef = $workloadParamHashRef->{"drivers"};
	my $driversParamHashRefs;
	if ($numDefault > 0) {
		if ($#{$instancesListRef} >= 0) {
			$console_logger->info("Specifying both numDrivers > 1 and the drivers parameter is not supported.");
			exit -1;
		}
		$driversParamHashRefs =
		  	Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $numDefault, "drivers");
	} else {
		$driversParamHashRefs =
	 		Parameters::getInstanceParamHashRefs( $paramsHashRef, $workloadParamHashRef, $instancesListRef, "drivers");
	}
	
	if ( $#$driversParamHashRefs < 0 ) {
		$console_logger->error(
"Workload $outputWorkloadNum does not have any drivers.  Specify at least one workload driver using either the numDrivers or drivers parameters."
		);
		exit(-1);
	}

	# The first driver is the primary driver.  The others are secondaries
	my $driverNum = 1;
	my $primaryDriverParamHashRef = shift @$driversParamHashRefs;
	
	if ( $logger->is_debug() ) {
		my $tmp = $json->encode($primaryDriverParamHashRef);
		$logger->debug( "For workload $outputWorkloadNum, the primary driver instance paramHashRef is:\n" . $tmp );
	}

	# Create the primary workload driver
	my $driverCluster = getDriverCluster($primaryDriverParamHashRef, \%nameToComputeResourceHash, 
										$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
	my $host = getComputeResourceForInstance( $primaryDriverParamHashRef, $driverNum, "driver", 
					\%nameToComputeResourceHash, $driverCluster, 
					$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
	my $workloadDriver = WorkloadDriverFactory->getWorkloadDriver($primaryDriverParamHashRef, $host, $numWorkloads);
	$workloadDriver->host($host);
	$workloadDriver->setWorkload($workload);
	$workloadDriver->instanceNum($driverNum);
	$workloadDriver->initialize(1);
	$driverNum++;

	# Add the primary driver to the workload
	$workload->setPrimaryDriver($workloadDriver);

	my $numSecondaries = $#{$driversParamHashRefs} + 1;
	if ( $logger->is_debug() ) {
		$logger->debug("For workload $outputWorkloadNum, have $numSecondaries secondary drivers");
		#$logger->debug("Their Param hash refs are:");
		#foreach my $paramHashRef (@$driversParamHashRefs) {
		#	my $tmp = $json->encode($paramHashRef);
		#	$logger->debug($tmp);
		#}
	}

	my $numDrivers = $numSecondaries + 1;
	$console_logger->info("Workload $outputWorkloadNum has $numDrivers workload-driver nodes");

	# Create the secondary drivers and add them to the primary driver
	foreach my $secondaryDriverParamHashRef (@$driversParamHashRefs) {
		$host = getComputeResourceForInstance( $secondaryDriverParamHashRef, $driverNum, 
												"driver", \%nameToComputeResourceHash, $driverCluster,
												$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
		my $secondary = WorkloadDriverFactory->getWorkloadDriver($secondaryDriverParamHashRef, $host, $numWorkloads);
		$secondary->host($host);
		$secondary->instanceNum($driverNum);
		$secondary->setWorkload($workload);
		$secondary->initialize(0);
		$driverNum++;

		# Add the secondary driver to the primary
		$workloadDriver->addSecondary($secondary);
	}

	# Now that the configuration of the workloadDriver is complete, ask it to check whether the
	# configuration is valid for its workload type
	if ( !$workloadDriver->checkConfig() ) {
		$console_logger->error(
			"The configuration of the workload drivers is invalid for workload type $workloadImpl");
		exit(-1);
	}

	# Check if all instances have the same configuration, and if 
	# so only print configuration once to the console
	my $allAiSameConfig = 1;
	my $commonConfigSize = "";
	foreach my $appInstanceParamHashRef (@$appInstanceParamHashRefs) {
		my $configSize = $appInstanceParamHashRef->{'configurationSize'};
		if (!$commonConfigSize) {
			$commonConfigSize = $configSize;
		} else {
			if ($configSize ne $commonConfigSize) {
				$allAiSameConfig = 0;
				last;
			}
		}
	}
	if ($allAiSameConfig && ($commonConfigSize ne "custom")) {
		$console_logger->info("Workload $outputWorkloadNum has $numAppInstances $commonConfigSize application instances:");
		my $appInstanceParamHashRef = $appInstanceParamHashRefs->[0];
		my $serviceTypesRef = $WeathervaneTypes::serviceTypes{$workloadImpl};
		foreach my $serviceType (@$serviceTypesRef) {
			my @services;
			my $numScvInstances      = $appInstanceParamHashRef->{ "num" . ucfirst($serviceType) . "s" };
			$console_logger->info( "\t$numScvInstances " . ucfirst($serviceType) . "s" );
		}		
	} else {
		$console_logger->info("Workload $outputWorkloadNum has $numAppInstances application instances.");
	}

	# Create the appInstances and add them to the workload
	my @appInstances;
	my $appInstanceNum = 1;    # Count appInstances so that each gets a unique suffix
	foreach my $appInstanceParamHashRef (@$appInstanceParamHashRefs) {
		if (!$allAiSameConfig || ($commonConfigSize eq "custom")) {
			$console_logger->info("Workload $outputWorkloadNum, Application Instance $appInstanceNum configuration:");
		}
		
		my $users = shift @usersList;
		if ( defined $users ) {
			$appInstanceParamHashRef->{'users'} = $users;
		}

		# Overwrite the appInstance's parameters with those specified by the configuration size.
		my $configSize = $appInstanceParamHashRef->{'configurationSize'};
		if ($configSize ne "custom") {
			my @configKeys = keys $fixedConfigs;
			if (!($configSize ~~ @configKeys)) {
				$console_logger->error("Error: For appInstance " . $appInstanceNum 
					.  " configurationSize " . $configSize . " does not exist.");
			}
			my $config = $fixedConfigs->{$configSize};
			foreach my $key (keys %$config) {
			  if ((($key ne "users") || !$appInstanceParamHashRef->{"users"})
			  		&& (($key ne "maxUsers") || !$appInstanceParamHashRef->{"maxUsers"})) {
				$appInstanceParamHashRef->{$key} = $config->{$key};
			  }
			}
		}

		my $appInstanceHostOrCluster = 
			getAppInstanceHostOrCluster($appInstanceParamHashRef, \%nameToComputeResourceHash, 
										$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
		my $appInstance = AppInstanceFactory->getAppInstance($appInstanceParamHashRef, $appInstanceHostOrCluster);
		$appInstance->instanceNum($appInstanceNum);
		$appInstance->workload($workload);
		$appInstance->host($appInstanceHostOrCluster);
		$appInstance->initialize();
		push @appInstances, $appInstance;
		
		# Create and add all of the services for the appInstance.
		my $serviceTypesRef = $WeathervaneTypes::serviceTypes{$workloadImpl};
		foreach my $serviceType (@$serviceTypesRef) {
			my @services;

			# Get the service instance parameters
			$numDefault      = $appInstanceParamHashRef->{ "num" . ucfirst($serviceType) . "s" };
			$instancesListRef = $appInstanceParamHashRef->{ $serviceType . "s" };
			my $svcInstanceParamHashRefs;
			if ($numDefault > 0) {
				if ($#{$instancesListRef} >= 0) {
					$console_logger->info("Specifying both num" . ucfirst($serviceType) 
						. "s > 1 and the ${serviceType}s parameter is not supported.");
					exit -1;
				}
				$svcInstanceParamHashRefs =
			 		Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $numDefault, $serviceType . "s");
			} else { 
				$svcInstanceParamHashRefs =
				  	Parameters::getInstanceParamHashRefs( $paramsHashRef, $appInstanceParamHashRef, $instancesListRef, $serviceType . "s" );
			}
			my $numScvInstances = $#{$svcInstanceParamHashRefs} + 1;
			if ( $logger->is_debug() ) {
				$logger->debug(
					"For workload $outputWorkloadNum and appInstance $appInstanceNum, have $numScvInstances ${serviceType}s."
				);
				#$logger->debug("Their Param hash refs are:");
				#foreach my $paramHashRef (@$svcInstanceParamHashRefs) {
				#	my $tmp = $json->encode($paramHashRef);
				#	$logger->debug($tmp);
				#}
			}
			if (!$allAiSameConfig || ($commonConfigSize eq "custom")) {
				$console_logger->info( "\t$numScvInstances " . ucfirst($serviceType) . "s" );
			}
			
			# Create the service instances and add them to the appInstance
			my $svcNum = 1;
			foreach my $svcInstanceParamHashRef (@$svcInstanceParamHashRefs) {
				$svcInstanceParamHashRef->{"serviceType"} = $serviceType;
				# Create the ComputeResource for the service
				$host = getComputeResourceForInstance( $svcInstanceParamHashRef, $svcNum, 
										$serviceType, \%nameToComputeResourceHash, $appInstanceHostOrCluster,
											$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
				my $service =
				  ServiceFactory->getServiceByType( $svcInstanceParamHashRef, $serviceType, $numScvInstances, $appInstance, $host );
				$service->instanceNum($svcNum);
				$service->host($host);
				$service->initialize();
				push @services, $service;
				
				$svcNum++;
			}

			$appInstance->setServicesByType( $serviceType, \@services );
		}

		# Ask the application which service is the edge service that is directly used by clients.
		# This may affect the configuration of port numbers
		my $edgeService = $appInstance->getEdgeService();
		$weathervane_logger->debug(
			"EdgeService for application $appInstanceNum in workload $outputWorkloadNum is $edgeService");
		$appInstanceParamHashRef->{'edgeService'} = $edgeService;

		# Create and add the dataManager
		my $dataManagerParamHashRef =
		  Parameters::getSingletonInstanceParamHashRef( $paramsHashRef, $appInstanceParamHashRef, "dataManagerInstance");
		#if ( $logger->is_debug() ) {
		#	my $tmp = $json->encode($dataManagerParamHashRef);
		#	$logger->debug(
		#		"For workload $workloadNum and appInstance $appInstanceNum, the dataManager instance paramHashRef is:\n"
		#		  . $tmp );
		#}
	
		
		$host = getComputeResourceForInstance( $dataManagerParamHashRef, 1, "dataManager", 
								\%nameToComputeResourceHash, $appInstanceHostOrCluster, 
									$paramsHashRef, $runProcedureParamHashRef, $runProcedure);
		my $dataManager = DataManagerFactory->getDataManager( $dataManagerParamHashRef, $appInstance, $host );
		$appInstance->setDataManager($dataManager);
		$dataManager->setAppInstance($appInstance);
		$dataManager->setWorkloadDriver($workloadDriver);
		$dataManager->host($host);
		$dataManager->initialize();

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
$instancesListRef = $viParamHashRef->{"viMgmtHosts"};
my $viMgmtHostInstanceParamHashRefs;
if ($numDefault > 0) {
	if ($#{$instancesListRef} >= 0) {
		$console_logger->info("Specifying both numViMgmtHosts > 1 and the viMgmtHosts parameter is not supported.");
		exit -1;
	}
	$viMgmtHostInstanceParamHashRefs =
  		Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viMgmtHosts");
} else {
	$viMgmtHostInstanceParamHashRefs =
  		Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viMgmtHosts");
}

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
$instancesListRef = $viParamHashRef->{"viHosts"};
my $viHostInstanceParamHashRefs;
if ($numDefault > 0) {
	if ($#{$instancesListRef} >= 0) {
		$console_logger->info("Specifying both numViHosts > 1 and the viHosts parameter is not supported.");
		exit -1;
	}
	$viHostInstanceParamHashRefs =
  		Parameters::getDefaultInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $numDefault, "viHosts");
} else {
	$viHostInstanceParamHashRefs =
  		Parameters::getInstanceParamHashRefs( $paramsHashRef, $viParamHashRef, $instancesListRef, "viHosts");
}

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
	$viHost->name($viHostInstanceParamHashRef->{'name'});
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

# Zip the debug log
$weathervane_logger->remove_appender("rootDebugFile");
($cmdFailed, $cmdOutput) = runCmd("gzip $tmpDir/debug.log");

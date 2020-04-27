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
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

my $accept = '';
my $configFile = 'weathervane.config';
my $version = '2.0.0';
my $outputDir = 'output';
my $tmpDir = '';
my $backgroundScript = '';
my $mapSsh = '';
my $fixedConfigsFile = "";
my $scriptPeriodSec = 60;
my $help = '';

if ((-e "./version.txt") && (-f "./version.txt")) {
  $version = `cat ./version.txt`;
  chomp($version);	
} 
my $defaultVersion = $version;

GetOptions(	'accept!' => \$accept,
			'configFile=s' => \$configFile,
			'outputDir=s' => \$outputDir,
			'version=s' => \$version,
			'tmpDir=s' => \$tmpDir,
			'script=s' => \$backgroundScript,
			'fixedConfigsFile=s' => \$fixedConfigsFile,
			'scriptPeriod=i' => \$scriptPeriodSec,
			'mapSsh!' => $mapSsh,
			'help!' => \$help,
		);
		
my $wvCommandLineArgs = join(" ", @ARGV);

sub usage {
    print "Usage: ./runWeathervane.pl [options] [-- parameters]\n";
	print "\nThis script is used to run the Weathervane benchmark using the configuration specified in a configuration file.\n";
	print "It takes the following options:\n";
	print "--configFile: This specifies the configuration file used to control the Weathervane run.\n";
	print "              If this parameter is not a fully-qualified file name starting with a \/ then\n";
	print "              the location of the file is assumed to be relative to the directory in which\n";
	print "              this script was invoked.\n";
	print "              For a description of the Weathervane configuration file, please see the \n";
	print "              Weathervane User's Guide\n";
	print "              default value: weathervane.config\n";
	print "--version:    The version of Weathervane to use.  This will override the default version\n";
	print "              number to use for the Weathervane container images.\n";
	print "              default value: $defaultVersion\n";
	print "--outputDir:  The directory in which to store the output from the Weathervane run.  You should\n";
	print "              use the same directory for all runs. Output is only placed in this directory\n";
	print "              at the end of a run.  The directory is created if it does not exist.\n";
	print "              If this parameter is not a fully-qualified file name starting with a \/ then\n";
	print "              the location of the file is assumed to be relative to the directory in which\n";
	print "              this script was invoked.\n";
	print "              default value: output\n";
	print "--tmpDir:     The directory in which to store temporary output created during the run.\n";
	print "              This information can be helpful when troubleshooting runs which do not complete\n";
	print "              properly.  The directory is created if it does not exist.\n";
	print "              If this parameter is not a fully-qualified file name starting with a \/ then\n";
	print "              the location of the file is assumed to be relative to the directory in which\n";
	print "              this script was invoked.\n";
	print "              default value: None.  If no value is specified the temporary files are stored\n";
	print "                             inside the Weathervane container.\n";
	print "--script:     The path to a script that should be run every scriptPeriod seconds.\n";
	print "              The script may be used to refresh the credentials in the kubeconfig file\n";
	print "              or to trigger external stats collection.\n";
	print "              If this parameter is not a fully-qualified file name starting with a \/ then\n";
	print "              the location of the file is assumed to be relative to the directory in which\n";
	print "              this script was invoked.\n";
	print "              default value: None.\n";
	print "--scriptPeriod: The frequency at which the script should be run in seconds.\n";
	print "              default value: 60\n";
	print "--mapSsh:     Causes the user's \$HOME/.ssh directory to be mapped into the run harness container.\n";
	print "              This is only needed when collecting esxtop data, which requires passwordless ssh.\n";
	print "              default value: False\n";
	print "--accept:     Accepts the terms of the Weathervane license.  Useful when running this script\n";
	print "              from another script.  Only needs to be specified on the first run in a given directory.\n";
	print "              default value: None.  If no value is specified the user is prompted to accept the\n";
	print "                             license terms.\n";
	print "--help:       Displays this text.\n";
	print "\n";
	print "To pass command-line parameters to the Weathervane run harness, enter them following two dashes\n";
	print "after the options.  For example, to stop the services from a previous run you would use:\n";
	print "./runWeathervane.pl --configFile=weathervane.config -- --stop\n";
}

sub parseConfigFile {
	my ($configFileName) = @_;
	
	# Read in the config file
	open( CONFIGFILE, "<$configFileName" ) or die "Couldn't open configuration file $configFileName: $!\n";

	my @k8sConfigFiles;
	my $dockerNamespace;
	while (<CONFIGFILE>) {
		if ($_ =~ /^\s*"kubeconfigFile"\s*\:\s*"(.*)"\s*,/) {
			if ((! -e $1) || (! -f $1)) {
				print "The kubeconfigFile $1 must exist and be a regular file.\n";
				usage();
				exit 1;									
			}
			if (!($1 ~~ @k8sConfigFiles)) {
				push(@k8sConfigFiles, $1);
			}
		} elsif ($_ =~ /^\s*"dockerNamespace"\s*\:\s*"(.*)"\s*,/) {
			$dockerNamespace = $1;
		} elsif ($_ =~ /useLoadBalancer/) {
			print "The useLoadBalancer parameter has been replaced with the appIngressMethod parameter. " . 
				"You must update your configuration file.\n" .
				"Please refer to the Weathervane User's Guide for information on setting the appIngressMethod parameter.\n";
			exit(1);
		}
	}
	close CONFIGFILE;
		
	if (!$dockerNamespace) {
		print "You must specify the dockerNamespace parameter in configuration file $configFileName.\n";
		usage();
		exit 1;									
	}
	
	my @return = (\@k8sConfigFiles, $dockerNamespace);
	
	return \@return;
}

sub parseKubeconfigFile {
	my ($configFileName) = @_;
	
	# Read in the config file
	open( CONFIGFILE, "<$configFileName" ) or die "Couldn't open configuration file $configFileName: $!\n";
	my @files;
	my $dockerNamespace;
	while (<CONFIGFILE>) {
		if ($_ =~ /^\s*[a-zA-Z0-9\-_]+:\s*(\/.*)$/) {
			push @files, $1;
		}
	}
	close CONFIGFILE;
		
	return \@files;
}
		
sub dockerExists {
	my ( $name ) = @_;
	my $out = `docker ps -a`;
	my @lines = split /\n/, $out;
	my $found = 0;
	foreach my $line (@lines) {	
		if ($line =~ /\s+$name\s*$/) {
			$found = 1;
			last;
		}
	}
	return $found;
}

sub runPeriodicScript {
	`$backgroundScript`;
	my $pid = fork();
	if (!defined $pid ) {
		die("Couldn't fork a process to run background script: $!\n");
	} elsif ( $pid == 0 ) {
		while (1) {
			`$backgroundScript`;
			sleep($scriptPeriodSec);
		}
		exit;
	}
	return $pid;
}

# Force acceptance of the license if not using the accept parameter
sub forceLicenseAccept {
	open( my $fileout, "./Notice.txt" ) or die "Can't open file ./Notice.txt: $!\n";
	while ( my $inline = <$fileout> ) {
		print $inline;
	}

	print "Do you accept these terms and conditions (yes/no)? ";
	my $answer = <STDIN>;
	chomp($answer);
	$answer = lc($answer);
	while ( ( $answer ne "yes" ) && ( $answer ne "no" ) ) {
		print "Please answer yes or no: ";
		$answer = <STDIN>;
		chomp($answer);
		$answer = lc($answer);
	}
	if ( $answer eq "yes" ) {
		open( my $file, ">./.accept-weathervane" ) or die "Can't create file ./.accept-weathervane: $!\n";
		close $file;
	}
	else {
		exit -1;
	}
	
}

if ($help) {
	usage();
	exit 0;
}

unless ( -e "./.accept-weathervane" ) {
	if ($accept) {
		open( my $file, ">./.accept-weathervane" ) or die "Can't create file ./.accept-weathervane: $!\n";
		close $file;
	}
	else {
		forceLicenseAccept();
	}
}

if (!(-e $configFile)) {
	print "You must specify a valid configuration file using the configFile parameter.  The file $configFile does not exist.\n";
	usage();
	exit 1;									
}
if (!(-f $configFile)) {
	print "The Weathervane configuration file $configFile must not be a directory.\n";
	usage();
	exit 1;									
}
# If the configFile does not reference a file with an absolute path, 
# then make it an absolute path relative to the local dir
my $pwd = `pwd`;
chomp($pwd);
if (!($configFile =~ /\//)) {
	$configFile = "$pwd/$configFile";	
}

# If the outputDir does not reference a directory with an absolute path, 
# then make it an absolute path relative to the local dir
if (!($outputDir =~ /\//)) {
	$outputDir = "$pwd/$outputDir";	
}
if (!(-e $outputDir)) {
	`mkdir -p $outputDir`;
}
if (!(-d $outputDir)) {
	print "The Weathervane output directory $outputDir must be a directory.\n";
	usage();
	exit 1;									
}
my $outputMountString = "-v $outputDir:/root/weathervane/output";

# Mounting the tmpDir is optional.
my $tmpMountString = "";
if ($tmpDir) {
	# If the tmpDir does not reference a directory with an absolute path, 
	# then make it an absolute path relative to the local dir
	if (!($tmpDir =~ /\//)) {
		$tmpDir = "$pwd/$tmpDir";	
	}
	if (!(-e $tmpDir)) {
		`mkdir -p $tmpDir`;
	}
	if (!(-d $tmpDir)) {
		print "The Weathervane tmp directory $tmpDir must be a directory.\n";
		usage();
		exit 1;									
	}
	$tmpMountString = "-v $tmpDir:/root/weathervane/tmpLog";
}

if ($backgroundScript) {
	# If the $backgroundScript does not reference a file with an absolute path, 
	# then make it an absolute path relative to the local dir
	if (!($backgroundScript =~ /\//)) {
		$backgroundScript = "$pwd/$backgroundScript";	
	}
	if (!(-e $backgroundScript)) {
		die "The script $backgroundScript does not exist.\n";
	}
	if (!(-f $backgroundScript)) {
		print "The script $backgroundScript must be a file.\n";
		exit 1;									
	}
	if (!(-x $backgroundScript)) {
		print "The script $backgroundScript must be a executable.\n";
		exit 1;									
	}
}

if (dockerExists("weathervane")) {
    `docker rm -vf weathervane`;
}

my $resultsFile = "$pwd/weathervaneResults.csv";
if (!(-e $resultsFile)) {
	`touch $resultsFile`;
} elsif (-d $resultsFile) {
	die "The file $resultsFile must be an ordinary file";
}

my $homeDir = $ENV{'HOME'};
my $sshMountString = "";
if ($mapSsh && (-e "$homeDir/.ssh") && (-d "$homeDir/.ssh")) {
    $sshMountString = "-v $homeDir/.ssh:/root/.ssh";
}

my $retRef = parseConfigFile($configFile);
my $k8sConfigFilesRef = $retRef->[0];
my $dockerNamespace = $retRef->[1];

my $k8sConfigMountString = "";
foreach my $k8sConfig (@$k8sConfigFilesRef) {
	# If the config file doesn't have an absolute path, 
	# then mount it in /root/weathervane
	if ($k8sConfig =~ /^\//) {
		$k8sConfigMountString .= "-v $k8sConfig:$k8sConfig ";				
	} else {
		$k8sConfigMountString .= "-v $k8sConfig:/root/weathervane/$k8sConfig ";		
	}
	
	# Also mount any files that are referenced in the kubeconfig file
	my $kubeconfigFilesRef = parseKubeconfigFile($k8sConfig);
	foreach my $file (@$kubeconfigFilesRef) {
		$k8sConfigMountString .= "-v $file:$file ";		
	}
}



my $configMountString = "-v $configFile:/root/weathervane/weathervane.config";
my $resultsMountString = "-v $resultsFile:/root/weathervane/weathervaneResults.csv";

my $fixedConfigsMountString = "";
if ($fixedConfigsFile) {
	# If the fixedConfigsFile does not reference a file with an absolute path, 
	# then make it an absolute path relative to the local dir
	if (!($fixedConfigsFile =~ /\//)) {
		$fixedConfigsFile = "$pwd/$fixedConfigsFile";	
	}
	if (!(-e "$fixedConfigsFile") || !(-f "$fixedConfigsFile")) {
		die "fixedConfigsFile $fixedConfigsFile must exist\n";
	} else {
		$fixedConfigsMountString = "-v $fixedConfigsFile:/root/weathervane/runHarness/fixedConfigs.json";
	}
}

my $tz = `date +%Z`;
chomp($tz);
my $tzEnvString = "-e TZ=$tz";

# Stop an existing run harness container
if (dockerExists("weathervane")) {
    `docker rm -vf weathervane`;
}

my $pid = '';
if ($backgroundScript) {
	print "Running script $backgroundScript every $scriptPeriodSec seconds.\n";
	$pid = runPeriodicScript();
}

# make sure the docker image is up-to-date
print "Starting Weathervane Run-Harness.  Pulling container image may take a few minutes.\n";
`docker pull $dockerNamespace/weathervane-runharness:$version`;

my $cmdString = "docker run --name weathervane --net host $tzEnvString --rm -d -w /root/weathervane " 
		. "$configMountString $resultsMountString $k8sConfigMountString $fixedConfigsMountString " 
		. "$outputMountString $tmpMountString $sshMountString " 
		. "$dockerNamespace/weathervane-runharness:$version $wvCommandLineArgs";
my $dockerId = `$cmdString`;

my $pipeString = "docker logs --follow weathervane |";
my $pipePid = open my $driverPipe, "$pipeString"
	  or die "Can't open docker logs pipe ($pipeString) : $!\n";

my $inline;
while ( $driverPipe->opened() &&  ($inline = <$driverPipe>) ) {
    print $inline;
}

if ($pid) {
	kill 9, $pid;
}

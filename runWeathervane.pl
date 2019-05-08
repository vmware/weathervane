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

my $accept = '';
my $configFile = 'weathervane.config';
my $version = '2.0.0';
my $outputDir = 'output';
my $tmpDir = '';

GetOptions(	'accept=s' => \$accept,
			'configFile=s' => \$configFile,
			'version=s' => \$version,
			'output=s' => \$outputDir,
			'tmpDir=s' => \$tmpDir,
		);
		
my $wvCommandLineArgs = join(" ", @ARGV);

sub parseConfigFile {
	my ($configFileName) = @_;
	
	# Read in the config file
	open( CONFIGFILE, "<$configFileName" ) or die "Couldn't open configuration file $configFileName: $!\n";
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
	
	# Extract the path to any Kubernetes config files used for kubernetesClusters.  
	# These files need to be mapped into the run harness container.
	# Clusters will be a reference to a list of kubernetesCluster hashes
	my @k8sConfigFiles;
	my $clusters = $paramConfig->{"kubernetesClusters"};
	if ($clusters) {
		foreach my $clusterHashRef (@$clusters) {
			my $clusterName = $clusterHashRef->{'name'};
			my $clusterConfigName = $clusterHashRef->{'kubernetesConfigFile'};
			if (!$clusterConfigName) {
				if ($clusterName) {
					die "KubernetesCluster $clusterName must have a kubernetesConfigFile definition in configuration file $configFileName.\n"										
				} else {
					die "All kubernetesClusters must include name and kubernetesConfigFile definitions in configuration file $configFileName.\n"										
				}
			} elsif ((! -e $clusterConfigName) || (! -f $clusterConfigName)) {
				die "The kubernetesConfigFile $clusterConfigName must exist and be a regular file.\n";
			}
			push(@k8sConfigFiles, $clusterConfigName);
		}
	}
	
	# Get the dockernamespace
	my $dockerNamespace = $paramConfig->{"dockerNamespace"};
	if (!$dockerNamespace) {
		die "You must specify the dockerNamespace parameter in configuration file $configFileName.\n"										
	}
	
	my @return = (\@k8sConfigFiles, $dockerNamespace);
	
	return \@return;
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
	die "You must specify a valid configuration file using the configFile parameter.  The file $configFile does not exist.\n";
}
if (!(-f $configFile)) {
	die "The Weathervane configuration file $configFile must not be a directory.\n";
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
	die "The Weathervane output directory $outputDir must be a directory.\n";
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
		die "The Weathervane tmp directory $tmpDir must be a directory.\n";
	}
	$tmpMountString = "-v $tmpDir:/root/weathervane/tmpLog";
}

if (dockerExists("weathervane")) {
    `docker rm -vf weathervane`;
}

my $resultsFile = "$pwd/weathervaneResults.csv";

my $retRef = parseConfigFiles($configFile);
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
}

my $configMountString = "-v $configFile:/root/weathervane/weathervane.config";
my $resultsMountString = "-v $resultsFile:/root/weathervane/weathervaneResults.csv";

# Stop an existing run harness container
if (dockerExists("weathervane")) {
    `docker rm -vf weathervane`;
}

# make sure the docker image is up-to-date
`docker pull $dockerNamespace/weathervane-runharness:$version`;

my $cmdString = "docker run --name weathervane --rm -d -w /root/weathervane " 
		. "$configMountString $resultsMountString $k8sConfigMountString " 
		. "$outputMountString $tmpMountString " 
		. "$dockerNamespace/weathervane-runharness:$version $wvCommandLineArgs";
my $dockerId = `$cmdString`;

my $pipeString = "docker logs --follow weathervane |";
my $pipePid = open my $driverPipe, "$pipeString"
	  or die "Can't open docker logs pipe ($pipeString) : $!\n";

my $inline;
while ( $driverPipe->opened() &&  ($inline = <$driverPipe>) ) {
    print $inline;
}

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

my $accept = '';
my $configFile = 'weathervane.config';
my $version = '1.1.0';
my $outputDir = 'output';
my $tmpDir = 'tmpLog';
my $dotKubeDir = '/root/.kube';
my $dockerNamespace = '';

GetOptions(	'accept=s' => \$accept,
			'configFile=s' => \$configFile,
			'version=s' => \$version,
			'output=s' => \$outputDir,
			'tmpDir=s' => \$tmpDir,
			'dotKubeDir=s' => \$dotKubeDir,
			'dockerNamespace=s' => \$dockerNamespace,
		);
		
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
	die "The Weathervane configuration file $configFile does not exist.";
}
if (!(-f $configFile)) {
	die "The Weathervane configuration file $configFile must not be a directory.";
}
# If the configFile does not reference a file with an absolute path, 
# then make it an absolute path relative to the local dir
my $pwd = `pwd`;
chomp($pwd);
if (!($configFile =~ /\//)) {
	$configFile = "$pwd/$configFile";	
}

if (!(-e $outputDir)) {
	`mkdir -p $outputDir`;
}
if (!(-d $outputDir)) {
	die "The Weathervane output directory $outputDir must be a directory.";
}
# If the outputDir does not reference a directory with an absolute path, 
# then make it an absolute path relative to the local dir
if (!($outputDir =~ /\//)) {
	$outputDir = "$pwd/$outputDir";	
}

if (!(-e $tmpDir)) {
	`mkdir -p $tmpDir`;
}
if (!(-d $tmpDir)) {
	die "The Weathervane output directory $tmpDir must be a directory.";
}
# If the tmpDir does not reference a directory with an absolute path, 
# then make it an absolute path relative to the local dir
if (!($tmpDir =~ /\//)) {
	$tmpDir = "$pwd/$tmpDir";	
}

my $resultsFile = "$pwd/weathervaneResults.csv";

if (!$dockerNamespace) {
	die "You must provide a namespace for the Docker images using the --dockerNamespace parameter."
}

if (dockerExists("weathervane")) {
    `docker rm -vf weathervane`;
}

my $cmdString = "docker run --name weathervane --rm -d -w /root/weathervane  -v $configFile:/root/weathervane/weathervane.config  -v $resultsFile:/root/weathervane/weathervaneResults.csv  -v $dotKubeDir:/root/.kube -v $tmpDir:/root/weathervane/tmpLog -v $outputDir:/root/weathervane/output $dockerNamespace/weathervane-runharness:$version";
my $dockerId = `$cmdString`;

my $pipeString = "docker logs --follow weathervane |";
my $pipePid = open my $driverPipe, "$pipeString"
	  or die "Can't open docker logs pipe ($pipeString) : $!";

my $inline;
while ( $driverPipe->opened() &&  ($inline = <$driverPipe>) ) {
    print $inline;
}

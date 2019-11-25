#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
#
# Created by: Hal Rosenberg
#
# This builds and pushes the Docker images for Weathervane
#
package BuildDocker;
use strict;
use Getopt::Long;
use Term::ReadKey;

sub usage {
	print "Usage: ./buildDockerImages.pl [options] [imageNames]\n";
	print "This script builds the Weathervane docker images and pushes them to either\n";
	print "a Docker Hub account or a private registry.\n";
    print " Options:\n";
    print "     --help :         Print this help and exit.\n";
    print "     --username:      The username for the repository (Docker Hub account or private repository).\n";
    print "                      This must be provided if --private is not used.\n";
    print "                      For a private repository, this must be provided if a login is required\n";
    print "                      to authenticate to the repository.\n";
    print "     --password:      (optional) The password for the username (Docker Hub account or private repository).\n";
    print "                      If username is specified and this is not provided, you will be prompted.\n";
    print "     --private :      Use a private Docker registry \n";
    print "     --host :         This is the hostname or IP address for the private registry.\n";
    print "                      This must be provided if --private is used.\n";
    print "     --port :         This is the port number for the private registry.\n";
    print "                      This is only used with --private.\n";
    print "If the list of image names is empty, then all images are built and pushed.\n";
}

my $help = '';
my $host= "";
my $port = 0;
my $username = "";
my $password = "";
my $private = '';

my $optionsSuccess = GetOptions('help' => \$help,
			'host=s' => \$host,
			'port=i' => \$port,
			'username=s' => \$username,
			'password=s' => \$password,
			'private!' => \$private
			);
if (!$optionsSuccess) {
  die "Error for command line options.\n";
}

my @imageNames = qw(centos7 runharness auctiondatamanager auctionworkloaddriver auctionappserverwarmer cassandra nginx postgresql rabbitmq zookeeper tomcat auctionbidservice);
if ($#ARGV >= 0) {
	@imageNames = @ARGV;
}

if ($help) {
	usage();
	exit;
}

sub runAndLog {
	my ( $fileout, $cmd ) = @_;
	print $fileout "COMMAND> $cmd\n";
	open( CMD, "$cmd 2>&1 |" ) || die "Couldn't run command $cmd: $!\n";
	while ( my $line = <CMD> ) {
		print $fileout $line;
	}
	close CMD;
}

sub rewriteDockerfile {
	my ( $dirName, $namespace, $version) = @_;
	`mv $dirName/Dockerfile $dirName/Dockerfile.orig`;
	open(my $filein, "$dirName/Dockerfile.orig") or die "Can't open file $dirName/Dockerfile.orig for reading: $!\n";
	open(my $fileout, ">$dirName/Dockerfile") or die "Can't open file $dirName/Dockerfile for writing: $!\n";
	while (my $inline = <$filein>) {
		if ($inline =~ /^FROM/) {
			print $fileout "FROM $namespace/weathervane-centos7:$version\n";
		} else {
			print $fileout $inline;
		}
	}
	close $filein;
	close $fileout
}

sub cleanupDockerfile {
	my ( $dirName) = @_;
	`mv $dirName/Dockerfile.orig $dirName/Dockerfile`;
}

sub buildImage {
	my ($imageName, $buildArgsListRef, $fileout, $namespace, $version, $logFile) = @_;
	if ($imageName ne "centos7") {		
		rewriteDockerfile("./dockerImages/$imageName", $namespace, $version);
	}

	my $buildArgs = "";
	foreach my $buildArg (@$buildArgsListRef) {
		$buildArgs .= " --build-arg $buildArg";
	}

	runAndLog($fileout, "docker build $buildArgs -t $namespace/weathervane-$imageName:$version ./dockerImages/$imageName");
	my $exitValue;
	$exitValue=$? >> 8;
	if ($exitValue) {
		print "Error: docker build failed with exitValue $exitValue, check $logFile.\n";
		if ($imageName ne "centos7") {		
			cleanupDockerfile("./dockerImages/$imageName");
		}
		cleanupAfterBuild($fileout);
		exit;
	}

	runAndLog($fileout, "docker push $namespace/weathervane-$imageName:$version");
	$exitValue=$? >> 8;
	if ($exitValue) {
		print "Error: docker push failed with exitValue $exitValue, check $logFile.\n";
		if ($imageName ne "centos7") {		
			cleanupDockerfile("./dockerImages/$imageName");
		}
		cleanupAfterBuild($fileout);
		exit;
	}

	if ($imageName ne "centos7") {		
		cleanupDockerfile("./dockerImages/$imageName");
	}
	
}

sub setupForBuild {
	my ($fileout) = @_;

	#nginx
	runAndLog($fileout, "rm -rf ./dockerImages/nginx/html");
	runAndLog($fileout, "mkdir ./dockerImages/nginx/html");
	runAndLog($fileout, "cp ./dist/auctionWeb.tgz ./dockerImages/nginx/html/");
	runAndLog($fileout, "cd ./dockerImages/nginx/html; tar zxf auctionWeb.tgz; rm -f auctionWeb.tgz");
	# appServerWarmer
	runAndLog($fileout, "rm -f ./dockerImages/auctionappserverwarmer/auctionAppServerWarmer.jar");
	runAndLog($fileout, "cp ./dist/auctionAppServerWarmer.jar ./dockerImages/auctionappserverwarmer/auctionAppServerWarmer.jar");
	# tomcat
	runAndLog($fileout, "rm -rf ./dockerImages/tomcat/apache-tomcat-auction1/webapps");
	runAndLog($fileout, "mkdir ./dockerImages/tomcat/apache-tomcat-auction1/webapps");
	runAndLog($fileout, "mkdir ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auction");
	runAndLog($fileout, "mkdir ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auctionWeb");
	runAndLog($fileout, "cp ./dist/auction.war ./dockerImages/tomcat/apache-tomcat-auction1/webapps/");
	runAndLog($fileout, "cp ./dist/auctionWeb.war ./dockerImages/tomcat/apache-tomcat-auction1/webapps/");
	runAndLog($fileout, "cp ./dist/auction.war ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auction/");
	runAndLog($fileout, "cd ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auction; jar xf auction.war; rm -f auction.war");
	runAndLog($fileout, "cp ./dist/auctionWeb.war ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auctionWeb/");
	runAndLog($fileout, "cd ./dockerImages/tomcat/apache-tomcat-auction1/webapps/auctionWeb; jar xf auctionWeb.war; rm -f auctionWeb.war");
	# auctionBidService
	runAndLog($fileout, "rm -rf ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps");
	runAndLog($fileout, "mkdir ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps");
	runAndLog($fileout, "mkdir ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps/auction");
	runAndLog($fileout, "cp ./dist/auctionBidService.war ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps/auction.war");
	runAndLog($fileout, "cp ./dist/auctionBidService.war ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps/auction/auction.war");
	runAndLog($fileout, "cd ./dockerImages/auctionbidservice/apache-tomcat-bid/webapps/auction; jar xf auction.war; rm -f auction.war");
	# workload driver
	runAndLog($fileout, "rm -f ./dockerImages/auctionworkloaddriver/workloadDriver.jar");
	runAndLog($fileout, "rm -rf ./dockerImages/auctionworkloaddriver/workloadDriverLibs");
	runAndLog($fileout, "cp ./dist/workloadDriver.jar ./dockerImages/auctionworkloaddriver/workloadDriver.jar");
	runAndLog($fileout, "cp -r ./dist/workloadDriverLibs ./dockerImages/auctionworkloaddriver/workloadDriverLibs");
	# data manager
	runAndLog($fileout, "rm -f ./dockerImages/auctiondatamanager/dbLoader.jar");
	runAndLog($fileout, "rm -rf ./dockerImages/auctiondatamanager/dbLoaderLibs");
	runAndLog($fileout, "cp ./dist/dbLoader.jar ./dockerImages/auctiondatamanager/dbLoader.jar");
	runAndLog($fileout, "cp -r ./dist/dbLoaderLibs ./dockerImages/auctiondatamanager/dbLoaderLibs");
	# run harness
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/runHarness");
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/configFiles");
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/workloadConfiguration");
	runAndLog($fileout, "rm -f ./dockerImages/runharness/weathervane.pl");
	runAndLog($fileout, "rm -f ./dockerImages/runharness/version.txt");
	runAndLog($fileout, "cp ./version.txt ./dockerImages/runharness/version.txt");
	runAndLog($fileout, "cp -r ./runHarness ./dockerImages/runharness/runHarness");
	runAndLog($fileout, "cp ./weathervane.pl ./dockerImages/runharness/weathervane.pl");
	runAndLog($fileout, "cp -r ./configFiles ./dockerImages/runharness/configFiles");
	runAndLog($fileout, "cp -r ./workloadConfiguration ./dockerImages/runharness/workloadConfiguration");	
}

sub cleanupAfterBuild {
	my ($fileout) = @_;
	runAndLog($fileout, "rm -rf ./dockerImages/nginx/html");
	runAndLog($fileout, "rm -f ./dockerImages/auctionappserverwarmer/auctionAppServerWarmer.jar");
	runAndLog($fileout, "rm -rf ./dockerImages/tomcat/apache-tomcat-auction1/webapps");
	runAndLog($fileout, "rm -rf ./dockerImages/auctionBidService/apache-tomcat-bid/webapps");
	runAndLog($fileout, "rm -f ./dockerImages/auctionworkloaddriver/workloadDriver.jar");
	runAndLog($fileout, "rm -rf ./dockerImages/auctionworkloaddriver/workloadDriverLibs");
	runAndLog($fileout, "rm -f ./dockerImages/auctiondatamanager/dbLoader.jar");
	runAndLog($fileout, "rm -rf ./dockerImages/auctiondatamanager/dbLoaderLibs");
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/runHarness");
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/configFiles");
	runAndLog($fileout, "rm -rf ./dockerImages/runharness/workloadConfiguration");
	runAndLog($fileout, "rm -f ./dockerImages/runharness/weathervane.pl");
	runAndLog($fileout, "rm -f ./dockerImages/runharness/version.txt");
}

my $namespace;
if ($private) {
	if ($host eq "") {
		print "When using a private repository, you must specify the host parameter.\n";
		usage();
		exit;
	}
	$namespace = $host;
	if ($port) {
		$namespace .= ":$port";
	}
} else {
	if ($username eq "") {
			print "When using Docker Hub, you must specify the username parameter.\n";
			usage();
			exit;
	}
	$namespace = $username;
}

if (!(-e "./buildDockerImages.pl")) {
	print "You must run in the weathervane directory with buildDockerImages.pl\n";
	exit;
}

my $cmdout;
my $fileout;
my $logFile = "buildDockerImages.log";
open( $fileout, ">$logFile" ) or die "Can't open file $logFile for writing: $!\n";

# Build the executables
print "Building the executables.\n";
print $fileout "Building the executables.\n";
runAndLog($fileout, "./gradlew release");
my $exitValue=$? >> 8;
if ($exitValue) {
	print "Error: Building failed with exitValue $exitValue, check $logFile.\n";
	exit;
}

# Get the latest executables into the appropriate directories for the Docker images
print "Setting up the Docker images.\n";
print $fileout "Setting up the Docker images.\n";
setupForBuild($fileout);

my $version = `cat version.txt`;
chomp($version);

# Turn on auto flushing of output
BEGIN { $| = 1 }

if (!$private || $username) {
	my $hostString = "Docker Hub";
	if ($private) {
		$hostString = $host;
	}
	if (!(length $password > 0)) {
		Term::ReadKey::ReadMode('noecho');
		print "Enter $hostString password for $username:";
		$password = Term::ReadKey::ReadLine(0);
		Term::ReadKey::ReadMode('restore');
		print "\n";
		$password =~ s/\R\z//; #get rid of new line
	}

	if (!(length $password > 0)) {
		die "Error, no password input.\n";
	}

	print "Logging into $hostString\n";
	print $fileout "Logging into $hostString\n";
	my $cmd = "docker login -u=$username -p=$password $host";
	my $response = `$cmd 2>&1`;
	print $fileout "result: $response\n";
	if ($response =~ /unauthorized/) {
		print "Could not login to $hostString with the supplied username and password.\n";
		cleanupAfterBuild($fileout);
		exit;
	}
} 

foreach my $imageName (@imageNames) {
	$imageName = lc $imageName;
	print "Building and pushing weathervane-$imageName image.\n";
	print $fileout "Building and pushing weathervane-$imageName image.\n";
	my @buildArgs;
	
	buildImage($imageName, \@buildArgs, $fileout, $namespace, $version, $logFile);
}

# Clean up
print $fileout "Cleaning up.\n";
cleanupAfterBuild($fileout);

print "Done.\n";
print $fileout "Done.\n";

1;

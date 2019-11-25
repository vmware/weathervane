#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use POSIX;

my $maxUsers = $ENV{'MAXUSERS'};
my $users = $ENV{'USERS'};
my $appInstanceNum = $ENV{'APPINSTANCENUM'};
my $threads = $ENV{'PREPTHREADS'};
print "Preparing data for appInstance $appInstanceNum\n";

if ( $users > $maxUsers ) {
	$maxUsers = $users;
}
my $auctions = ceil($maxUsers / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 
if ( $auctions < 4 ) {
	$auctions = 4;
}
# Must be multiple of 2
if (($auctions % 2) != 0) {
	$auctions++;
}

my $dbPrepOptions = " -a $auctions ";

$dbPrepOptions .= " -u $users -t $threads ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $jvmopts              = $ENV{'JVMOPTS'};
my $dbLoaderJavaOptions = "";

my $cmdString = "java $jvmopts $dbLoaderJavaOptions -client -cp $dbLoaderClasspath" .
				" -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$ENV{'DBHOSTNAME'}" . 
				" -DDBPORT=$ENV{'DBPORT'} -DCASSANDRA_CONTACTPOINTS=$ENV{'CASSANDRA_CONTACTPOINTS'}" .
				" -DCASSANDRA_PORT=$ENV{'CASSANDRA_PORT'} com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1";
				
print "Running for appInstance $appInstanceNum: $cmdString\n";
my $cmdOut = `$cmdString`;
print "Output for appInstance $appInstanceNum: $cmdOut\n";

if ($?) {
	exit 1;
}
else {
	exit 0;
}

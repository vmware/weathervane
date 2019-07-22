#!/usr/bin/perl

use strict;
use POSIX;

my $appInstanceNum = $ENV{'APPINSTANCENUM'};
print "Cleaning data for appInstance $appInstanceNum\n";

# Not preparing any auctions, just cleaning up
my $auctions = 0;
my $dbPrepOptions = " -a $auctions ";

my $users = $ENV{'USERS'};
my $maxUsers = $ENV{'MAXUSERS'};
if ( $users > $maxUsers ) {
	$maxUsers = $users;
}
$dbPrepOptions .= " -u $maxUsers ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";
my $jvmopts              = $ENV{'JVMOPTS'};
my $dbLoaderJavaOptions = "";

my $cmdString = "java $jvmopts $dbLoaderJavaOptions -client -cp $dbLoaderClasspath" .
				" -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$ENV{'DBHOSTNAME'} -DDBPORT=$ENV{'DBPORT'}" . 
				" -DCASSANDRA_CONTACTPOINTS=$ENV{'CASSANDRA_CONTACTPOINTS'} -DCASSANDRA_PORT=$ENV{'CASSANDRA_PORT'}" .
				" com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1";

print "Running for appInstance $appInstanceNum: $cmdString\n";
my $cmdOut = `$cmdString`;
print "Output for appInstance $appInstanceNum: $cmdOut\n";

if ($?) {
	exit 1;
}
else {
	exit 0;
}

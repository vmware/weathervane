#!/usr/bin/perl

use strict;
use POSIX;

print "Cleaning data\n";

# Not preparing any auctions, just cleaning up
my $auctions = 0;

my $dbPrepOptions = " -a $auctions -c ";
$dbPrepOptions .= " -f $ENV{'MAXDURATION'} ";

my $users = $ENV{'USERS'};
$dbPrepOptions .= " -u $users ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";
my $heap              = "4G";
my $dbLoaderJavaOptions = "";

my $cmdString = "java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -client -cp $dbLoaderClasspath" + 
				" -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$ENV{'DBHOSTNAME'} -DDBPORT=$ENV{'DBPORT'}" + 
				" -DCASSANDRA_CONTACTPOINTS=$ENV{'CASSANDRA_CONTACTPOINTS'} -DCASSANDRA_PORT=$ENV{'CASSANDRA_PORT'}" + 
				" com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1";

print "Running: $cmdString\n";
my $cmdOut = `$cmdString`;
print "$cmdOut\n";

if ($?) {
	exit 1;
}
else {
	exit 0;
}

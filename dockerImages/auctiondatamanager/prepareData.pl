#!/usr/bin/perl

use strict;
use POSIX;

print "Preparing data for run\n";
my $maxUsers = $ENV{'MAXUSERS'};

my $auctions = ceil($maxUsers / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 
if ( $auctions < 4 ) {
	$auctions = 4;
}
# Must be multiple of 2
if (($auctions % 2) != 0) {
	$auctions++;
}

my $dbPrepOptions = " -a $auctions ";
$dbPrepOptions .= " -f $ENV{'MAXDURATION'} ";

my $users = $ENV{'USERS'};
$dbPrepOptions .= " -u $users ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $heap              = "4G";
my $threads = 8;
my $dbLoaderJavaOptions = "";

my $cmdString = "java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -client -cp $dbLoaderClasspath" + 
				" -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$ENV{'DBHOSTNAME'}" + 
				" -DDBPORT=$ENV{'DBPORT'} -DCASSANDRA_CONTACTPOINTS=$ENV{'CASSANDRA_CONTACTPOINTS'}" + 
				" -DCASSANDRA_PORT=$ENV{'CASSANDRA_PORT'} com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1";
				
print "Running: $cmdString\n";
my $cmdOut = `$cmdString`;

print "$cmdOut\n";

if ($?) {
	exit 1;
}
else {
	exit 0;
}

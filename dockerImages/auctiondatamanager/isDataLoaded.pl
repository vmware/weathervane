#!/usr/bin/perl

use strict;
use POSIX;

print "Checking whether data is loaded\n";

# the usersPerAuctionScaleFactor
my $auctions = ceil($ENV{'USERS'} / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 

my $dbPrepOptions = " -a $auctions -c ";

my $users = $ENV{'USERS'};
my $maxUsers = $ENV{'MAXUSERS'};
if ( $users > $maxUsers ) {
	$maxUsers = $users;
}
$dbPrepOptions .= " -u $maxUsers ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";
my $heap              = $ENV{'HEAP'};

my $cmdString = "java  -Xmx$heap -Xms$heap  -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\"" .
		 " -DDBHOSTNAME=$ENV{'DBHOSTNAME'} -DDBPORT=$ENV{'DBPORT'} -DCASSANDRA_CONTACTPOINTS=$ENV{'CASSANDRA_CONTACTPOINTS'}" . 
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

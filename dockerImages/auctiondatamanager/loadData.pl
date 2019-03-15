#!/usr/bin/perl

use strict;
use POSIX;

# the usersPerAuctionScaleFactor
my $maxUsers = $ENV{'MAXUSERS'};
my $users = $ENV{'USERS'};
my $maxDuration = $ENV{'MAXDURATION'};
my $workloadNum = $ENV{'WORKLOADNUM'};
my $appInstanceNum = $ENV{'APPINSTANCENUM'};
my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
my $dbHostname = $ENV{'DBHOSTNAME'};
my $dbPort = $ENV{'DBPORT'};
my $cassandraContactpoints = $ENV{'CASSANDRA_CONTACTPOINTS'};
my $cassandraPort = $ENV{'CASSANDRA_PORT'};

my $heap              = "6G";
my $threads = 16;

if ( $users > $maxUsers ) {
	$maxUsers = $users;
}

my $auctions = ceil($users / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 
if ( $auctions < 4 ) {
	$auctions = 4;
}
# Must be multiple of 2
if (($auctions % 2) != 0) {
	$auctions++;
}

# Load the data
my $dbLoaderOptions = "-d /items.json -t $threads ";
$dbLoaderOptions .= " -u $maxUsers ";
$dbLoaderOptions .= " -f $maxDuration ";
$dbLoaderOptions .= " -a 'Workload $workloadNum, appInstance $appInstanceNum.' ";
$dbLoaderOptions .= " -r \"/images\"";

$springProfilesActive .= ",dbloader";

my $dbLoaderJavaOptions = "";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $cmdString = "java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -Dwkld=W${workloadNum}I${appInstanceNum}" .
				" -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\"" .
				" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DCASSANDRA_CONTACTPOINTS=$cassandraContactpoints" . 
				" -DCASSANDRA_PORT=$cassandraPort com.vmware.weathervane.auction.dbloader.DBLoader $dbLoaderOptions 2>/dev/null";
				
system($cmdString);

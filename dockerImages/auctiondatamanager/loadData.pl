#!/usr/bin/perl

use strict;
use POSIX;

# the usersPerAuctionScaleFactor
my $maxUsers = $ENV{'MAXUSERS'};
my $users = $ENV{'USERS'};
my $workloadNum = $ENV{'WORKLOADNUM'};
my $appInstanceNum = $ENV{'APPINSTANCENUM'};
my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
my $dbHostname = $ENV{'DBHOSTNAME'};
my $dbPort = $ENV{'DBPORT'};
my $cassandraContactpoints = $ENV{'CASSANDRA_CONTACTPOINTS'};
my $cassandraPort = $ENV{'CASSANDRA_PORT'};
my $jvmopts              = $ENV{'JVMOPTS'};
my $threads = $ENV{'LOADERTHREADS'};

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
$dbLoaderOptions .= " -a 'Workload $workloadNum, appInstance $appInstanceNum.' ";
$dbLoaderOptions .= " -r \"/images\"";

$springProfilesActive .= ",dbloader";

my $dbLoaderJavaOptions = "";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $cmdString = "java $jvmopts $dbLoaderJavaOptions -Dwkld=W${workloadNum}I${appInstanceNum}" .
				" -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\"" .
				" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DCASSANDRA_CONTACTPOINTS=$cassandraContactpoints" . 
				" -DCASSANDRA_PORT=$cassandraPort com.vmware.weathervane.auction.dbloader.DBLoader $dbLoaderOptions 2>/dev/null";
				
print "Running for appInstance $appInstanceNum: $cmdString\n";
system($cmdString);

print "Catting /images/.db*\n";
`cat /images/.db*`;

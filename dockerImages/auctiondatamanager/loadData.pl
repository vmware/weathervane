#!/usr/bin/perl

use strict;
use POSIX;

print "Loading Data\n";

# the usersPerAuctionScaleFactor
my $maxUsers = $ENV{'MAXUSERS'};
my $users = $ENV{'USERS'};
my $maxDuration = $ENV{'MAXDURATION'};
my $numNosqlShards = $ENV{'NUMNOSQLSHARDS'};
my $numNosqlReplicas = $ENV{'NUMNOSQLREPLICAS'};
my $mongoHostPortPairsString = $ENV{'MONGODBSERVERS'};
my $workloadNum = $ENV{'WORKLOADNUM'};
my $appInstanceNum = $ENV{'APPINSTANCENUM'};
my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
my $dbHostname = $ENV{'DBHOSTNAME'};
my $dbPort = $ENV{'DBPORT'};
my $mongodbHostname = $ENV{'MONGODBHOSTNAME'};
my $mongodbPort = $ENV{'MONGODBPORT'};
my $mongodbReplicaSet = $ENV{'MONGODBREPLICASET'};

my $heap              = "4G";
my $threads = 8;

if ( $users > $maxUsers ) {
	$maxUsers = $users;
}

my $auctions = ceil($users / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 

my @mongoHostPortPairs = split /,/, $mongoHostPortPairsString;

# Load the data
my $dbLoaderOptions = "-d /items.json -t $threads ";
$dbLoaderOptions .= " -u $maxUsers ";
$dbLoaderOptions .= " -m $numNosqlShards ";
$dbLoaderOptions .= " -p $numNosqlReplicas ";
$dbLoaderOptions .= " -f $maxDuration ";
$dbLoaderOptions .= " -a 'Workload $workloadNum, appInstance $appInstanceNum.' ";
$dbLoaderOptions .= " -r \"/images\"";

$springProfilesActive .= ",dbloader";

my $dbLoaderJavaOptions = "";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $cmdString =
"java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -Dwkld=W${workloadNum}I${appInstanceNum} -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort -DMONGODB_HOST=$mongodbHostname -DMONGODB_PORT=$mongodbPort -DMONGODB_REPLICA_SET=$mongodbReplicaSet com.vmware.weathervane.auction.dbloader.DBLoader $dbLoaderOptions ";
system($cmdString);

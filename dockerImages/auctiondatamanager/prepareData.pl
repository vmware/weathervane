#!/usr/bin/perl

use strict;
use POSIX;

print "Preparing data for run\n";

my $auctions = ceil($ENV{'USERS'} / $ENV{'USERSPERAUCTIONSCALEFACTOR'}); 

my $dbPrepOptions = " -a $auctions ";
$dbPrepOptions .= " -m $ENV{'NUMNOSQLSHARDS'} ";
$dbPrepOptions .= " -p $ENV{'NUMNOSQLREPLICAS'} ";
$dbPrepOptions .= " -f $ENV{'MAXDURATION'} ";

my $users = $ENV{'USERS'};
$dbPrepOptions .= " -u $users ";

my $springProfilesActive = $ENV{'SPRINGPROFILESACTIVE'};
$springProfilesActive .= ",dbprep";

my $dbLoaderClasspath = "/dbLoader.jar:/dbLoaderLibs/*:/dbLoaderLibs";

my $heap              = "4G";
my $threads = 8;
my $dbLoaderJavaOptions = "";

my $cmdString = "java -Xmx$heap -Xms$heap $dbLoaderJavaOptions -client -cp $dbLoaderClasspath -Dspring.profiles.active=\"$springProfilesActive\" -DDBHOSTNAME=$ENV{'DBHOSTNAME'} -DDBPORT=$ENV{'DBPORT'} -DMONGODB_HOST=$ENV{'MONGODBHOSTNAME'} -DMONGODB_PORT=$ENV{'MONGODBPORT'} -DMONGODB_REPLICA_SET=$ENV{'MONGODBREPLICASET'} com.vmware.weathervane.auction.dbloader.DBPrep $dbPrepOptions 2>&1";
print "Running: $cmdString\n";

my $cmdOut = `$cmdString`;

print "$cmdOut\n";

if ($?) {
	exit 1;
}
else {
	exit 0;
}

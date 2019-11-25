#!/usr/bin/perl
# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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

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

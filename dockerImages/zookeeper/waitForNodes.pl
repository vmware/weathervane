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

my $clientPort   = $ENV{'ZK_CLIENT_PORT'};
my $servers;
if ((exists $ENV{'ZK_SERVERS'}) && (defined $ENV{'ZK_SERVERS'})) {
	$servers = $ENV{'ZK_SERVERS'};
} else {
	# Get the zookeeper servers info from the zookeeperServers.txt file
	open( FILEIN, "/zookeeperServers.txt" )
	  or die "Can't open file /zookeeperServers.txt: $!";
	$servers = <FILEIN>;
	close FILEIN;
}

my @servers      = split /,/, $servers;
if ( $#servers > 0 ) {

	print "Waiting for all zookeeper nodes to be reachable. \n";
	my $hostname = `hostname`;
	
	foreach my $server (@servers) {
		my @parts = split /\=/, $server; 
		@parts = split /\:/, $parts[1]; 
		my $serverFullName = $parts[0];
		
		my $isUp = 0;
		while (!$isUp) {
			my $out = `ping -c 1 $serverFullName`;
			my $retCode = $? >> 8;
			if ($retCode) {
				print "Server $serverFullName is not yet reachable\n";
				sleep 10;
			} else {
				print "Server $serverFullName is reachable\n";
				$isUp = 1;
			}
			
		}
		
	}

}

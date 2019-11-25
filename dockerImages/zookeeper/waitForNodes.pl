#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

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

#!/usr/bin/perl

use strict;
use POSIX;

my $servers      = $ENV{'ZK_SERVERS'};
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

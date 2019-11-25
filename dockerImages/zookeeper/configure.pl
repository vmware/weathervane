#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use POSIX;

my $clientPort   = $ENV{'ZK_CLIENT_PORT'};
my $id           = $ENV{'ZK_ID'};
my $servers ;

print "configure zookeeper. \n";
if ((exists $ENV{'ZK_SERVERS'}) && (defined $ENV{'ZK_SERVERS'})) {
	$servers = $ENV{'ZK_SERVERS'};
} else {
	# Get the zookeeper servers info from the zookeeperServers.txt file
	open( FILEIN, "/zookeeperServers.txt" )
	  or die "Can't open file /zookeeperServers.txt: $!";
	$servers = <FILEIN>;
	close FILEIN;
}
print "servers = $servers\n";
my @servers      = split /,/, $servers;

if (!$id) {
	my $hostname = `hostname`;
	my @parts = split /-/, $hostname;
	$id = $parts[1] + 1; 
}

open( FILEIN, "/root/zookeeper/conf/zoo.cfg" )
  or die "Can't open file /root/zookeeper/conf/zoo.cfg: $!";
open( FILEOUT, ">/opt/zookeeper/conf/zoo.cfg" )
  or die "Can't open file /opt/zookeeper/conf/zoo.cfg: $!";
while ( my $inline = <FILEIN> ) {

	if ( $inline =~ /^\s*clientPort=/ ) {
		print FILEOUT "clientPort=" . $clientPort . "\n";
	}
	else {
		print FILEOUT $inline;
	}

}

if ( $#servers > 0 ) {

	# Add server info for a replicated config
	print FILEOUT "initLimit=5\n";
	print FILEOUT "syncLimit=2\n";

	foreach my $zookeeperServer (@servers) {
		print FILEOUT "$zookeeperServer\n";
	}

	open( MYIDFILE, ">/mnt/zookeeper/myid" )
	  or die "Can't open file /mnt/zookeeper/myid: $!";
	print MYIDFILE "$id\n";
	close MYIDFILE;

}

close FILEIN;
close FILEOUT;

#!/usr/bin/perl

use strict;
use POSIX;

my $clientPort   = $ENV{'ZK_CLIENT_PORT'};
my $peerPort     = $ENV{'ZK_PEER_PORT'};
my $electionPort = $ENV{'ZK_ELECTION_PORT'};
my $id           = $ENV{'ZK_ID'};
my $servers      = $ENV{'ZK_SERVERS'};
my @servers      = split /,/, $servers;

print "configure zookeeper. \n";
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

if ( $#servers > 1 ) {

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

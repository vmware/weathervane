#!/usr/bin/perl

use strict;
use POSIX;

my $clearBeforeStart = $ENV{'CLEARBEFORESTART'};
my $seeds = $ENV{'CASSANDRA_SEEDS'};
my $clusterName  = $ENV{'CASSANDRA_CLUSTER_NAME'};
my $hostname = $ENV{'CASSANDRA_HOSTNAME'};
if (!$hostname) {
	$hostname = `hostname`;
	chomp($hostname);
}

print "configure cassandra. \n";

if ($clearBeforeStart) {
	# Delete the directories for the auction_image and auction_event keyspaces
	`rm -rf /data/data/auction_event`;
	`rm -rf /data/data/auction_image`;
}

# Configure setenv.sh
open( FILEIN,  "/cassandra.yaml" ) or die "Can't open file /cassandra.yaml: $!\n";
open( FILEOUT, ">/etc/cassandra/conf/cassandra.yaml" ) or die "Can't open file /etc/cassandra/conf/cassandra.yaml: $!\n";
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^(\s*)\-\sseeds\:/ ) {
		print FILEOUT "${1}- seeds: \"$seeds\"\n";
	}
	elsif ( $inline =~ /^cluster\_name:/ ) {
		print FILEOUT "cluster_name: '$clusterName'\n";
	}
	elsif ( $inline =~ /^\#listen\_address\:\slocalhost/ ) {
		print FILEOUT "listen_address: $hostname\n";
	}
	elsif ( $inline =~ /^rpc\_address\:\slocalhost/ ) {
		print FILEOUT "rpc_address: $hostname\n";
	}
	else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;

# ToDo: Configure jvm.options bassed on assigned memory size
open( FILEIN,  "/jvm.options" ) or die "Can't open file /jvm.options: $!\n";
open( FILEOUT, ">/etc/cassandra/conf/jvm.options" ) or die "Can't open file /etc/cassandra/conf/jvm.options: $!\n";
while ( my $inline = <FILEIN> ) {
	print FILEOUT $inline;
}
close FILEIN;
close FILEOUT;

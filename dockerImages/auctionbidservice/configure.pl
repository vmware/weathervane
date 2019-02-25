#!/usr/bin/perl

use strict;
use POSIX;

my $seeds = $ENV{'CASSANDRA_SEEDS'};
my $clusterName  = $ENV{'CASSANDRA_CLUSTER_NAME'};
print "configure cassandra. \n";

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
	else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;

#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use POSIX;
use List::Util qw[min max];

my $clearBeforeStart = $ENV{'CLEARBEFORESTART'};
my $seeds = $ENV{'CASSANDRA_SEEDS'};
my $clusterName  = $ENV{'CASSANDRA_CLUSTER_NAME'};
my $numNodes = $ENV{'CASSANDRA_NUM_NODES'};
my $nativeTransportPort = $ENV{'CASSANDRA_NATIVE_TRANSPORT_PORT'};
my $jmxPort = $ENV{'CASSANDRA_JMX_PORT'};

my $hostname = `hostname`;
chomp($hostname);
if ($ENV{'CASSANDRA_USE_IP'}) {
	my $hostnameIp = `hostname -i`;
	chomp($hostnameIp);
	if ($hostname =~ /cassandra\-0/) {
		$seeds = $hostnameIp . "," . $seeds;
	} else {
		$seeds = $hostnameIp; #set seeds to the same ip as the listen_address
		#this only works for a single Cassandra node, and will need updating for multiple nodes
	}
	$hostname = $hostnameIp;
}

print "configure cassandra. \n";

if ($clearBeforeStart) {
	`rm -rf /data/data/*`;
	`rm -rf /data/commitlog/*`;
}

# Configure jvm.options
`cp /jvm-server.options /etc/cassandra/jvm-server.options`;

# Configure casandra.yaml
open( FILEIN,  "/cassandra.yaml" ) or die "Can't open file /cassandra.yaml: $!\n";
open( FILEOUT, ">/etc/cassandra/cassandra.yaml" ) or die "Can't open file /etc/cassandra/cassandra.yaml: $!\n";
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^(\s*)\-\sseeds\:/ ) {
		print FILEOUT "${1}- seeds: \"$seeds\"\n";
	}
	elsif ( $inline =~ /^cluster\_name:/ ) {
		print FILEOUT "cluster_name: '$clusterName'\n";
	}
	elsif ( $inline =~ /^file\_cache\_size\_in\_mb:/ ) {
		print FILEOUT "file_cache_size_in_mb: 512\n";
	}
	elsif ( $inline =~ /^\#listen\_address\:\slocalhost/ ) {
		print FILEOUT "listen_address: $hostname\n";
	}
	elsif ( $inline =~ /^rpc\_address\:\slocalhost/ ) {
		print FILEOUT "rpc_address: $hostname\n";
	}
	elsif ( $nativeTransportPort && $inline =~ /^native\_transport\_port:\s9042/ ) {
		print FILEOUT "native_transport_port: $nativeTransportPort\n";
	}
	else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;

# Configure cassandra-env.sh
if ( $jmxPort ) {
	open( FILEIN,  "/etc/cassandra/cassandra-env.sh" ) or die "Can't open file /etc/cassandra/cassandra-env.sh: $!\n";
	open( FILEOUT, ">/tmp/cassandra-env.sh" ) or die "Can't open file /tmp/cassandra-env.sh: $!\n";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /^JMX\_PORT=/ ) {
			print FILEOUT "JMX_PORT=\"$jmxPort\"\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	`mv /tmp/cassandra-env.sh /etc/cassandra/cassandra-env.sh`;
}

# Configure auction_cassandra.cql
open( FILEIN,  "/auction_cassandra.cql" ) or die "Can't open file /auction_cassandra.cql: $!\n";
open( FILEOUT, ">/auction_cassandra_configured.cql" ) or die "Can't open file /auction_cassandra_configured.cql: $!\n";
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^CREATE\sKEYSPACE\sauction\_event/ ) {
		print FILEOUT $inline;
		$inline = <FILEIN>;
		if ($numNodes == 1) {
			print FILEOUT "  WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 1 };\n";			
		} elsif ($numNodes == 2) {
			print FILEOUT "  WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 2 };\n";			
		} else {
			print FILEOUT "  WITH REPLICATION = {'class' : 'SimpleStrategy', 'replication_factor' : 3 };\n";			
		}
	}
	else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;


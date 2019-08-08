#!/usr/bin/perl

use strict;
use POSIX;
use List::Util qw[min max];

my $clearBeforeStart = $ENV{'CLEARBEFORESTART'};
my $seeds = $ENV{'CASSANDRA_SEEDS'};
my $clusterName  = $ENV{'CASSANDRA_CLUSTER_NAME'};
my $memory = $ENV{'CASSANDRA_MEMORY'};
my $cpus = $ENV{'CASSANDRA_CPUS'};

my $hostname = `hostname`;
chomp($hostname);
if ($ENV{'CASSANDRA_USE_IP'}) {
	$hostname = `hostname -i`;
	chomp($hostname);
	$seeds = $hostname . "," . $seeds;
}

print "configure cassandra. \n";

if ($clearBeforeStart) {
	`rm -rf /data/data/*`;
	`rm -rf /data/commitlog/*`;
}

# Configure jvm.options bassed on assigned memory size
# Heap calculations are those used by cassandra
$memory = convertK8sMemStringToMB($memory);
$cpus = ceil($cpus);
my $heapBound1 = min(0.5 * $memory, 1024);
my $heapBound2 = min(0.25 * $memory, 8192);
my $heapSize = ceil(max($heapBound1, $heapBound2));
my $newHeapSize = ceil(min(100 * $cpus, 0.25 * $heapSize));
open( FILEIN,  "/jvm.options" ) or die "Can't open file /jvm.options: $!\n";
open( FILEOUT, ">/etc/cassandra/conf/jvm.options" ) or die "Can't open file /etc/cassandra/conf/jvm.options: $!\n";
while ( my $inline = <FILEIN> ) {
	if ($inline =~ /^#\-Xms/) {
		print FILEOUT "-Xms${heapSize}M\n";
	} elsif ($inline =~ /^#\-Xmx/) {		
		print FILEOUT "-Xmx${heapSize}M\n";
	} elsif ($inline =~ /^#\-Xmn/) {
		print FILEOUT "-Xmn${newHeapSize}M\n";
	} else {
		print FILEOUT $inline;
	}
}
close FILEIN;
close FILEOUT;

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
	elsif ( $inline =~ /^file\_cache\_size\_in\_mb:/ ) {
		my $fileCacheSize = ceil($heapSize * 0.25);
		print FILEOUT "file_cache_size_in_mb: $fileCacheSize\n";
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

# In the weathervane config file, memory limits are specified using Kubernetes 
# notation.  Were we convert these to MB for use in jvm.options
sub convertK8sMemStringToMB {
	my ( $k8sMemString ) = @_;
	# Both K8s and Docker Memory limits are an integer followed by an optional suffix.
	# The legal suffixes in K8s are:
	#  * E, P, T, G, M, K (powers of 10)
	#  * Ei, Pi, Ti, Gi, Mi, Ki (powers of 2)
	# The legal suffixes in Docker are:
	#  * g, m, k, b (powers of 2)
	$k8sMemString =~ /^(\d+)(.*)$/;
	my $memMb = $1;
	my $suffix = $2;
	if ($suffix) {
		if ($suffix =~ /i/) {
			# Already a power of 2 notation
			if ($suffix =~ /E/) {
				$memMb *= 1024 * 1024 * 1024 * 1024;
			} elsif ($suffix =~ /P/) {				
				$memMb *= 1024 * 1024 * 1024;
			} elsif ($suffix =~ /T/) {
				$memMb *= 1024 * 1024;
			} elsif ($suffix =~ /G/) {
				$memMb *= 1024;
			} elsif ($suffix =~ /K/) {
				$memMb /= 1024;
			}
		} else {
			# Power of 10 notation
			if ($suffix =~ /E/) {
				$memMb *= 1000 * 1000 * 1000 * 1000;
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} elsif ($suffix =~ /P/) {				
				$memMb *= 1000 * 1000 * 1000;
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} elsif ($suffix =~ /T/) {
				$memMb *= 1000 * 1000;
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} elsif ($suffix =~ /G/) {				
				$memMb *= 1000;
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} elsif ($suffix =~ /M/) {
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} elsif ($suffix =~ /K/) {				
				$memMb /= 1000;
				# Convert from M to Mi
				$memMb = trunc(round($memMb * 0.9537));
			} 	
		}
	}
	return $memMb;
}


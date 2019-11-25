#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use POSIX;

my $port                            = $ENV{'POSTGRESPORT'};
my $totalMem                        = $ENV{'POSTGRESTOTALMEM'};
my $totalMemUnit                    = $ENV{'POSTGRESTOTALMEMUNIT'};
my $postgresqlSharedBuffers         = $ENV{'POSTGRESSHAREDBUFFERS'};
my $postgresqlSharedBuffersPct      = $ENV{'POSTGRESSHAREDBUFFERSPCT'};
my $postgresqlEffectiveCacheSize    = $ENV{'POSTGRESEFFECTIVECACHESIZE'};
my $postgresqlEffectiveCacheSizePct = $ENV{'POSTGRESEFFECTIVECACHESIZEPCT'};
my $postgresqlMaxConnections        = $ENV{'POSTGRESMAXCONNECTIONS'};

if ( !$totalMem || !$totalMemUnit ) {

	# Find the total amount of memory on the host
	my $out = `cat /proc/meminfo`;
	$out =~ /MemTotal:\s+(\d+)\s+(\w)/;
	$totalMem     = $1;
	$totalMemUnit = $2;
}
if ( uc($totalMemUnit) eq "K" ) {
	$totalMemUnit = "kB";
}
elsif ( uc($totalMemUnit) eq "M" ) {
	$totalMemUnit = "MB";
}
elsif ( uc($totalMemUnit) eq "G" ) {
	$totalMemUnit = "GB";
}

# Modify the postgresql.conf and
# then copy the new version to the DB
print "Configuring postgresql.conf\n";
open( FILEIN,  "/postgresql.conf" );
open( FILEOUT, ">/mnt/dbData/postgresql/postgresql.conf" );
while ( my $inline = <FILEIN> ) {

	if ( $inline =~ /^\s*shared_buffers\s*=\s*(.*)/ ) {
		my $origValue = $1;

		# If postgresqlSharedBuffers was set, then use it
		# as the value. Otherwise, if postgresqlSharedBuffersPct
		# was set, use that percentage of total memory,
		# otherwise use what was in the original file
		if ($postgresqlSharedBuffers) {
			print FILEOUT "shared_buffers = " . $postgresqlSharedBuffers . "\n";

		}
		elsif ($postgresqlSharedBuffersPct) {
			print "Setting shared_buffers based on totalMem = $totalMem, totalMemUnit = $totalMemUnit, postgresqlSharedBuffersPct = $postgresqlSharedBuffersPct\n";

			if ( $postgresqlSharedBuffersPct > 1 ) {
				die "postgresqlSharedBuffersPct must be less than 1";
			}

			my $bufferMem = $totalMem * $postgresqlSharedBuffersPct;
			if ($bufferMem < 1.0) {
				$totalMem *= 1024;
				$bufferMem *= 1024;
				if ($totalMemUnit eq "GB") {
					$totalMemUnit = "MB";
				} elsif ($totalMemUnit eq "MB") {
					$totalMemUnit = "kB";
				}
			}
			$bufferMem = floor($bufferMem);
			print "shared_buffers = $bufferMem, totalMemUnit = $totalMemUnit\n";

			print " In postgresqlService::configure setting shared_buffers to $bufferMem$totalMemUnit\n";
			print FILEOUT "shared_buffers = $bufferMem$totalMemUnit\n";

		}
		else {
			print FILEOUT $inline;
		}
	}
	elsif ( $inline =~ /^\s*effective_cache_size\s*=\s*(.*)/ ) {
		my $origValue = $1;

		# If postgresqlEffectiveCacheSize was set, then use it
		# as the value. Otherwise, if postgresqlEffectiveCacheSizePct
		# was set, use that percentage of total memory,
		# otherwise use what was in the original file
		if ($postgresqlEffectiveCacheSize) {
			print FILEOUT "effective_cache_size = "
			  . $postgresqlEffectiveCacheSize . "\n";

		}
		elsif ($postgresqlEffectiveCacheSizePct) {
			print "Setting effective_cache_size based on totalMem = $totalMem, totalMemUnit = $totalMemUnit, postgresqlEffectiveCacheSizePct = $postgresqlEffectiveCacheSizePct\n";

			if ( $postgresqlEffectiveCacheSizePct > 1 ) {
				die "postgresqlEffectiveCacheSizePct must be less than 1";
			}

			my $bufferMem = $totalMem * $postgresqlEffectiveCacheSizePct ;
			if ($bufferMem < 1.0) {
				$totalMem *= 1024;
				$bufferMem *= 1024;
				if ($totalMemUnit eq "GB") {
					$totalMemUnit = "MB";
				} elsif ($totalMemUnit eq "MB") {
					$totalMemUnit = "kB";
				}
			}
			$bufferMem = floor($bufferMem);
			print "effective_cache_size = $bufferMem, totalMemUnit = $totalMemUnit\n";

			print FILEOUT "effective_cache_size = $bufferMem$totalMemUnit\n";

		}
		else {
			print FILEOUT $inline;
		}
	}
	elsif ( $inline =~ /^\s*max_connections\s*=\s*(\d*)/ ) {
		my $origValue = $1;
		if ($postgresqlMaxConnections) {
			print FILEOUT "max_connections = "
			  . $postgresqlMaxConnections . "\n";

		}
		else {
			print FILEOUT $inline;
		}
	}
	elsif ( $inline =~ /^\s*port\s*=\s*(\d*)/ ) {
		print FILEOUT "port = '" . $port . "'\n";
	}
	else {
		print FILEOUT $inline;
	}

}
close FILEIN;
close FILEOUT;
`chown postgres:postgres /mnt/dbData/postgresql/postgresql.conf`;

print "Configured postgresql.conf\n";


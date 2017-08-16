#!/usr/bin/perl

use strict;
use POSIX;

my $port     = $ENV{'POSTGRESPORT'};
my $totalMem = $ENV{'POSTGRESTOTALMEM'};
my $totalMemUnit = $ENV{'POSTGRESTOTALMEMUNIT'};
my $postgresqlSharedBuffers = $ENV{'POSTGRESSHAREDBUFFERS'};
my $postgresqlSharedBuffersPct = $ENV{'POSTGRESSHAREDBUFFERSPCT'};
my $postgresqlEffectiveCacheSize = $ENV{'POSTGRESEFFECTIVECACHESIZE'};
my $postgresqlEffectiveCacheSizePct = $ENV{'POSTGRESEFFECTIVECACHESIZEPCT'};
my $postgresqlMaxConnections = $ENV{'POSTGRESMAXCONNECTIONS'};


if (!$totalMem || !$totalMemUnit) {
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
			elsif ($postgresqlSharedBuffersPct ) {

				my $bufferMem = floor( $totalMem * $postgresqlSharedBuffersPct );

				if ( $bufferMem > $totalMem ) {
					die "postgresqlSharedBuffersPct must be less than 1";
				}

				#					print $self->meta->name
				#					  . " In postgresqlService::configure setting shared_buffers to $bufferMem$totalMemUnit\n";
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
			if ( $postgresqlEffectiveCacheSize ) {
				print FILEOUT "effective_cache_size = " . $postgresqlEffectiveCacheSize . "\n";

			}
			elsif ( $postgresqlEffectiveCacheSizePct ) {

				my $bufferMem = floor( $totalMem * $postgresqlEffectiveCacheSizePct );

				if ( $bufferMem > $totalMem ) {
					die "postgresqlEffectiveCacheSizePct must be less than 1";
				}

				print FILEOUT "effective_cache_size = $bufferMem$totalMemUnit\n";

			}
			else {
				print FILEOUT $inline;
			}
		}
		elsif ( $inline =~ /^\s*max_connections\s*=\s*(\d*)/ ) {
			my $origValue = $1;
			if ( $postgresqlMaxConnections ) {
				print FILEOUT "max_connections = " . $postgresqlMaxConnections . "\n";

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
	`chown postgres:postgres /mnt/dbData/postgresql/postgresql.conf`
	
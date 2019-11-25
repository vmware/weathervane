# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package ParseGC;

use strict;
use Statistics::Descriptive;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA       = qw( Exporter);
	@EXPORT_OK = qw( parseGCLog );
}

sub parseGCLog {

	my ( $gcLogDir, $gcFileSuffix, $gcviewerDir ) = @_;
	my $logger = get_logger("Weathervane::StatsParsers::ParseGC");	
    tie( my %retVal, 'Tie::IxHash' );
	
	my (
		$totalGCPauseTime, $fullGCPauseTime, $minorGCPauseTime, $avgHeapAfterFullGC,
		$gcTotLoadPct,     $avgMinorGCPause, $avgFullGCPause
	  )
	  = ( 0, 0, 0, 0, 0, 0, 0 );

	# Create a gc log without ramp-up entries
	open( GCFILE,     "$gcLogDir/gc${gcFileSuffix}.log" ) or do {
		#print "Error parsing GC stats. Can't open $gcLogDir/gc${gcFileSuffix}.log: $!\n";	
		return \%retVal;
	};
	open( GCRAMPFILE, "$gcLogDir/gc${gcFileSuffix}_rampup.log" ) or do {
		#print "Error parsing GC stats. Can't open $gcLogDir/gc${gcFileSuffix}_rampup.log: $!\n";	
		return \%retVal;
	};
	open( STDYGCFILE, ">$gcLogDir/gc${gcFileSuffix}_stdy.log" ) or do {
		#print "Error parsing GC stats. Can't open $gcLogDir/gc${gcFileSuffix}_stdy.log: $!\n";	
		return \%retVal;
	};

	# skip all of the lines in the gc log that are also in the log from ramp-up
	while (<GCRAMPFILE>) {
		<GCFILE>;
	}
	while ( my $inline = <GCFILE> ) {
		print STDYGCFILE $inline;
	}
	close GCFILE;
	close GCRAMPFILE;
	close STDYGCFILE;

	# First run gcviewer on the gc.log
	my $out = `java -jar $gcviewerDir/gcviewer-1.34-SNAPSHOT.jar $gcLogDir/gc${gcFileSuffix}_stdy.log $gcLogDir/gc${gcFileSuffix}_parsed.csv 2>&1`;
	
	# Parse out the main stats from gc_parsed
	open( RESULTFILE, "$gcLogDir/gc${gcFileSuffix}_parsed.csv" );

	while ( my $inline = <RESULTFILE> ) {

		if ( $inline =~ /gcPause;\s(\d+(\.\d+)?);/ ) {
			$minorGCPauseTime = $1;
			$minorGCPauseTime =~ s/,//g;
		}
		elsif ( $inline =~ /fullGCPause;\s(\d+(\.\d+)?);/ ) {
			$fullGCPauseTime = $1;
			$fullGCPauseTime =~ s/,//g;
		}
		elsif ( $inline =~ /accumPause;\s(\d+(,\d+)?\.\d+);/ ) {
			$totalGCPauseTime = $1;
			$totalGCPauseTime =~ s/,//g;
		}
		elsif ( $inline =~ /throughput;\s(\d+(\.\d+)?);/ ) {
			$gcTotLoadPct = 100 - $1;
			$gcTotLoadPct =~ s/,//g;
		}
		elsif ( $inline =~ /avgGCPause;\s(\d+(\.\d+)?);/ ) {
			$avgMinorGCPause = $1;
			$avgMinorGCPause =~ s/,//g;
		}
		elsif ( $inline =~ /avgFullGCPause;\s(\d+(\.\d+)?);/ ) {
			$avgFullGCPause = $1;
			$avgFullGCPause =~ s/,//g;
		}
		elsif ( $inline =~ /avgfootprintAfterFullGC;\s(\d+(,\d\d\d)?\.\d+);/ ) {

			# remove any commas from result
			$avgHeapAfterFullGC = $1;
			$avgHeapAfterFullGC =~ s/,//g;
		}

	}
	close RESULTFILE;

	tie( my %retVal, 'Tie::IxHash' );
	%retVal = (
		"totalGCPauseTime" => $totalGCPauseTime, 
		"fullGCPauseTime" => $fullGCPauseTime, 
		"minorGCPauseTime" => $minorGCPauseTime, 
		"avgHeapAfterFullGC" => $avgHeapAfterFullGC,
		"gcTotLoadPct" => $gcTotLoadPct,     
		"avgMinorGCPause" => $avgMinorGCPause, 
		"avgFullGCPause" => $avgFullGCPause
	);
	
	return \%retVal;

}

1;

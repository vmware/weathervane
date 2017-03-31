# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
package ParseSar;

use strict;
use Statistics::Descriptive;
use Tie::IxHash;

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA       = qw( Exporter);
	@EXPORT_OK = qw( parseSar );
}

sub parseSar {
	my ( $sarFileDir, $sarFileName ) = @_;

	open SARFILE, "$sarFileDir/$sarFileName";

	my ($cpuIdle);
	my ( %tps, %mbRead, %mbWrtn, %await );
	my ( $rtps,   $wtps );
	my ( %rxMbps, %txMbps );
	my ( %rxPckS, %txPckS );
	my $swapping = 0;
	my $netErr   = 0;
	$cpuIdle = Statistics::Descriptive::Full->new();
	$rtps    = Statistics::Descriptive::Full->new();
	$wtps    = Statistics::Descriptive::Full->new();

	my $inCPU         = 0;
	my $inMem         = 0;
	my $inDisk        = 0;
	my $inDiskAverage = 0;

	my $inTpsDisk    = 0;
	my $inNet        = 0;
	my $inNetAverage = 0;

	my $inNetErr = 0;
	my @inline;
	while ( my $inline = <SARFILE> ) {

		if ( $inCPU && ( $inline =~ /\d\d:\d\d:\d\d\s..\s+all/ ) ) {
			@inline = split( /\s+/, $inline );
			$cpuIdle->add_data( $inline[$#inline] );
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s..\s+CPU\s+\%usr/ ) {
			$inCPU = 1;
		}

		if ( $inCPU && ( $inline =~ /Average:\s+all/ ) ) {
			$inCPU = 0;
		}

		if ($inMem) {
			if ( $inline =~ /Average:/ ) {
				$inMem  = 0;
				@inline = split( /\s+/, $inline );

				# if any major faults, then there was some swapping
				if ( $inline[4] > 1 ) {
					$swapping = 1;
				}
			}
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s.+majflt/ ) {
			$inMem = 1;
		}

		if ($inDisk) {
			@inline = split( /\s+/, $inline );
			if ( ( $inDiskAverage == 1 ) && !( $inline[0] =~ /Average/ ) ) {
				$inDiskAverage = 0;
				$inDisk        = 0;
			}
			elsif ( ( $inline[0] =~ /Average/ ) && ( $inline[1] =~ /^sd/ ) ) {

				# Only count disks starting with sd
				if ( !exists( $tps{ $inline[1] } ) ) {
					$tps{ $inline[1] }    = Statistics::Descriptive::Full->new();
					$mbRead{ $inline[1] } = Statistics::Descriptive::Full->new();
					$mbWrtn{ $inline[1] } = Statistics::Descriptive::Full->new();
					$await{ $inline[1] }  = Statistics::Descriptive::Full->new();
				}
				$tps{ $inline[1] }->add_data( $inline[2] );
				$mbRead{ $inline[1] }->add_data( $inline[3] * 512 / ( 1024 * 1024 ) );
				$mbWrtn{ $inline[1] }->add_data( $inline[4] * 512 / ( 1024 * 1024 ) );
				$await{ $inline[1] }->add_data( $inline[7] );
				$inDiskAverage = 1;
			}
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s.+DEV/ ) {
			$inDisk = 1;
		}

		if ($inTpsDisk) {
			@inline = split( /\s+/, $inline );
			if ( $inline[0] =~ /Average/ ) {
				$rtps->add_data( $inline[2] );
				$wtps->add_data( $inline[3] );
				$inTpsDisk = 0;
			}
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s.+rtps/ ) {
			$inTpsDisk = 1;
		}

		if ($inNet) {
			if ( $inline =~ /Average/ ) {
				$inNet = 0;
			}
			else {
				@inline = split( /\s+/, $inline );
				if ( !exists( $rxMbps{ $inline[2] } ) ) {
					$rxMbps{ $inline[2] } = Statistics::Descriptive::Full->new();
					$txMbps{ $inline[2] } = Statistics::Descriptive::Full->new();
					$rxPckS{ $inline[2] } = Statistics::Descriptive::Full->new();
					$txPckS{ $inline[2] } = Statistics::Descriptive::Full->new();
				}
				$rxMbps{ $inline[2] }->add_data( $inline[5] * 8 / 1024 );
				$txMbps{ $inline[2] }->add_data( $inline[6] * 8 / 1024 );
				$rxPckS{ $inline[2] }->add_data( $inline[3] );
				$txPckS{ $inline[2] }->add_data( $inline[4] );
			}
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s.+IFACE\s+rxpck/ ) {
			$inNet = 1;
		}

		if ($inNetErr) {
			if ( $inline =~ /Average/ ) {
				$inNetErr = 0;
			}
			else {
				@inline = split( /\s+/, $inline );

				# if any packets are dropped, note error
				if ( ( $inline[3] + $inline[4] + $inline[6] + $inline[6] ) > 1 ) {
					$netErr = 1;
				}
			}
		}

		if ( $inline =~ /\d\d:\d\d:\d\d\s.+IFACE\s+rxerr/ ) {
			$inNetErr = 1;
		}

	}
	close SARFILE;

	# get the overall disk usage and the overall average wait
	my ( $totalTps, $totalMBRead, $totalMBWrtn, $avgWait ) = ( 0, 0, 0, 0 );
	foreach my $key ( keys %tps ) {
		$totalTps    += $tps{$key}->mean();
		$totalMBRead += $mbRead{$key}->mean;
		$totalMBWrtn += $mbWrtn{$key}->mean;
	}

	# compute average wait weighted by tps per disk
	if ( $totalTps > 0 ) {
		foreach my $key ( keys %tps ) {
			$avgWait += ( $tps{$key}->mean() / $totalTps ) * $await{$key}->mean;
		}
	}
	else {
		$avgWait = 0;
	}

	# get the overall network usage
	my ( $totalRxMbps, $totalTxMbps, $totalRxPckS, $totalTxPckS ) = ( 0, 0, 0, 0 );
	foreach my $key ( keys %rxMbps ) {
		$totalRxMbps += $rxMbps{$key}->mean;
		$totalTxMbps += $txMbps{$key}->mean;
		$totalRxPckS += $rxPckS{$key}->mean;
		$totalTxPckS += $txPckS{$key}->mean;
	}

	tie (my %retVal, 'Tie::IxHash');

	%retVal =  (
		"cpuUT" => 100 - $cpuIdle->mean(), 
		"cpuIdle_stdDev" => $cpuIdle->standard_deviation(), 
		"readTPS" => $rtps->mean(), 
		"writeTPS" => $wtps->mean(), 
		"mbRead" => $totalMBRead, 
		"mbWrtn" => $totalMBWrtn,
		"avgWait" => $avgWait,               
		"swapping" => $swapping,    
		"rxPck/s" => $totalRxPckS, 
		"txPck/s" => $totalTxPckS,  
		"rxMbps" => $totalRxMbps,  
		"txMbps" => $totalTxMbps, 
		"netErr" => $netErr
	);
	
	return \%retVal;

}

1;
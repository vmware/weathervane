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
package ESXiHost;

use Moose;
use MooseX::Storage;
use ComputeResources::VIHost;
use StatsParsers::ParseEsxtop qw( parseEsxtop );
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'VIHost';

has 'esxtopPid' => (
	is  => 'rw',
	isa => 'Int',
	default => 0,
);

override 'initialize' => sub {
	my ($self) = @_;
	super();
};

sub stopStatsCollection {
	my ($self) = @_;
	if ($self->esxtopPid) {
		kill 'KILL', $self->esxtopPid;
		$self->esxtopPid(0);
	}
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $console_logger   = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
	
	# Stop any old Weathervane-started esxtop processes
	my $oldPidLines = `ps x | grep -E "sh -c.*wv.esx" | grep -v grep`;
	$logger->debug("Killing old esxtop processes.  Found: " . $oldPidLines);
	my @oldPidLines = split /\n/, $oldPidLines; 
	foreach my $line (@oldPidLines) {
		$line =~ /^\s*(\d+)\s/;
		$logger->debug("Killing old esxtop process $1");
		`kill -9 $1`;
	}
	
	my $hostname         = $self->name;
	my $configDir        = $self->getParamValue('configDir');
	my $cmdString = "scp -o 'StrictHostKeyChecking no' $configDir/esxtop/wv.esxtoprc $hostname:. 2>&1";
	$logger->debug("Command to copy esxtoprc to $hostname: " . $cmdString);
	my $cmdOut = `$cmdString`;
	$logger->debug("Copied wv.esxtoprc to $hostname. cmdOut is: " . $cmdOut);
	
	$logger->debug("Starting stats collection for ESXi Host " . $hostname);
	$self->esxtopPid(fork());
	if ( $self->esxtopPid == 0 ) {
		my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
		my $console_logger = get_logger("Console");
		
		if (!$numIntervals) {
			# If numIntervals == 0, then run for a maximum of 4 hours
			$numIntervals = (4 * 60 * 60) / $intervalLengthSec;
		}
		$cmdString = "ssh -o 'StrictHostKeyChecking no' root\@$hostname esxtop -c wv.esxtoprc -b -d  $intervalLengthSec -n $numIntervals > /tmp/${hostname}_esxtop.csv 2>/tmp/${hostname}_esxtop.stderr";
		$logger->debug("esxtop command for $hostname is: " . $cmdString);
		$cmdOut = `$cmdString`;
		exit;
	}
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
	my $hostname = $self->name;
	if (-e "/tmp/${hostname}_esxtop.csv") {	
		if (-s "/tmp/${hostname}_esxtop.csv") {
			my $hostname         = $self->name;
			$logger->debug("Gathering stats file /tmp/${hostname}_esxtop.csv for ESXi Host " . $hostname);
			`cp /tmp/${hostname}_esxtop.csv $destinationPath/${hostname}_esxtop.csv`;
		} else {
			$logger->warn("Not gathering stats file /tmp/${hostname}_esxtop.csv for ESXi Host " . $hostname,
			". File is empty.");					
		}
	} else {
		$logger->warn("Not gathering stats file /tmp/${hostname}_esxtop.csv for ESXi Host " . $hostname,
		". File does not exist.");		
	}
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
	my $hostname         = $self->name;
	$logger->debug("Removing stats file /tmp/${hostname}_esxtop.csv for ESXi Host " . $hostname);
	`rm -f /tmp/${hostname}_esxtop.csv 2>&1`;
	`rm -f /tmp/${hostname}_esxtop.stderr 2>&1`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
	my $hostname = $self->name;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");

	my $hostname = $self->name;

}

sub parseLogFiles {
	my ($self) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");

	my $hostname = $self->name;
}

sub getEsxtopPctUsed {
	my ( $self, $esxtopDir, $esxtopFileName, $vmName ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");

	my ( $pctUsed, $vmPctUsed ) = ( "notFound", "notFound" );
	if (-e "$esxtopDir/$esxtopFileName") {	

		open REPORTFILE, "$esxtopDir/$esxtopFileName"
		  or die "Can't open file $esxtopDir/$esxtopFileName: $!\n";

		while ( my $inline = <REPORTFILE> ) {

			if ( $inline =~ /^Total\saverage\sCPU\sutilization\s=\s(\d+\.\d+)/ )
			{

				$pctUsed = $1;

			}
			elsif ( $inline =~ /^Statistics for VM\s$vmName/ ) {
				$inline = <REPORTFILE>;
				$inline =~ /^CPU Pct Used = ([\d\.]+),/;

				$vmPctUsed = $1;
				last;

			}

		} 
		close REPORTFILE;
	} else {
		$logger->warn("Can't compute esxtop percent Used. File $esxtopDir/$esxtopFileName does not exist.");
	}
	return ( $pctUsed, $vmPctUsed );
}

sub getStatsSummary {
	my ( $self, $statsFilePath, $users ) = @_;
	my $logger         = get_logger("Weathervane::Hosts::ESXiHost");
	my $hostname     = $self->name;
	$logger->debug("getStatsSummary for ESXi Host " . $hostname);

	tie( my %csv, 'Tie::IxHash' );
	if (-e "$statsFilePath/$hostname/${hostname}_esxtop.csv") {	
		my $statsFileDir = $statsFilePath . "/" . $hostname;

		my $csvRef = ParseEsxtop::parseEsxtop(
			"$statsFileDir/${hostname}_esxtop.csv",        1,
			"$statsFileDir/${hostname}_esxtop_report.txt", '',
			"$statsFileDir/${hostname}_esxtop_summary",    0,
			0,                                             1,
			'',                                            1,
			'',                                            '',
			'',                                            1,
			'',                                            '',
			"$statsFilePath/vmEsxtopSummary.csv"
		);

		`gzip $statsFileDir/${hostname}_esxtop.csv`;

		foreach my $key ( keys %$csvRef ) {
			$csv{"${hostname}_$key"} = $csvRef->{$key};
		}

	   # Add per-user stats
	   #	foreach my $key ( keys %$csvRef ) {
	   #		$csv{"${hostname}_${key}_perUser"} = $csvRef->{$key} / ($users * 1.0);
	   #	}
	} else {
		$logger->warn("Can't compute esxtop stats summary. File $statsFilePath/$hostname/${hostname}_esxtop.csv does not exist.");
	}
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

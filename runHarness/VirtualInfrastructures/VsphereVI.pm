# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package VsphereVI;

use Moose;
use MooseX::Storage;

use VirtualInfrastructures::VirtualInfrastructure;

use namespace::autoclean;
use Log::Log4perl qw(get_logger);

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'VirtualInfrastructure';

has '+name' => ( default => 'vsphere', );

override 'initialize' => sub {
	my ($self) = @_;
	super();

};
override 'initializeVmInfo' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	if ($self->getParamValue('logLevel') >= 4) {

		# get information on all of the VMs on the hosts
		my $vmsInfoHashRef = $self->vmsInfoHashRef;
		my $hostsRef       = $self->hosts;
		foreach my $host (@$hostsRef) {
			my $viHostname = $host->name;
			$logger->debug("Getting VM info for virtual-infrastructure host $viHostname");
			my @vmInfo = `ssh  -o 'StrictHostKeyChecking no' root\@$viHostname vim-cmd /vmsvc/getallvms 2>&1`;
			foreach my $vmInfo (@vmInfo) {
				if ( $vmInfo =~ /(\d+)\s+([^\s]*)\s+\[(.*)\]\s+([^\s]+).*/ ) {
					my ( $vmid, $vmName, $datastore, $file ) = ( $1, $2, $3, $4 );
					$logger->debug("Found VM $vmName: vmid = $vmid, datastore = $datastore, file = $file");
					my %vmInfo = (
						"hostname"  => $viHostname,
						"vmid"      => $vmid,
						"datastore" => $datastore,
						"file"      => $file,
					);
					$vmsInfoHashRef->{$vmName} = \%vmInfo;
				}
			}
		}
	}
};

sub getVMPowerState {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my %vmList;
	my $vmsInfoHashRef = $self->vmsInfoHashRef;
	foreach my $vmName ( keys %$vmsInfoHashRef ) {
		my $vmInfoHashRef = $vmsInfoHashRef->{$vmName};
		my $vmid          = $vmInfoHashRef->{"vmid"};
		my $viHostname    = $vmInfoHashRef->{"hostname"};

		# get current power state
		$logger->debug("Checking powerstate for vm $vmName, vmid = $vmid, on host $viHostname");
		my @vmState = `ssh  -o 'StrictHostKeyChecking no' root\@$viHostname vim-cmd /vmsvc/power.getstate $vmid`;
		my $powerState = 0;    # default 0 = off
		if ( $vmState[1] =~ /on/ ) {
			$powerState = 1;
		}
		$logger->debug("For vm $vmName, powerState = $powerState");
		$vmList{$vmName} = $powerState;
	}

	return \%vmList;
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	$logger->debug("startStatsCollection");
	# Start stats collection on management host
	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->startStatsCollection( $intervalLengthSec, $numIntervals );
	}
	
	# Stop any old Weathervane-started esxtop processes
	my $oldPidLines = `ps x | grep -E "ssh.*wv.esx" | grep -v "sh -c" | grep -v grep`;
	$logger->debug("Killing old esxtop processes.  Found:\n" . $oldPidLines);
	my @oldPidLines = split /\n/, $oldPidLines; 
	foreach my $line (@oldPidLines) {
		$line =~ /^\s*(\d+)\s/;
		$logger->debug("Killing old esxtop process $1");
		my $out = `kill -9 $1 2>&1`;
		$logger->debug("Output from killing old esxtop process $1: $out");
	}
	
	# start stats collection on all VI hosts
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("startStatsCollection on " . $host->name);
		$host->startStatsCollection( $intervalLengthSec, $numIntervals );
	}
}

sub stopStatsCollection {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");
	$logger->debug("stopStatsCollection ");

	# stop stats collection on management host
	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->stopStatsCollection();
	}
	
	# stop stats collection on all VI hosts
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("stopStatsCollection on " . $host->name);
		$host->stopStatsCollection();
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");
	$logger->debug("getStatsFiles ");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		my $destinationPath = $baseDestinationPath . "/" . $host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getStatsFiles($destinationPath);
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getStatsFiles on " . $host->name);
		my $destinationPath = $baseDestinationPath . "/" . $host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getStatsFiles($destinationPath);
	}

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->cleanStatsFiles();
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("cleanStatsFiles on " . $host->name);
		$host->cleanStatsFiles();
	}

}

sub getLogFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		my $destinationPath = $baseDestinationPath . "/" . $host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getLogFiles($destinationPath);
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getLogFiles on " . $host->name);
		my $destinationPath = $baseDestinationPath . "/" . $host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getLogFiles($destinationPath);
	}

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->cleanLogFiles();
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("cleanLogFiles on " . $host->name);
		$host->cleanLogFiles();
	}

}

sub parseLogFiles {
	my ($self) = @_;

	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");
	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->parseLogFiles();
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("parseLogFiles on " . $host->name);
		$host->parseLogFiles();
	}

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		$host->getConfigFiles($destinationPath);
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getConfigFiles on " . $host->name);
		$host->getConfigFiles($destinationPath);
	}

}

sub getStatsSummary {
	my ( $self, $statsFilePath, $users ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $headers = "";
	tie( my %csv, 'Tie::IxHash' );

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		my $destinationPath = $statsFilePath . "/" . $host->name;
    	my $tmpCsvRef;
		$tmpCsvRef = $host->getStatsSummary( $destinationPath, $users );
		@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getStatsSummary on " . $host->name);
		my $destinationPath         = $statsFilePath;
		my $tmpCsvRef               = $host->getStatsSummary( $destinationPath, $users );
		@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
	}

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

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
package VsphereVI;

use Moose;
use MooseX::Storage;

use VirtualInfrastructures::VirtualInfrastructure;

use namespace::autoclean;
use Log::Log4perl qw(get_logger);

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'VirtualInfrastructure';

has '+name' => ( default => 'vsphere', );

has '+version' => ( default => '5.5', );

has '+description' => ( default => 'VMware vSphere 5.5', );

override 'initialize' => sub {
	my ($self) = @_;
	super();

};
override 'initializeVmInfo' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	if ( ( $self->getParamValue('logLevel') >= 4 ) || ( $self->getParamValue('powerOnVms') )
		|| ( $self->getParamValue('powerOffVms') ) ) {

		# get information on all of the VMs on the hosts
		my $vmsInfoHashRef = $self->vmsInfoHashRef;
		my $hostsRef       = $self->hosts;
		foreach my $host (@$hostsRef) {
			my $viHostname = $host->hostName;
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

sub powerOnVM {
	my ( $self, $vmName ) = @_;
	my $vmsInfoHashRef = $self->vmsInfoHashRef;
	my $vmInfoHashRef  = $vmsInfoHashRef->{$vmName};
	my $vmid           = $vmInfoHashRef->{"vmid"};
	my $viHostname     = $vmInfoHashRef->{"hostname"};

	# TODO Need error handling
	`ssh  -o 'StrictHostKeyChecking no' root\@$viHostname vim-cmd /vmsvc/power.on $vmid`;

}

sub powerOffVM {
	my ( $self, $vmName ) = @_;
	my $vmsInfoHashRef = $self->vmsInfoHashRef;
	my $vmInfoHashRef  = $vmsInfoHashRef->{$vmName};
	my $vmid           = $vmInfoHashRef->{"vmid"};
	my $viHostname     = $vmInfoHashRef->{"hostname"};

	# TODO Need error handling
	`ssh  -o 'StrictHostKeyChecking no' root\@$viHostname vim-cmd /vmsvc/power.shutdown $vmid`;

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
	
	# start stats collection on all VI hosts
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("startStatsCollection on " . $host->hostName);
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
		$logger->debug("stopStatsCollection on " . $host->hostName);
		$host->stopStatsCollection();
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");
	$logger->debug("getStatsFiles ");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		my $destinationPath = $baseDestinationPath . "/" . $host->hostName;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getStatsFiles($destinationPath);
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getStatsFiles on " . $host->hostName);
		my $destinationPath = $baseDestinationPath . "/" . $host->hostName;
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
		$logger->debug("cleanStatsFiles on " . $host->hostName);
		$host->cleanStatsFiles();
	}

}

sub getLogFiles {
	my ( $self, $baseDestinationPath ) = @_;
	my $logger = get_logger("Weathervane::VirtualInfrastructures:VsphereVI");

	my $hostsRef = $self->managementHosts;
	foreach my $host (@$hostsRef) {
		my $destinationPath = $baseDestinationPath . "/" . $host->hostName;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$host->getLogFiles($destinationPath);
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getLogFiles on " . $host->hostName);
		my $destinationPath = $baseDestinationPath . "/" . $host->hostName;
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
		$logger->debug("cleanLogFiles on " . $host->hostName);
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
		$logger->debug("parseLogFiles on " . $host->hostName);
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
		$logger->debug("getConfigFiles on " . $host->hostName);
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
		my $destinationPath = $statsFilePath . "/" . $host->hostName;
    	my $tmpCsvRef;
		$tmpCsvRef = $host->getStatsSummary( $destinationPath, $users );
		@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
	}
	
	$hostsRef = $self->hosts;
	foreach my $host (@$hostsRef) {
		$logger->debug("getStatsSummary on " . $host->hostName);
		my $destinationPath         = $statsFilePath;
		my $tmpCsvRef               = $host->getStatsSummary( $destinationPath, $users );
		@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
	}

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

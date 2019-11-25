# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package WorkloadDriverFactory;

use Moose;
use MooseX::Storage;
use WorkloadDrivers::AuctionWorkloadDriver;
use WorkloadDrivers::AuctionKubernetesWorkloadDriver;
use Parameters qw(getParamValue);
use WeathervaneTypes;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getWorkloadDriver {
	my ( $self, $workloadDriverHashRef, $host ) = @_;
	
	my $hostType = ref $host;
	my $workloadType = $workloadDriverHashRef->{"workloadImpl"};
	
	if ( !( $workloadType ~~ @WeathervaneTypes::workloadImpls ) ) {
		die "No matching workloadDriver for workload type $workloadType";
	}

	my $workloadDriver;
	if ( $workloadType eq "auction" ) {
		if ($hostType eq "KubernetesCluster") {
			$workloadDriver = AuctionKubernetesWorkloadDriver->new(
				paramHashRef => $workloadDriverHashRef
			);
		} else {
			$workloadDriver = AuctionWorkloadDriver->new(
				paramHashRef => $workloadDriverHashRef
			);
		}
	}
	else {
		die "No matching workloadDriver for workload type $workloadType";
	}

	return $workloadDriver;
}

__PACKAGE__->meta->make_immutable;

1;

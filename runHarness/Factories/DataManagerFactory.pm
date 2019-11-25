# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package DataManagerFactory;

use Moose;
use MooseX::Storage;
use DataManagers::AuctionDataManager;
use DataManagers::AuctionKubernetesDataManager;
use Parameters qw(getParamValue);
use WeathervaneTypes;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getDataManager {
	my ( $self, $paramHashRef, $appInstance, $host ) = @_;
	my $workloadType = $paramHashRef->{"workloadImpl"};
	my $hostType = ref $host;

	if ( !( $workloadType ~~ @WeathervaneTypes::workloadImpls ) ) {
		die "No matching dataManager for workload type $workloadType";

	}

	my $dataManager;
	if ( $workloadType eq "auction" ) {
		if ($hostType eq "KubernetesCluster") {
			$dataManager = AuctionKubernetesDataManager->new( 'paramHashRef' => $paramHashRef,
			'appInstance' => $appInstance );
		} else {
			$dataManager = AuctionDataManager->new( 'paramHashRef' => $paramHashRef,
			'appInstance' => $appInstance );
		}
	}
	else {
		die "No matching workloadDriver for workload type $workloadType";
	}

	return $dataManager;
}

__PACKAGE__->meta->make_immutable;

1;

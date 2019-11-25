# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AppInstanceFactory;

use Moose;
use MooseX::Storage;
use AppInstance::AuctionAppInstance;
use AppInstance::AuctionKubernetesAppInstance;
use Parameters qw(getParamValue);
use WeathervaneTypes;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getAppInstance {
	my ( $self, $applicationParamHashRef, $host ) = @_;

	my $applicationImpl = $applicationParamHashRef->{'workloadImpl'};

	if ( !( $applicationImpl ~~ @WeathervaneTypes::workloadImpls ) ) {
		die "No matching application for workload $applicationImpl";
	}

	my $application;
	if ( $applicationImpl eq "auction" ) {
		if ($host && ((ref $host) eq "KubernetesCluster")) {
			$application = AuctionKubernetesAppInstance->new( paramHashRef => $applicationParamHashRef );
		} else {
			$application = AuctionAppInstance->new( paramHashRef => $applicationParamHashRef );			
		}
	}
	else {
		die "No matching application for workload type $applicationImpl";
	}

	return $application;
}

__PACKAGE__->meta->make_immutable;

1;

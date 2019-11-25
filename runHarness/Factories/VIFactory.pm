# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package VIFactory;

use Moose;
use MooseX::Storage;
use VirtualInfrastructures::VsphereVI;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getVI {
	my ( $self, $paramHashRef ) = @_;
	my $vi;
	my $viType = $paramHashRef->{'virtualInfrastructureType'};
	if ( $viType eq "vsphere" ) {
		$vi = VsphereVI->new(
			'paramHashRef' => $paramHashRef
		);
	}
	else {
		die "No matching Virtual Infrastructure type available to VIFactory";
	}

	$vi->initialize();

	return $vi;
}

__PACKAGE__->meta->make_immutable;

1;

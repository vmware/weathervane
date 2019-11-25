# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package WorkloadFactory;

use Moose;
use MooseX::Storage;
use Workload::Workload;
use Parameters qw(getParamValue);
use WeathervaneTypes;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getWorkload {
	my ( $self, $workloadHashRef ) = @_;

	my $workload = Workload->new( paramHashRef => $workloadHashRef );

	return $workload;
}

__PACKAGE__->meta->make_immutable;

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package VIHost;

use Moose;
use MooseX::Storage;
use ComputeResources::Host;
use VirtualInfrastructures::VirtualInfrastructure;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Host';

has 'virtualInfrastructure' => (
	is  => 'rw',
	isa => 'VirtualInfrastructure',
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();
};

sub setVirtualInfrastructure {
	my ( $self, $vi ) = @_;
	$self->virtualInfrastructure($vi);
}

sub getStatsSummary {
	my ($self, $statsFileDir, $users) = @_;
	tie (my %csv, 'Tie::IxHash');
	%csv = ();
	
	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

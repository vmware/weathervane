# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package VirtualInfrastructure;

use Moose;
use MooseX::Storage;

use namespace::autoclean;

use ComputeResources::VIHost;
use Factories::HostFactory;
use WeathervaneTypes;
use Parameters qw(getParamValue);
use Instance;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Instance';

has 'version' => (
	is  => 'ro',
	isa => 'Str',
);

has 'description' => (
	is  => 'ro',
	isa => 'Str',
);

# Attributes for a specific instance
has 'managementHosts' => (
	is  => 'rw',
	isa => 'ArrayRef[VIHost]',
	default => sub { [] },
);

has 'hosts' => (
	is      => 'rw',
	isa     => 'ArrayRef[VIHost]',
	default => sub { [] },
);


has 'vmsInfoHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

# This is a hash from ip address to a list of the VI
# hosts which share that ip address.  For VI hists,
# there really shouldn't be two with the same IP address,
# but this lets us handle that case
my %hostsByIp = ();

override 'initialize' => sub {
	my ( $self ) = @_;

	super();

};

sub addManagementHost {
	my ( $self, $host ) = @_;
	
	push @{ $self->managementHosts }, $host;
}

sub addHost {
	my ( $self, $host ) = @_;

	push @{ $self->hosts }, $host;
}

sub initializeVmInfo {
}

sub stopStatsCollection {
	my ($self) = @_;

}

sub startStatsCollection {
	my ($self) = @_;

}

sub getStatsFiles {
	my ($self) = @_;

}

sub cleanStatsFiles {
	my ($self) = @_;

}

sub getLogFiles {
	my ($self) = @_;

}

sub cleanLogFiles {
	my ($self) = @_;

}

sub parseLogFiles {
	my ($self) = @_;
}

sub toString {
	my ($self) = @_;

	return "Virtual Infrastructure is  " . $self->name() . " with version " . $self->version();
}

__PACKAGE__->meta->make_immutable;

1;

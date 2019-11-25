# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package ComputeResource;

use Moose;
use MooseX::Storage;
use StatsParsers::ParseSar qw(parseSar);
use Parameters qw(getParamValue);
use Instance;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Instance';

has 'servicesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Service]',
);

override 'initialize' => sub {
	my ( $self ) = @_;
	my $console_logger = get_logger("Console");
	
	super();

};

sub registerService {
	my ($self, $serviceRef) = @_;
	my $console_logger = get_logger("Console");
	
	$console_logger->error("registerService called on a Host object that does not support that method.");
	exit(-1);	
}

sub stopStatsCollection {
	my ($self) = @_;

}

sub startStatsCollection {
	my ($self) = @_;

}

sub getLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ($self) = @_;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::ComputeResources::ComputeResource");
	$logger->debug("cleanLogFiles host = ", $self->name);

}

sub parseLogFiles {
	my ($self) = @_;

}

sub getStatsFiles {
	my ($self) = @_;

}

sub cleanStatsFiles {
	my ($self) = @_;

}

sub parseStats {
	my ( $self, $storagePath ) = @_;

}

sub getStatsSummary {
	my ( $self, $storagePath ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package Host;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use Instance;
use Log::Log4perl qw(get_logger);
use ComputeResources::ComputeResource;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'ComputeResource';

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

sub getDockerServiceImages {
	my ($self) = @_;
	return $self->getParamValue('dockerServiceImages');
}


#-------------------------------
# Two hosts are equal if they have the same name
#-------------------------------
sub equals {
	my ( $this, $that ) = @_;

	return $this->name eq $that->name;
}

sub toString {
	my ($self) = @_;

	return "Host name = " . $self->name;
}
__PACKAGE__->meta->make_immutable;

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package Cluster;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use Instance;
use ComputeResources::ComputeResource;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'ComputeResource';

override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

__PACKAGE__->meta->make_immutable;

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package Instance;

use Moose;
use MooseX::Storage;
use Log::Log4perl qw(get_logger);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

has 'name' => (
	is        => 'rw',
	isa       => 'Str',
    default => "",
);

has 'instanceNum' => (
	is        => 'rw',
	isa       => 'Num',
    default => 1,
);

has 'paramHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

sub initialize {
	my ( $self ) = @_;
}

sub getParamValue {
	my ($self, $param) = @_;
	my $console_logger = get_logger("Console");
	my $paramHashRef = $self->paramHashRef;
	
	if (!exists $paramHashRef->{$param}) {
		$console_logger->error("getParamValue. Parameter $param does not exist in parameter hash for class ", $self->meta->name);
		exit -1;
	}
	
	return $paramHashRef->{$param};
}

sub setParamValue {
	my ($self, $param, $value) = @_;
	my $paramHashRef = $self->paramHashRef;
	
	$paramHashRef->{$param} = $value;
}

__PACKAGE__->meta->make_immutable;

1;

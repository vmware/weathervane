# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RunResult;

use Moose;
use MooseX::Storage;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

has 'runNum' => (
	is  => 'rw',
	isa => 'Str',
);

has 'isRunError' => (
	is  => 'rw',
	isa => 'Bool',
);


has 'isPassable' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'isPassed' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'metricsHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'resultsSummaryHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

sub initialize {
	my ( $self, $paramHashRef ) = @_;
	print $self->meta->name . "::initialize: " . $self->toString() . "\n";
}

sub toString {
	my ($self) = @_;
	my $retVal = "Run " . $self->runNum;
	if ( $self->isPassable ) {
		if ( $self->isPassed ) {
			$retVal .= " Passed";
			my $metricsHashRef = $self->metricsHashRef;
			foreach my $key (keys %$metricsHashRef) {
				$retVal .= "; $key = ".$metricsHashRef->{$key};
			}
		}
		else {
			$retVal .= " Failed";
		}
	}
	return $retVal;
}
__PACKAGE__->meta->make_immutable;

1;

# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

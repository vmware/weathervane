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

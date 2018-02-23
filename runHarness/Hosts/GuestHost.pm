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
package GuestHost;

use Moose;
use MooseX::Storage;
use ComputeResources::Host;
use VirtualInfrastructures::VirtualInfrastructure;
use WeathervaneTypes;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Host';

has 'vmName' => (
	is  => 'rw',
	isa => 'Str',
	predicate => 'has_vmName',
);

has 'possibleVmNamesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Str]',
);

has 'serviceType' => (
	is  => 'rw',
	isa => 'ServiceType',
);

has 'osType' => (
	is  => 'rw',
	isa => 'Str',
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	
	# A GuestHost supports power control
	$self->supportsPowerControl(1);
	$self->isGuest(1);
	
	super();
};

sub addVmName {
	my ( $self, $vmName ) = @_;
	my $possibleVmNamesRef = $self->possibleVmNamesRef;
	push @$possibleVmNamesRef, $vmName;
}

sub setVmName {
	my ( $self, $vmName ) = @_;
	$self->vmName($vmName);	
}

__PACKAGE__->meta->make_immutable;

1;

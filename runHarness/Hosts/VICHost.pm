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
package VICHost;

use Moose;
use MooseX::Storage;
use Hosts::Host;
use VirtualInfrastructures::VirtualInfrastructure;
use WeathervaneTypes;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Host';

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	
	super();
};

override 'registerService' => sub {
	my ( $self ) = @_;

};

override 'registerPortNumber' => sub {
	my ( $self ) = @_;

};

override 'unRegisterPortNumber' => sub {
	my ( $self ) = @_;

};

sub restartNtp {
	my ($self) = @_;
}

sub restartNtp {
	my ($self) = @_;
}

sub startNscd {
	my ($self)           = @_;
}

sub stopNscd {
	my ($self)           = @_;
}

__PACKAGE__->meta->make_immutable;

1;

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
package VirtualInfrastructure;

use Moose;
use MooseX::Storage;

use namespace::autoclean;

use Hosts::VIHost;
use Factories::HostFactory;
use WeathervaneTypes;
use Parameters qw(getParamValue);
use Instance;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Instance';

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

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

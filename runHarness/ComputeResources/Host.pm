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
package Host;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use Instance;
use Log::Log4perl qw(get_logger);
use Utils qw(getIpAddresses getIpAddress);
use ComputeResources::ComputeResource;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'ComputeResource';

has 'ipAddr' => (
	is      => 'rw',
	isa     => 'Str',
	builder => '_get_ipAddr',
	lazy    => 1,
);

override 'initialize' => sub {
	my ( $self ) = @_;
	my $console_logger = get_logger("Console");
	

	super();

};

sub _get_ipAddr {
	my ($self) = @_;

	return getIpAddress($self->name);
}

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
# Two hosts are equal if they have the same IP address
#-------------------------------
sub equals {
	my ( $this, $that ) = @_;

	return $this->ipAddr() eq $that->ipAddr;
}

sub toString {
	my ($self) = @_;

	return "Host name = " . $self->name . ", IP Address = " . $self->ipAddr;
}
__PACKAGE__->meta->make_immutable;

1;

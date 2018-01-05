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
package Cluster;

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

has 'clusterName' => (
	is  => 'rw',
	isa => 'Str',
);

has 'servicesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Service]',
);

override 'initialize' => sub {
	my ( $self ) = @_;
	my $console_logger = get_logger("Console");
	
	my $clusterName = $self->getParamValue('clusterName');
	if (!$clusterName) {
		$console_logger->error("Must specify a clusterName for all cluster instances.");
		exit(-1);
	}

	$self->clusterName($clusterName);

	super();

};

sub toString {
	my ($self) = @_;

	return "Cluster name = " . $self->clusterName;
}
__PACKAGE__->meta->make_immutable;

1;

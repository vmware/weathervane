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
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Host';

has 'servicesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Service]',
);

has 'dockerHostString' => (
	is  => 'rw',
	isa => 'Str',
);

# used to track docker names that are used on this host
has 'dockerNameHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;
	super();

	my $hostname   = $self->getParamValue('hostName');
	my $dockerPort = $self->getParamValue('dockerHostPort');
	$self->dockerHostString( "DOCKER_HOST=" . $hostname . ":" . $dockerPort );

};

override 'registerService' => sub {
	my ( $self, $serviceRef ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	my $servicesRef    = $self->servicesRef;

	my $dockerName = $serviceRef->getDockerName();
	$logger->debug( "Registering service $dockerName with host ",
		$self->hostName );

	if ( $serviceRef->useDocker() ) {
		if ( exists $self->dockerNameHashRef->{$dockerName} ) {
			$console_logger->error( "Have two services on host ",
				$self->hostName, " with docker name $dockerName." );
			exit(-1);
		}
		$self->dockerNameHashRef->{$dockerName} = 1;
	}

	push @$servicesRef, $serviceRef;

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

sub startNscd {
	my ($self)           = @_;
}

sub stopNscd {
	my ($self)           = @_;
}

__PACKAGE__->meta->make_immutable;

1;

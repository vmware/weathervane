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
package LinuxGuest;

use Moose;
use MooseX::Storage;
use Services::Service;

use Hosts::GuestHost;
use StatsParsers::ParseSar qw(parseSar);
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);
use JSON;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'GuestHost';

has 'servicesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef[Service]',
);

has 'portMapHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
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

# Services use this method to notify the host that they are using
# a particular port number
override 'registerPortNumber' => sub {
	my ( $self, $portNumber, $service ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "Registering port $portNumber for host ", $self->hostName );

	my $portMapHashRef = $self->portMapHashRef;

	if ( exists $portMapHashRef->{$portNumber} ) {

		# Notify about conflict and exit
		my $conflictService = $portMapHashRef->{$portNumber};
		$console_logger->error(
			"Conflict on port $portNumber on host ",
			$self->hostName,
			". Required by both ",
			$conflictService->getDockerName(),
			" from Workload ",
			$conflictService->getWorkloadNum(),
			" AppInstance ",
			$conflictService->getAppInstanceNum(),
			" and ",
			$service->getDockerName(),
			" from Workload ",
			$service->getWorkloadNum(),
			" AppInstance ",
			$service->getAppInstanceNum(),
			"."
		);
		exit(-1);
	}

	$portMapHashRef->{$portNumber} = $service;
};

override 'unRegisterPortNumber' => sub {
	my ( $self, $portNumber ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "Unregistering port $portNumber for host ",
		$self->hostName );

	my $portMapHashRef = $self->portMapHashRef;
	if ( exists $portMapHashRef->{$portNumber} ) {
		delete $portMapHashRef->{$portNumber};
	}
};

override 'startStatsCollection' => sub {
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $console_logger   = get_logger("Console");
	my $hostname         = $self->hostName;

};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	super();
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	$logger->debug( "StopStatsCollect for " . $self->hostName );

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

	my $hostname         = $self->hostName;

};

override 'cleanStatsFiles' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
		
	super();

};

override 'getLogFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	super($destinationPath);
};

override 'cleanLogFiles' => sub {
	my ($self)   = @_;
	my $logger   = get_logger("Weathervane::Hosts::LinuxGuest");
	super();
};

override 'parseLogFiles' => sub {
	my ($self) = @_;
	super();

};

override 'getConfigFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Hosts::LinuxGuest");
	super();

};

override 'parseStats' => sub {
	my ( $self, $storagePath ) = @_;
	super();

};

override 'getStatsSummary' => sub {
	my ( $self, $statsFileDir ) = @_;
	my $logger   = get_logger("Weathervane::Hosts::LinuxGuest");
	my $hostname = $self->hostName;
	$logger->debug("getStatsSummary on $hostname.");

	my $csvRef = ParseSar::parseSar( $statsFileDir, "${hostname}_sar.txt" );

	my $superCsvRef = super();
	for my $key ( keys %$superCsvRef ) {
		$superCsvRef->{$key} = $superCsvRef->{$key};
	}
	return $csvRef;
};

__PACKAGE__->meta->make_immutable;

1;

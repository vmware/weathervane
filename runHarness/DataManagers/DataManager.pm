# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package DataManager;

use Moose;
use MooseX::Storage;
use Services::Service;
use RunProcedures::RunProcedure;
use Factories::RunProcedureFactory;
use WorkloadDrivers::WorkloadDriver;
use Factories::WorkloadDriverFactory;
use ComputeResources::ComputeResource;
use Instance;
use Log::Log4perl qw(get_logger);

use Parameters qw(getParamValue);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;
extends 'Instance';

has 'appInstance' => (
	is      => 'rw',
	isa     => 'AppInstance',
);

has 'workloadDriver' => (
	is  => 'rw',
	isa => 'WorkloadDriver',
);

has 'host' => (
	is  => 'rw',
	isa => 'ComputeResource',
);

# internalPortMap: A map from a name for a port (e.g. http) to
# the ports used by this service.  This represents the view from
# inside a docker container
has 'internalPortMap' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

# portMap: A map from a name for a port (e.g. http) to
# the port used by this service
has 'portMap' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

override 'initialize' => sub {
	my ( $self ) = @_;
	
	super();

};

sub setHost {
	my ($self, $host) = @_;
	
	$self->host($host);
}
sub setAppInstance {
	my ($self, $appInstance) = @_;
	$self->appInstance($appInstance);
}

sub setWorkloadDriver {
	my ($self, $driver) = @_;
	$self->workloadDriver($driver);
}

sub loadData {
	die "Can only loadData for a concrete sub-class of DataManager";
}

sub prepareDataServices {
	die "Can only prepareDataServices for a concrete sub-class of DataManager";
}

sub prepareData {
	die "Can only prepareData for a concrete sub-class of DataManager";
}

sub isDataLoaded {
	die "Can only check isDataLoaded for a concrete sub-class of DataManager";
}

# This method returns true if both this and the other service are
# running dockerized on the same Docker host and network but are not
# using docker host networking
sub corunningDockerized {
	my ($self, $other) = @_;
	my $logger = get_logger("Weathervane::DataManagers::Datamanager");
	if (((ref $self->host) ne 'DockerHost') || ((ref $other->host) ne 'DockerHost')
		|| ($self->dockerConfigHashRef->{'net'} eq 'host')
		|| ($other->dockerConfigHashRef->{'net'} eq 'host')
		|| ($self->dockerConfigHashRef->{'net'} ne $other->dockerConfigHashRef->{'net'})
		|| !$self->host->equals($other->host)
		|| ($self->host->getParamValue('vicHost') && ($self->dockerConfigHashRef->{'net'} ne "bridge"))) 
	{
		$logger->debug("corunningDockerized: " . $self->name . " and " . $other->name . " are not corunningDockerized");
		return 0;
	} else {
		$logger->debug("corunningDockerized: " . $self->name . " and " . $other->name . " are corunningDockerized");
		return 1;
	}	
	
}

# This method checks whether this service and another service are 
# both running Dockerized on the same host and Docker network.  If so, it
# returns the docker name of the service (so that this service can connect to 
# it directly via the Docker provided /etc/hosts), otherwise it returns the
# hostname of the other service.
# If this service is using Docker host networking, then this method always
# returns the hostname of the other host.
sub getHostnameForUsedService {
	my ($self, $other) = @_;
	my $logger = get_logger("Weathervane::DataManagers::Datamanager");
	
	if ($self->corunningDockerized($other)) 
	{
		$logger->debug("getHostnameForUsedService: Corunning dockerized, returning " . $other->host->dockerGetIp($other->name));
		return $other->host->dockerGetIp($other->name);
	} else {
		$logger->debug("getHostnameForUsedService: Not corunning dockerized, returning " . $other->host->name);
		return $other->host->name;
	}	
}

sub getPortNumberForUsedService {
	my ($self, $other, $portName) = @_;
	my $logger = get_logger("Weathervane::DataManagers::Datamanager");
	
	if ($self->corunningDockerized($other)) 
	{
		$logger->debug("getPortNumberForUsedService: Corunning dockerized, returning " . $other->internalPortMap->{$portName});
		return $other->internalPortMap->{$portName};
	} else {
		$logger->debug("getPortNumberForUsedService: Not corunning dockerized, returning " . $other->portMap->{$portName});
		return $other->portMap->{$portName};
	}	
}

sub toString {
	  my ($self) = @_;

	  return "DataManager " . $self->name();
}

__PACKAGE__->meta->make_immutable;

1;

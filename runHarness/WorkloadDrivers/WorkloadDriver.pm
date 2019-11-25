# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package WorkloadDriver;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use Instance;
use Log::Log4perl qw(get_logger);
use MooseX::ClassAttribute;
use ComputeResources::ComputeResource;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;
extends 'Instance';

has 'description' => (
	is  => 'ro',
	isa => 'Str',
);

has 'host' => (
	is  => 'rw',
	isa => 'ComputeResource',
);


has 'workload' => (
	is  => 'rw',
	isa => 'Workload',
);

class_has 'nextPortMultiplier' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
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
	
	# Assign a name to this driver
	my $workloadNum = $self->workload->instanceNum;
	my $instanceNum = $self->instanceNum;
	$self->name("driverW${workloadNum}I${instanceNum}");

	super();

};

sub redeploy {
	my ($self, $logfile) = @_;
	
}

sub getNextPortMultiplier {
	my ($self, $logfile) = @_;
	my $retVal = $self->nextPortMultiplier;
	$self->nextPortMultiplier($retVal + 1);
	
	return $retVal;
}

sub setWorkload {
	my ($self, $workload) = @_;
	
	$self->workload($workload);
}

sub checkConfig {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	$console_logger->error("Called checkConfig on an abstract instance of WorkloadDriver");

	return 0;
}

sub addSecondary {
	
}

sub configure {

}

sub initializeRun {
	my ( $self, $runNum, $logDir, $suffix ) = @_;
	die "Only PrimaryWorkloadDrivers implement initialize";

}

sub startRun {
	die "Only PrimaryWorkloadDrivers implement start";
}

sub stopRun {
	die "Only PrimaryWorkloadDrivers implement stopRun";
}

sub isUp {
	die "Only PrimaryWorkloadDrivers implement isUp";
}

sub toString {
	my ($self) = @_;

	return "WorkloadDriver " . $self->name();
}

__PACKAGE__->meta->make_immutable;

1;

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

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

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
	my $paramHashRef = $self->paramHashRef;
	
	# Assign a name to this driver
	my $workloadNum = $self->getWorkloadNum();
	my $instanceNum = $self->getParamValue("instanceNum");
	$self->name("driverW${workloadNum}I${instanceNum}")

	my $weathervaneHome        = $paramHashRef->{ 'weathervaneHome' };
	my $workloadDriverDir = $self->getParamValue('workloadDriverDir');
	if ( !( $workloadDriverDir =~ /^\// ) ) {
		$workloadDriverDir = $weathervaneHome . "/" . $workloadDriverDir;
	}
	$self->setParamValue( 'workloadDriverDir', $workloadDriverDir );

	my $distDir = $self->getParamValue('distDir' );
	if ( !( $distDir =~ /^\// ) ) {
		$distDir = $weathervaneHome . "/" . $distDir;
	}
	$self->setParamValue( 'distDir', $distDir );
	
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

sub setHost {
	my ($self, $host) = @_;
	
	$self->host($host);
}

sub setWorkload {
	my ($self, $workload) = @_;
	
	$self->workload($workload);
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

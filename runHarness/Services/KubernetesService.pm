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
package Service;

use Moose;
use MooseX::Storage;
use Tie::IxHash;
use Parameters qw(getParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use POSIX qw(floor);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;
use Log::Log4perl qw(get_logger);
use ComputeResources::ComputeResource;
use WeathervaneTypes;
use Instance;
use Services::Service;

has 'namespace' => (
	is  => 'ro',
	isa => 'Str',
);

extends 'Service';
override 'initialize' => sub {
	my ( $self ) = @_;
	
	$self->namespace($self->appInstance->namespace);
	
	super();

};

override 'registerPortsWithHost' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For service ", $self->getDockerName(), ", registering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->registerPortNumber($portNumber, $self);
		}				
	}

};

override 'unRegisterPortsWithHost' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For service ", $self->getDockerName(), ", unregistering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->unRegisterPortNumber($portNumber);
		}				
	}

};


override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Service::Service");
	$logger->debug(
		"start serviceType $serviceType, Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	my $impl   = $self->appInstance->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	my $servicesRef = $self->appInstance->getActiveServicesByType($serviceType);

	if ( $serviceType ~~ @$dockerServiceTypesRef ) {
		foreach my $service (@$servicesRef) {
			$logger->debug( "Create " . $service->getDockerName() . "\n" );
			$service->create($logPath);
		}
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "Configure " . $service->getDockerName() . "\n" );
		$service->configure( $logPath, $users, $suffix );
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "Start " . $service->getDockerName() . "\n" );
		$service->startInstance($logPath);
	}
	
	sleep 15;
	
};


override 'stop' => sub {
	my ($self, $serviceType, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Service::Service");
	$logger->debug(
		"stop serviceType $serviceType, Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	my $impl   = $self->appInstance->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	my $servicesRef = $self->appInstance->getActiveServicesByType($serviceType);

	foreach my $service (@$servicesRef) {
		$logger->debug( "Stop " . $service->getDockerName() . "\n" );
		$service->stopInstance( $logPath );
	}

	if ( $serviceType ~~ @$dockerServiceTypesRef ) {
		foreach my $service (@$servicesRef) {
			$logger->debug( "Remove " . $service->getDockerName() . "\n" );
			$service->remove($logPath);
		}
	}

	foreach my $service (@$servicesRef) {
		$logger->debug( "CleanLogFiles " . $service->getDockerName() . "\n" );
		$service->cleanLogFiles();
		$logger->debug( "CleanStatsFiles " . $service->getDockerName() . "\n" );
		$service->cleanStatsFiles();
	}

	sleep 15;
	
};

override 'isReachable ' => sub {
	my ($self, $fileout) = @_;
	return 1;		
};

#-------------------------------
# Two services are equal if they have the same name and
# the same version.
#-------------------------------
sub equals {
	my ( $this, $that ) = @_;

	return ( $this->name() eq $that->name() ) && ( $this->service() eq $that->service() );
}

sub toString {
	my ($self) = @_;

	return "Service " . $self->name() . " with version " . $self->version() . " on host " . $self->host->toString();
}

__PACKAGE__->meta->make_immutable;

1;

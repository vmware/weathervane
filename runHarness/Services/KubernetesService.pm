# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package KubernetesService;

use Moose;
use Tie::IxHash;
use Parameters qw(getParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use POSIX qw(floor ceil);
use namespace::autoclean;
use Log::Log4perl qw(get_logger);
use ComputeResources::ComputeResource;
use WeathervaneTypes;
use Instance;
use Services::Service;

has 'namespace' => (
	is  => 'rw',
	isa => 'Str',
);

extends 'Service';
override 'initialize' => sub {
	my ( $self ) = @_;
	
	$self->namespace($self->appInstance->namespace);
	
	super();

};

# Stop all of the services needed for the Nginx service
override 'stop' => sub {
	my ($self, $serviceType, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::KubernetesService");

	my $impl = $self->getImpl();
	$logger->debug("$impl kubernetes Stop");
			
	my $cluster = $self->host;
	$cluster->kubernetesDeleteAllWithLabel("type=$serviceType", $self->namespace);
};

# Configure and Start all of the services 
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::KubernetesService");

	my $impl = $self->getImpl();	
	$logger->debug("$impl kubernetes Start");
	
	# Create the yaml file for the service
	$self->configure($serviceType, $users);
			
	my $cluster = $self->host;
	my $namespace = $self->namespace;
	$cluster->kubernetesApply("/tmp/${impl}-${namespace}.yaml", $namespace);
};

override 'isRunning' => sub {
	my ($self, $fileout) = @_;
	my $serviceType = $self->getParamValue('serviceType');
	my $namespace = $self->namespace;
	my $numServers = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	return $self->host->kubernetesAreAllPodRunningWithNum("type=$serviceType", $namespace, $numServers );
};


override 'isStopped' => sub {
	my ($self, $fileout) = @_;
	my $serviceType = $self->getParamValue('serviceType');
	my $namespace = $self->namespace;
	return !$self->host->kubernetesDoPodsExist("type=$serviceType", $namespace );
};

sub expandK8sCpu {
	my ($self, $cpuString, $expansionFactor) = @_;
	
	if ($cpuString =~ /^\d*\.?\d+$/) {
		# Already numerical.  Just return expanded
		return $cpuString * $expansionFactor;
	}
	
	$cpuString =~ /(\d+)([^\d]+)/;
	my $magnitude = ceil($1 * $expansionFactor);
	my $unit = $2;	
	return 	"$magnitude$unit";
}

sub expandK8sMem {
	my ($self, $memString, $expansionFactor) = @_;
	$memString =~ /(\d+)([^\d]+)/;
	my $magnitude = $1;
	my $unit = $2;

	# Apply the expansion factor and move down one unit so we 
	# don't have to round too far
	my $unitStep = 1000;
	if ($unit =~ /i/) {
		$unitStep = 1024;
	}
	$magnitude = ceil($magnitude * $expansionFactor * $unitStep);
	$unit =~ s/M/K/i;
	$unit =~ s/G/M/i;
	$unit =~ s/T/G/i;
	$unit =~ s/P/T/i;
	$unit =~ s/E/P/i;
	
	return 	"$magnitude$unit";
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $serviceType = $self->getParamValue('serviceType');
	my $namespace = $self->namespace;
	my $impl = $self->getImpl();
	
	if ( !( -e $destinationPath ) ) {
		`mkdir -p $destinationPath`;
	}

	$self->host->kubernetesGetLogs("type=$serviceType", $impl, $namespace, $destinationPath);

}

sub startStatsCollection {
	my ( $self ) = @_;

}

sub stopStatsCollection {
	my ( $self ) = @_;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

}

sub setPortNumbers {
	my ($self)          = @_;
}


sub setExternalPortNumbers {
	my ($self)          = @_;
}

override 'isReachable' => sub {
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

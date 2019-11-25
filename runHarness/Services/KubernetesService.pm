# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package KubernetesService;

use Moose;
use Tie::IxHash;
use Parameters qw(getParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
use POSIX qw(floor);
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
	my $console_logger   = get_logger("Console");

	my $impl = $self->getImpl();
	
	
	my $time = `date +%H:%M`;
	chomp($time);
	my $logName     = "$logPath/Stop${impl}Kubernetes-$time.log";
	my $appInstance = $self->appInstance;
	
	$logger->debug("$impl kubernetes Stop");
	
	my $log;
	open( $log, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $log $self->meta->name . " In KubernetesService::stop for $impl\n";
		
	my $cluster = $self->host;
	
	$cluster->kubernetesDeleteAllWithLabel("type=$serviceType", $self->namespace);
	close $log;
};

# Configure and Start all of the services needed for the 
# Nginx service
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::KubernetesService");
	my $console_logger   = get_logger("Console");
	my $time = `date +%H:%M`;
	chomp($time);
	my $impl = $self->getImpl();
	my $logName     = "$logPath/Start${impl}Kubernetes-$time.log";
	my $appInstance = $self->appInstance;
	
	$logger->debug("$impl kubernetes Start");
	
	my $log;
	open( $log, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $log $self->meta->name . " In KubernetesService::start for $impl\n";
			
	# Create the yaml file for the service
	$self->configure($log, $serviceType, $users);
			
	my $cluster = $self->host;
	my $namespace = $self->namespace;
	$cluster->kubernetesApply("/tmp/${impl}-${namespace}.yaml", $namespace);
	
	close $log;

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

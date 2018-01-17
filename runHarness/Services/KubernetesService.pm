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

override 'registerPortsWithHost' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	
	

};

override 'unRegisterPortsWithHost' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::Service");	

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
	$cluster->kubernetesDeleteAllWithLabelAndResourceType("type=$serviceType", "configmap", $self->namespace);
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
	return $self->host->kubernetesAreAllPodRunning("type=$serviceType", $namespace );
};

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

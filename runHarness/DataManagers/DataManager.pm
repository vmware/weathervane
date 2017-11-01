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
package DataManager;

use Moose;
use MooseX::Storage;
use Services::Service;
use RunProcedures::RunProcedure;
use Factories::RunProcedureFactory;
use WorkloadDrivers::WorkloadDriver;
use Factories::WorkloadDriverFactory;
use Hosts::Host;
use Instance;
use Log::Log4perl qw(get_logger);

use Parameters qw(getParamValue);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;
extends 'Instance';

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

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
	isa => 'Host',
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
	
	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	
	# if the dbScriptDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $dbScriptDir    = $self->getParamValue('dbScriptDir');
	if ( !( $dbScriptDir =~ /^\// ) ) {
		$dbScriptDir = $weathervaneHome . "/" . $dbScriptDir;
	}
	$self->setParamValue('dbScriptDir', $dbScriptDir);

	# make sure the directories exist
	if ( !( -e $dbScriptDir ) ) {
		die "Error: The directory for the database creation scripts, $dbScriptDir, does not exist.";
	}

	# if the dbLoaderDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $dbLoaderDir    = $self->getParamValue('dbLoaderDir' );
	if ( !( $dbLoaderDir =~ /^\// ) ) {
		$dbLoaderDir = $weathervaneHome . "/" . $dbLoaderDir;
	}
	$self->setParamValue('dbLoaderDir', $dbLoaderDir);

	my $tmpDir    =  $self->getParamValue('tmpDir' ); 
	if ( !( $tmpDir =~ /^\// ) ) {
		$tmpDir = $weathervaneHome . "/" . $tmpDir;
	}
	$self->setParamValue('tmpDir', $tmpDir);

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

sub registerPortsWithHost {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::DataManagers::DataManager");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For dataManager, registering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->registerPortNumber($portNumber, $self);
		}				
	}

}

sub unRegisterPortsWithHost {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::DataManagers::DataManager");	
	
	foreach my $key (keys %{$self->portMap}) {
		my $portNumber = $self->portMap->{$key};
		$logger->debug("For dataManager, unregistering port $portNumber for key $key");
		if ($portNumber) {
 			$self->host->unRegisterPortNumber($portNumber);
		}				
	}

}

sub getWorkloadNum {
	my ($self) = @_;
	return $self->getParamValue('workloadNum');
}

sub getAppInstanceNum {
	my ($self) = @_;
	return $self->getParamValue('appInstanceNum');
}

sub getDockerName {
	my ($self) = @_;
	
	return $self->getParamValue("dockerName");
}

sub loadData {
	die "Can only loadData for a concrete sub-class of DataManager";
}

sub prepareData {
	die "Can only prepareData for a concrete sub-class of DataManager";
}

sub isDataLoaded {
	die "Can only check isDataLoaded for a concrete sub-class of DataManager";
}

sub toString {
	  my ($self) = @_;

	  return "DataManager " . $self->name();
}

__PACKAGE__->meta->make_immutable;

1;

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package HostFactory;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use Moose::Util qw( apply_all_roles );
use ComputeResources::KubernetesCluster;
use ComputeResources::DockerHost;
use ComputeResources::ESXiHost;
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getDockerHost {
	my ( $self, $paramsHashRef ) = @_;
	my $logger = get_logger("Weathervane::Factories::HostFactory");
	my $hostname = $paramsHashRef->{'name'};
	
	$logger->debug("Creating a DockerHost with hostname $hostname");
	my $host = DockerHost->new('paramHashRef' => $paramsHashRef);
	return $host;
}

sub getKubernetesCluster {
	my ( $self, $paramsHashRef ) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Factories::HostFactory");
	my $cluster;	
	my $clusterName = $paramsHashRef->{'name'};
	
	$logger->debug("Creating a Kubernetes cluster with name $clusterName");
	$cluster = KubernetesCluster->new('paramHashRef' => $paramsHashRef);
	return $cluster;
}

sub getVIHost{
	my ( $self, $paramHashRef) = @_;
	my $host;
	my $viType = $paramHashRef->{'virtualInfrastructureType'};

	if ( $viType eq "vsphere" ) {
		$host = ESXiHost->new(
			'paramHashRef' => $paramHashRef,

		);
	}
	else {
		die "No matching virtualInfrastructure type available to hostFactory";
	}

	$host->initialize();

	return $host;
}
__PACKAGE__->meta->make_immutable;

1;

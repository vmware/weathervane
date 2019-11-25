# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package ServiceFactory;

use Moose;
use MooseX::Storage;
use Services::NginxKubernetesService;
use Services::NginxDockerService;
use Services::TomcatKubernetesService;
use Services::TomcatDockerService;
use Services::AuctionBidKubernetesService;
use Services::AuctionBidDockerService;
use Services::PostgresqlKubernetesService;
use Services::PostgresqlDockerService;
use Services::CassandraKubernetesService;
use Services::CassandraDockerService;
use Services::ZookeeperKubernetesService;
use Services::ZookeeperDockerService;
use Services::RabbitmqKubernetesService;
use Services::RabbitmqDockerService;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getServiceByNameAndVersion {
	my ( $self, $serviceName, $serviceVersion, $host, $paramsHashRef ) = @_;
	my $service;

	my $serviceTypeName = "$serviceName.$serviceVersion";

	if ( $serviceTypeName eq "tomcat.8" ) {
		$service = TomcatService->new();
	}
	else {
		die "No matching service name $serviceName and version available to ServiceFactory";
	}

	return $service;
}

sub getServiceByType {
	my ( $self, $paramHashRef, $serviceType, $numSvcInstances, $appInstance, $host ) = @_;
	my $console_logger = get_logger("Console");
	
	my $hostType = ref $host;
	my $serviceName = $paramHashRef->{$serviceType . "Impl"};	

	my $service;
	if ( $serviceName eq "tomcat" ) {
		if ($hostType eq "KubernetesCluster") {
			$service = TomcatKubernetesService->new(
			paramHashRef => $paramHashRef,
			appInstance => $appInstance,
			);
		} else {
			$service = TomcatDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "auctionbidservice" ) {
		if ($hostType eq "KubernetesCluster") {
				$service = AuctionBidKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		} else {
				$service = AuctionBidDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		}
	}
	elsif ( $serviceName eq "zookeeper" ) {
		if ($hostType eq "KubernetesCluster") {
				$service = ZookeeperKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		} else {
			$service = ZookeeperDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "nginx" ) {
		if ($hostType eq "KubernetesCluster") {
				$service = NginxKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		} else {
			$service = NginxDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "postgresql" ) {
		if ($hostType eq "KubernetesCluster") {
				$service = PostgresqlKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		} else {
			$service = PostgresqlDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "cassandra" ) {
		if ($hostType eq "KubernetesCluster") {
			$service = CassandraKubernetesService->new(
			paramHashRef => $paramHashRef,
			appInstance => $appInstance,
			);
		} else {
			$service = CassandraDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "rabbitmq" ) {
		if ($hostType eq "KubernetesCluster") {
				$service = RabbitmqKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
		} else {
			$service = RabbitmqDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	else {
		die "No matching service name $serviceName available to ServiceFactory";
	}

	return $service;
}

__PACKAGE__->meta->make_immutable;

1;

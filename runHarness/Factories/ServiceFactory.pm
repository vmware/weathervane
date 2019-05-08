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
package ServiceFactory;

use Moose;
use MooseX::Storage;
use Services::NginxKubernetesService;
use Services::NginxDockerService;
use Services::TomcatKubernetesService;
use Services::TomcatDockerService;
use Services::AuctionBidKubernetesService;
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
			$console_logger->error("There is no Docker implementation for the AuctionBidServer, only Kubernetes");
			exit(-1);
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

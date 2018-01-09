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
use Services::KeepalivedService;
use Services::HaproxyService;
use Services::HaproxyDockerService;
use Services::HttpdService;
use Services::NginxService;
use Services::NginxKubernetesService;
use Services::NginxDockerService;
use Services::TomcatService;
use Services::TomcatKubernetesService;
use Services::TomcatDockerService;
use Services::MysqlService;
use Services::PostgresqlService;
use Services::PostgresqlKubernetesService;
use Services::PostgresqlDockerService;
use Services::MongodbService;
use Services::MongodbKubernetesService;
use Services::MongodbDockerService;
use Services::ZookeeperService;
use Services::ZookeeperKubernetesService;
use Services::ZookeeperDockerService;
use Services::RabbitmqService;
use Services::RabbitmqKubernetesService;
use Services::RabbitmqDockerService;
use Services::NfsService;
use Services::ConfigurationManager;
use Services::ConfigurationKubernetesManager;
use Services::ConfigurationManagerDocker;
use Services::ScheduledElasticityService;
use Services::SimpleElasticityService;

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

	$service->initialize($paramsHashRef);

	return $service;
}

sub getServiceByType {
	my ( $self, $paramHashRef, $serviceType, $numScvInstances, $appInstance ) = @_;
	my $service;

	my $serviceName = $paramHashRef->{$serviceType . "Impl"};
	
	my $docker = $paramHashRef->{"useDocker"};

	if ( $serviceName eq "tomcat" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = TomcatKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = TomcatDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
		else {
			$service = TomcatService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "keepalived" ) {
		$service = KeepalivedService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
		);
	}
	elsif ( $serviceName eq "haproxy" ) {
		if ($docker) {
			$service = HaproxyDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		} else {
			$service = HaproxyService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "httpd" ) {
			$service = HttpdService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
	}
	elsif ( $serviceName eq "zookeeper" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = ZookeeperKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = ZookeeperDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
		else {
			$service = ZookeeperService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "nginx" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = NginxKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = NginxDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
		else {
			$service = NginxService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "mysql" ) {
		$service = MysqlService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
		);
	}
	elsif ( $serviceName eq "postgresql" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = PostgresqlKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = PostgresqlDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		} else {	
			$service = PostgresqlService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "mongodb" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = MongodbKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = MongodbDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		} else {			
			$service = MongodbService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "rabbitmq" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = RabbitmqKubernetesService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = RabbitmqDockerService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		} else {
			$service = RabbitmqService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
			);
		}
	}
	elsif ( $serviceName eq "nfs" ) {
		$service = NfsService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
		);
	}
	elsif ( $serviceName eq "webConfig" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$service = ConfigurationManagerKubernetes->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
				);
			}		
		} elsif ($docker) {
			$service = ConfigurationManagerDocker->new(
					paramHashRef => $paramHashRef,
					appInstance => $appInstance,
			);
		} else {
			$service = ConfigurationManager->new(
						paramHashRef => $paramHashRef,
					appInstance => $appInstance,
			);	
		}
	}
	elsif ( $serviceName eq "simpleES" ) {
		$service = SimpleElasticityService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
		);
	}
	elsif ( $serviceName eq "scheduledES" ) {
		$service = ScheduledElasticityService->new(
				paramHashRef => $paramHashRef,
				appInstance => $appInstance,
		);
	}
	else {
		die "No matching service name $serviceName available to ServiceFactory";
	}

	$service->initialize($numScvInstances);

	return $service;
}

__PACKAGE__->meta->make_immutable;

1;

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
package NginxKubernetesService;

use Moose;
use MooseX::Storage;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

sub configure {
	my ( $self, $dblog, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxService");
	$logger->debug("Configure Nginx kubernetes");
	print $dblog "Configure Nginx Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getTotalNumOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}

	my $dataVolumeSize = $self->getParamValue("nginxCacheVolumeSize");
	# Convert the cache size notation from Kubernetes to Nginx. Also need to 
	# make the cache size 90% of the volume size to ensure that it doesn't 
	# fill up. To do this we step down to the next smaller unit size
	$dataVolumeSize =~ /(\d+)([^\d]+)/;
	my $cacheMagnitude = ceil(1024 * $1 * 0.90);
	my $cacheUnit = $2;	
	$cacheUnit =~ s/Gi/m/i;
	$cacheUnit =~ s/Mi/k/i;
	$cacheUnit =~ s/Ki//i;
	my $cacheMaxSize = "$cacheMagnitude$cacheUnit";

	my $numAuctionBidServers = $self->appInstance->getTotalNumOfServiceType('auctionBidServer');
	# The default setting for net.ipv4.ip_local_port_range on most Linux distros gives 28231 port numbers.
	# As a result, we need to limit the number of connections to any back-end server to less than this 
	# number to avoid running out of ports.  
	# If there are no bid servers in the config, then the servers will appear twice, so we
	# need to divide the number of connections in half
	my $perServerConnections = 28000;
	if (!$numAuctionBidServers) {
		$perServerConnections = 14000;
	}

	my $numWebServers = $self->appInstance->getTotalNumOfServiceType('webServer');
	open( FILEIN,  "$configDir/kubernetes/nginx.yaml" ) or die "$configDir/kubernetes/nginx.yaml: $!\n";
	open( FILEOUT, ">/tmp/nginx-$namespace.yaml" )             or die "Can't open file /tmp/nginx-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /WORKERCONNECTIONS:/ ) {
			print FILEOUT "  WORKERCONNECTIONS: \"$workerConnections\"\n";
		}
		elsif ( $inline =~ /PERSERVERCONNECTIONS:/ ) {
			print FILEOUT "  PERSERVERCONNECTIONS: \"$perServerConnections\"\n";
		}
		elsif ( $inline =~ /CACHEMAXSIZE:/ ) {
			print FILEOUT "  CACHEMAXSIZE: \"$cacheMaxSize\"\n";
		}
		elsif ( $inline =~ /KEEPALIVETIMEOUT:/ ) {
			print FILEOUT "  KEEPALIVETIMEOUT: \"" . $self->getParamValue('nginxKeepaliveTimeout') . "\"\n";
		}
		elsif ( $inline =~ /MAXKEEPALIVEREQUESTS:/ ) {
			print FILEOUT "  MAXKEEPALIVEREQUESTS: \"" . $self->getParamValue('nginxMaxKeepaliveRequests') . "\"\n";
		}
		elsif ( $inline =~ /IMAGESTORETYPE:/ ) {
			print FILEOUT "  IMAGESTORETYPE: \"" . $self->getParamValue('imageStoreType') . "\"\n";
		}
		elsif ( $inline =~ /BIDSERVERS:/ ) {
			if ($numAuctionBidServers > 0) {
				print FILEOUT "  BIDSERVERS: \"auctionbidservice:8080\"\n";				
			} else {
				print FILEOUT "  BIDSERVERS: \"tomcat:8080\"\n";								
			}
		}
		elsif ( $inline =~ /(\s+)type:\s+LoadBalancer/ ) {
			my $useLoadbalancer = $self->host->getParamValue('useLoadBalancer');
			if (!$useLoadbalancer) {
				print FILEOUT "${1}type: NodePort\n";				
			} else {
				print FILEOUT $inline;		
			}
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			print FILEOUT $inline;
			print FILEOUT "$indent  requests:\n";
			print FILEOUT "$indent    cpu: " . $self->getParamValue('webServerCpus') . "\n";
			print FILEOUT "$indent    memory: " . $self->getParamValue('webServerMem') . "\n";
			if ($self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  limits:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('webServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('webServerMem') . "\n";						
			}
			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /livenessProbe/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numWebServers\n";
		}
		elsif ( $inline =~ /(\s+)volumeClaimTemplates:/ ) {
			print FILEOUT $inline;
			while ( my $inline = <FILEIN> ) {
				if ( $inline =~ /(\s+)name:\snginx\-cache/ ) {
					print FILEOUT $inline;
					while ( my $inline = <FILEIN> ) {
						if ( $inline =~ /(\s+)storageClassName:/ ) {
							my $storageClass = $self->getParamValue("nginxCacheStorageClass");
							print FILEOUT "${1}storageClassName: $storageClass\n";
							last;
						} elsif ($inline =~ /^(\s+)storage:/ ) {
							print FILEOUT "${1}storage: $dataVolumeSize\n";
						} else {
							print FILEOUT $inline;
						}	
					}
				} elsif ( $inline =~ /\-\-\-/ ) {
					print FILEOUT $inline;
					last;
				} else {
					print FILEOUT $inline;					
				}
			}
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	
	close FILEIN;
	close FILEOUT;
	
	# Delete the pvc for nginxCacheVolume
	# if the size doesn't match the requested size.  
	# This is to make sure that we are running the
	# correct configuration size
	my $cluster = $self->host;
	my $curPvcSize = $cluster->kubernetesGetSizeForPVC("nginx-cache-nginx-0", $self->namespace);
	if (($curPvcSize ne "") && ($curPvcSize ne $dataVolumeSize)) {
		$cluster->kubernetesDeleteAllWithLabelAndResourceType("impl=nginx,type=webServer", "pvc", $self->namespace);
	}
}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	my $numServers = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	if ($cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "curl -s -w \"%{http_code}\n\" -o /dev/null http://127.0.0.1:80", $self->namespace, '200', $numServers)) { 
		return 1;
	}
	return 0;
};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::NginxKubernetesService");
	$logger->debug("stopStatsCollection");
};

override 'startStatsCollection' => sub {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::NginxKubernetesService");
	$logger->debug("startStatsCollection hostname = $hostname");

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxKubernetesService");
	$logger->debug("getStatsFiles");

};


sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::NginxKubernetesService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/nginx-$namespace.yaml $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"nginxKeepaliveTimeout"}     = $self->getParamValue('nginxKeepaliveTimeout');
	$csv{"nginxMaxKeepaliveRequests"} = $self->getParamValue('nginxMaxKeepaliveRequests');
	$csv{"nginxWorkerConnections"}    = $self->getParamValue('nginxWorkerConnections');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

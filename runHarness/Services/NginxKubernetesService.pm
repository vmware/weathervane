# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
	my ( $self, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxService");
	$logger->debug("Configure Nginx kubernetes");

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getTotalNumOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}

	my $configurationSize = $self->getParamValue("configurationSize");
	my $cacheMagnitudeMultiplier = 0.90;
	if ($configurationSize eq "xsmall") {
		$logger->debug("For xsmall config, setting cacheMagnitudeMultiplier to 0.85");
		$cacheMagnitudeMultiplier = 0.85;
	}
	my $dataVolumeSize = $self->getParamValue("nginxCacheVolumeSize");
	# Convert the cache size notation from Kubernetes to Nginx. Also need to 
	# make the cache size 90% of the volume size to ensure that it doesn't 
	# fill up. To do this we step down to the next smaller unit size
	$dataVolumeSize =~ /(\d+)([^\d]+)/;
	my $cacheMagnitude = ceil(1024 * $1 * $cacheMagnitudeMultiplier);
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

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

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
            my $appIngressMethod = $self->getParamValue("appIngressMethod");
			if ($appIngressMethod eq "clusterip") {
                print FILEOUT "${1}type: ClusterIP\n";               			  	
			} elsif ($appIngressMethod eq "loadbalancer") {
                print FILEOUT $inline;      
	   	    } elsif (($appIngressMethod eq "nodeport") || ($appIngressMethod eq "nodeport-internal")) {
                print FILEOUT "${1}type: NodePort\n";               
			}
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT $inline;
			}
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('webServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('webServerMem') . "\n";
			}
			if ($self->getParamValue('useKubernetesLimits')) {
				my $limitsExpansion = 1 + (0.01 *  $self->getParamValue('limitsExpansionPct'));
				my $cpuLimit = $self->expandK8sCpu($self->getParamValue('webServerCpus'), $limitsExpansion);
				my $memLimit = $self->expandK8sMem($self->getParamValue('webServerMem'), $limitsExpansion);
				print FILEOUT "$indent  limits:\n";
				print FILEOUT "$indent    cpu: " . $cpuLimit . "\n";
				print FILEOUT "$indent    memory: " . $memLimit . "\n";						
			}

			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /readinessProbe/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+)initialDelaySeconds:/ ) {
	        # Randomize the initialDelaySeconds on the readiness probes
			my $indent = $1;
			my $delay = int(rand(60)) + 1;
			print FILEOUT "${indent}initialDelaySeconds: $delay\n";
		}
		elsif ( $inline =~ /(\s+)ports:/ ) {
			# Deal with both the container and service ports here
			print FILEOUT $inline;
			if ($self->getParamValue('ssl')) {
				# Skip the port 80 definitions by dropping all lines
				# until we see 443
				$inline = <FILEIN>;			
				while (!($inline =~ /443/)) {
					$inline = <FILEIN>;							
				}
				print FILEOUT $inline;
			} else {
				# Leave the port 80 definitions and drop the
				# port 443 definitions
				$inline = <FILEIN>;
				print FILEOUT $inline;
				# Decide whether we are parsing the container or 
				# service port
				if ($inline =~ /container/) {
					# Container ports.  Leave two more lines then drop three
					$inline = <FILEIN>;
					print FILEOUT $inline;
					$inline = <FILEIN>;
					print FILEOUT $inline;
					$inline = <FILEIN>;
					$inline = <FILEIN>;
					$inline = <FILEIN>;
				} else {
					# Service ports.  Leave one more lines then drop two
					$inline = <FILEIN>;
					print FILEOUT $inline;
					$inline = <FILEIN>;
					$inline = <FILEIN>;
				}
			}
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
		elsif ( $inline =~ /^(\s+)affinity\:/ )  {
			print FILEOUT $inline;
			# Add any pod affinity rules controlled by parameters
			print FILEOUT $serviceParamsHashRef->{"affinityRuleText"};
			do {
				$inline = <FILEIN>;
				if ( $inline =~ /^(\s+)requiredDuringScheduling/ ) {
					my $indent = $1;
					print FILEOUT $inline;
					do {
						$inline = <FILEIN>;
						print FILEOUT $inline;			
					} while(!($inline =~ /matchExpressions/));
					if ($self->getParamValue('instanceNodeLabels')) {
						my $workloadNum    = $self->appInstance->workload->instanceNum;
						my $appInstanceNum = $self->appInstance->instanceNum;
    	        	    print FILEOUT "${indent}    - key: wvauctionw${workloadNum}i${appInstanceNum}\n";
        	        	print FILEOUT "${indent}      operator: Exists\n";
					} 
					if ($self->getParamValue('serviceTypeNodeLabels')) {
    	        	    print FILEOUT "${indent}    - key: wv${serviceType}\n";
        	        	print FILEOUT "${indent}      operator: Exists\n";
					} 
				} else {
					print FILEOUT $inline;					
				}
			} while(!($inline =~ /containers/));
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

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package TomcatKubernetesService;

use Moose;
use MooseX::Storage;

use POSIX;
use Services::KubernetesService;
use Parameters qw(getParamValue);
use StatsParsers::ParseGC qw( parseGCLog );
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub configure {
	my ( $self, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatKubernetesService");
	$logger->debug("Configure Tomcat kubernetes");

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $numCpus = ceil($self->getParamValue( $serviceType . "Cpus" ));
	my $threads            = $self->getParamValue('appServerThreads') * $numCpus;
	my $connections        = $self->getParamValue('appServerJdbcConnections') * $numCpus;
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $maxIdle = ceil($self->getParamValue('appServerJdbcConnections') / 2);
	my $nodeNum = $self->instanceNum;
	my $maxConnections =
	  ceil( $self->getParamValue('frontendConnectionMultiplier') *
		  $users /
		  ( $self->appInstance->getTotalNumOfServiceType('appServer') * 1.0 ) );
	if ( $maxConnections < 100 ) {
		$maxConnections = 100;
	}


	my $warmerJvmOpts = "-Xmx250m -Xms250m -XX:+AlwaysPreTouch";
	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$warmerJvmOpts .= " -Dspring.profiles.active=$springProfilesActive ";

	my $completeJVMOpts .= $self->getParamValue('appServerJvmOpts');
	$completeJVMOpts .= " " . $serviceParamsHashRef->{"jvmOpts"};

	if ( $self->getParamValue('logLevel') >= 3 ) {
		$completeJVMOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:$tomcatCatalinaBase/logs/gc.log ";
	}
	if ( $self->getParamValue('enableJmx') ) {
		$completeJVMOpts .= " -Dcom.sun.management.jmxremote.rmi.port=9090 -Dcom.sun.management.jmxremote=true "
							. "-Dcom.sun.management.jmxremote.port=9090 -Dcom.sun.management.jmxremote.ssl=false "
							. "-Dcom.sun.management.jmxremote.authenticate=false -Dcom.sun.management.jmxremote.local.only=false "
							. "-Djava.rmi.server.hostname=127.0.0.1 ";
	}
	$completeJVMOpts .= " -DnodeNumber=$nodeNum ";
	
	my $numAppServers = $self->appInstance->getTotalNumOfServiceType('appServer');

	open( FILEIN,  "$configDir/kubernetes/tomcat.yaml" ) or die "$configDir/kubernetes/tomcat.yaml: $!\n";
	open( FILEOUT, ">/tmp/tomcat-$namespace.yaml" )             or die "Can't open file /tmp/tomcat-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /TOMCAT_JVMOPTS:/ ) {
			print FILEOUT "  TOMCAT_JVMOPTS: \"$completeJVMOpts\"\n";
		}
		elsif ( $inline =~ /WARMER_JVMOPTS:/ ) {
			print FILEOUT "  WARMER_JVMOPTS: \"$warmerJvmOpts\"\n";
		}
		elsif ( $inline =~ /WARMER_THREADS_PER_SERVER:/ ) {
			print FILEOUT "  WARMER_THREADS_PER_SERVER: \"" . $self->getParamValue('appServerWarmerThreadsPerServer') . "\"\n";
		}
		elsif ( $inline =~ /WARMER_ITERATIONS/ ) {
			print FILEOUT "  WARMER_ITERATIONS: \"" . $self->getParamValue('appServerWarmerIterations') . "\"\n";
		}
		elsif ( $inline =~ /TOMCAT_THREADS:/ ) {
			print FILEOUT "  TOMCAT_THREADS: \"$threads\"\n";
		}
		elsif ( $inline =~ /TOMCAT_JDBC_CONNECTIONS:/ ) {
			print FILEOUT "  TOMCAT_JDBC_CONNECTIONS: \"$connections\"\n";
		}
		elsif ( $inline =~ /TOMCAT_JDBC_MAXIDLE:/ ) {
			print FILEOUT "  TOMCAT_JDBC_MAXIDLE: \"$maxIdle\"\n";
		}
		elsif ( $inline =~ /TOMCAT_CONNECTIONS:/ ) {
			print FILEOUT "  TOMCAT_CONNECTIONS: \"$maxConnections\"\n";
		}
		elsif ( $inline =~ /weathervane\-tomcat/ ) {
			do {
				if ( $inline =~ /(\s+)resources/ )  {
					my $indent = $1;
					if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
						print FILEOUT $inline;
					}
					if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
						print FILEOUT "$indent  requests:\n";
						print FILEOUT "$indent    cpu: " . $self->getParamValue('appServerCpus') . "\n";
						print FILEOUT "$indent    memory: " . $self->getParamValue('appServerMem') . "\n";
					}
					if ($self->getParamValue('useKubernetesLimits') ||
						($self->getParamValue('useKubernetesRequests') && $self->getParamValue('useAppServerLimits'))) {
						my $cpuLimit = $self->getParamValue('appServerCpus');
						my $memLimit = $self->getParamValue('appServerMem');
						print FILEOUT "$indent  limits:\n";
						print FILEOUT "$indent    cpu: " . $cpuLimit . "\n";
						print FILEOUT "$indent    memory: " . $memLimit . "\n";						
					}

					do {
						$inline = <FILEIN>;
					} while(!($inline =~ /readinessProbe/));
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
	  		    elsif ( $inline =~ /(\s+)initialDelaySeconds:/ ) {
			        # Randomize the initialDelaySeconds on the readiness probes
					my $indent = $1;
					my $delay = int(rand(60)) + 1;
					print FILEOUT "${indent}initialDelaySeconds: $delay\n";
				} else {
					print FILEOUT $inline;						
				}
				$inline = <FILEIN>;
			} while (!($inline =~ /timeoutSeconds/)); 
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /weathervane\-auctionappserverwarmer/ ) {
			if (!($self->getParamValue('prewarmAppServers'))) {
				#  Not using warmer so remove it from yaml
				do {
					$inline = <FILEIN>;
				} while(!($inline =~ /\-\-\-/));
				print FILEOUT $inline;							
			} else {
				do {
					if ( $inline =~ /(\s+)resources/ )  {
						my $indent = $1;
						if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
							print FILEOUT $inline;
						}
						if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
							print FILEOUT "$indent  requests:\n";
							print FILEOUT "$indent    cpu: " . $self->getParamValue('appWarmerCpus') . "\n";
							print FILEOUT "$indent    memory: " . $self->getParamValue('appWarmerMem') . "\n";
						}
						if ($self->getParamValue('useKubernetesLimits') ||
							($self->getParamValue('useKubernetesRequests') && $self->getParamValue('useAppServerLimits'))) {
							my $cpuLimit = $self->getParamValue('appWarmerCpus');
							my $memLimit = $self->getParamValue('appWarmerMem');
							print FILEOUT "$indent  limits:\n";
							print FILEOUT "$indent    cpu: " . $cpuLimit . "\n";
							print FILEOUT "$indent    memory: " . $memLimit . "\n";						
						}

						do {
							$inline = <FILEIN>;
						} while(!($inline =~ /\-\-\-/));
						print FILEOUT $inline;			
					}
					elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
						print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
					}
					elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
						my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
						my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
						print FILEOUT "${1}$dockerNamespace/${3}$version\n";
					} else {
						print FILEOUT $inline;						
					}
					$inline = <FILEIN>;
				} while (!($inline =~ /apiVersion/)); 
				print FILEOUT $inline;
			}			
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numAppServers\n";
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
    	        	    print FILEOUT "${indent}    - key: wvtype\n";
        	        	print FILEOUT "${indent}      operator: In\n";
        	        	print FILEOUT "${indent}      values:\n";
        	        	print FILEOUT "${indent}      - $serviceType\n";
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

}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	my $numServers = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	if ($cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "curl -s http://localhost:8080/auction/healthCheck", $self->namespace, 'alive', $numServers ) 
	    && (!$self->getParamValue('prewarmAppServers') ||
	         $cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "curl -s http://localhost:8888/warmer/ready", $self->namespace, 'ready', $numServers ))) { 
		return 1;
	}
	return 0;
};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatKubernetesService");
	$logger->debug("stopStatsCollection");
};

override 'startStatsCollection' => sub {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::TomcatKubernetesService");
	$logger->debug("startStatsCollection hostname = $hostname");

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatKubernetesService");
	$logger->debug("getStatsFiles");

};

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::TomcatKubernetesService");
	$logger->debug("cleanLogFiles");
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/tomcat-$namespace.yaml $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"tomcatThreads"}     = $self->getParamValue('appServerThreads');
	$csv{"tomcatConnections"} = $self->getParamValue('appServerJdbcConnections');
	$csv{"tomcatJvmOpts"}     = $self->getParamValue('appServerJvmOpts');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

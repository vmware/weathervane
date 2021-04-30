# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RabbitmqKubernetesService;

use Moose;
use MooseX::Storage;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

# Names of stats collected for RabbitMQ and the text to match in the list queues output
my @rabbitmqStatNames = (
	"memory",       "messages",       "messages_ready", "messages_unacked", "ack_rate", "deliver_rate",
	"publish_rate", "redeliver_rate", "unacked_rate"
);
my @rabbitmqStatText = (
	"memory",                             "messages",
	"messages_ready",                     "messages_unacknowledged",
	"message_stats.ack_details.rate",     "message_stats.deliver_get_details.rate",
	"message_stats.publish_details.rate", "message_stats.redeliver_details.rate",
	"messages_unacknowledged_details.rate"
);

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

sub configure {
	my ( $self, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("Configure Rabbitmq kubernetes");

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $memString = $self->getParamValue('msgServerMem');
	$logger->debug("msgServerMem is set to $memString.");
	$memString =~ /(\d+)\s*(\w+)/;
	my $totalMemory = $1;
	my $totalMemoryUnit = $2;
	if (lc($totalMemoryUnit) eq "gi") {
		$totalMemoryUnit = "GB";
	} elsif (lc($totalMemoryUnit) eq "mi") {
		$totalMemoryUnit = "MB";
	} elsif (lc($totalMemoryUnit) eq "ki") {
		$totalMemoryUnit = "kB";
	}

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $numReplicas = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));

	open( FILEIN,  "$configDir/kubernetes/rabbitmq.yaml" ) or die "$configDir/kubernetes/rabbitmq.yaml: $!\n";
	open( FILEOUT, ">/tmp/rabbitmq-$namespace.yaml" )             or die "Can't open file /tmp/rabbitmq-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /RABBITMQ_MEMORY:/ ) {
			print FILEOUT "  RABBITMQ_MEMORY: \"$totalMemory$totalMemoryUnit\"\n";
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT $inline;
			}
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('msgServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('msgServerMem') . "\n";
			}
			if ($self->getParamValue('useKubernetesLimits')) {
				my $limitsExpansion = 1 + (0.01 *  $self->getParamValue('limitsExpansionPct'));
				my $cpuLimit = $self->expandK8sCpu($self->getParamValue('msgServerCpus'), $limitsExpansion);
				my $memLimit = $self->expandK8sMem($self->getParamValue('msgServerMem'), $limitsExpansion);
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
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numReplicas\n";
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
	
		

}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	my $cluster = $self->host;
	my $numServers = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	if ($cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "rabbitmqctl list_vhosts", $self->namespace, 'auction', $numServers)) { 
		return 1;
	}
	return 0;
};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("stopStatsCollection");
};

override 'startStatsCollection' => sub {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("startStatsCollection hostname = $hostname");

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("getStatsFiles");

};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/rabbitmq-$namespace.yaml $destinationPath/. 2>&1`;
	
}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

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

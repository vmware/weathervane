# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package ZookeeperKubernetesService;

use Moose;
use MooseX::Storage;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);
use WeathervaneTypes;
use JSON;

use LWP;
use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

sub configure {
	my ( $self, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperKubernetesService");
	$logger->debug("Configure Zookeeper kubernetes");

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $numReplicas = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));
	my $servers = "";
	for (my $i = 0; $i < $numReplicas; $i++) {
		my $serverNum = $i + 1;
		$servers .= "server.${serverNum}=zookeeper-${i}.zookeeper:2888:3888";
		if ($serverNum < $numReplicas) {
			$servers .= ",";
		}
	}

	open( FILEIN,  "$configDir/kubernetes/zookeeper.yaml" ) or die "$configDir/kubernetes/zookeeper.yaml: $!\n";
	open( FILEOUT, ">/tmp/zookeeper-$namespace.yaml" )             or die "Can't open file /tmp/zookeeper-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT $inline;
			}
			if ($self->getParamValue('useKubernetesRequests') || $self->getParamValue('useKubernetesLimits')) {
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('coordinationServerCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('coordinationServerMem') . "\n";
			}
			if ($self->getParamValue('useKubernetesLimits')) {
				my $limitsExpansion = 1 + (0.01 *  $self->getParamValue('limitsExpansionPct'));
				my $cpuLimit = $self->expandK8sCpu($self->getParamValue('coordinationServerCpus'), $limitsExpansion);
				my $memLimit = $self->expandK8sMem($self->getParamValue('coordinationServerMem'), $limitsExpansion);
				print FILEOUT "$indent  limits:\n";
				print FILEOUT "$indent    cpu: " . $cpuLimit . "\n";
				print FILEOUT "$indent    memory: " . $memLimit . "\n";						
			}

			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /\-\-\-/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /^(\s+)requiredDuringScheduling/ ) {
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
		}
		elsif ( $inline =~ /ZK_SERVERS:/ ) {
			print FILEOUT "  ZK_SERVERS: \"$servers\"\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numReplicas\n";
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
	if ($cluster->kubernetesAreAllPodUpWithNum ($self->getImpl(), "/bin/sh -c '[ \"imok\" = \"\$(echo ruok | nc -w 1 127.0.0.1 2181)\" ]'", $self->namespace, '', $numServers)) { 
		return 1;
	}
	return 0;
};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperKubernetesService");
	$logger->debug("stopStatsCollection");
};

override 'startStatsCollection' => sub {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->name;
	my $logger = get_logger("Weathervane::Services::ZookeeperKubernetesService");
	$logger->debug("startStatsCollection hostname = $hostname");

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperKubernetesService");
	$logger->debug("getStatsFiles");

};
sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
}

sub cleanLogFiles {
	my ($self)           = @_;
	
}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/zookeeper-$namespace.yaml $destinationPath/. 2>&1`;
	
}

sub getConfigSummary {
	my ($self) = @_;
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

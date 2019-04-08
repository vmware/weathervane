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

has '+name' => ( default => 'RabbitMQ', );

has '+version' => ( default => 'xx', );

has '+description' => ( default => '', );

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
	my ( $self, $dblog, $serviceType, $users ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqKubernetesService");
	$logger->debug("Configure Rabbitmq kubernetes");
	print $dblog "Configure Rabbitmq Kubernetes\n";

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

	my $numReplicas = $self->appInstance->getTotalNumOfServiceType($self->getParamValue('serviceType'));

	open( FILEIN,  "$configDir/kubernetes/rabbitmq.yaml" ) or die "$configDir/kubernetes/rabbitmq.yaml: $!\n";
	open( FILEOUT, ">/tmp/rabbitmq-$namespace.yaml" )             or die "Can't open file /tmp/rabbitmq-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			print FILEOUT "${1}$version\n";
		}
		elsif ( $inline =~ /RABBITMQ_MEMORY:/ ) {
			print FILEOUT "  RABBITMQ_MEMORY: \"$totalMemory$totalMemoryUnit\"\n";
		}
		elsif ( $inline =~ /^(\s+)cpu:/ ) {
			print FILEOUT "${1}cpu: " . $self->getParamValue('msgServerCpus') . "\n";
		}
		elsif ( $inline =~ /^(\s+)memory:/ ) {
			print FILEOUT "${1}memory: " . $self->getParamValue('msgServerMem') . "\n";
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
	my $hostname         = $self->host->hostName;
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

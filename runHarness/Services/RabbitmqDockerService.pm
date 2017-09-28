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
package RabbitmqDockerService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

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

override 'create' => sub {
	my ($self, $logPath)            = @_;
	
	if (!$self->getParamValue('useDocker')) {
		return;
	}
	
	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	# The default create doesn't map any volumes
	my %volumeMap;
	
	# The default create doesn't create any environment variables
	my %envVarMap;
	$envVarMap{"RABBITMQ_NODE_PORT"} = $self->internalPortMap->{$self->getImpl()};
	$envVarMap{"RABBITMQ_DIST_PORT"} = $self->internalPortMap->{'dist'};
	
	
	# Create the container
	my %portMap;
	my $directMap = 0;
	if ($self->getParamValue( 'serviceType' ) eq $self->appInstance->getEdgeService()) {
		# This is an edge service.  Map the internal ports to the host ports
		$directMap = 1;
	}
	foreach my $key (keys %{$self->internalPortMap}) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	
	my $cmd = "";
	my $entryPoint = "";
	
	$self->host->dockerRun($applog, $self->getParamValue('dockerName'), $impl, $directMap, 
		\%portMap, \%volumeMap, \%envVarMap,$self->dockerConfigHashRef,	
		$entryPoint, $cmd, $self->needsTty);
		
	$self->setExternalPortNumbers();
	
	close $applog;
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");
	$logger->debug("stop RabbitmqDockerService");

	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/StopRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop($applog, $name);

	close $applog;
}


sub start {
	my ( $self, $logPath ) = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $logName          = "$logPath/StartRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	print $applog $self->meta->name . " In RabbitmqDockerService::startRabbitMQ $name on $hostname\n";

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{$self->getImpl()} = $self->internalPortMap->{$self->getImpl()};
		$self->portMap->{'mgmt'} = $self->internalPortMap->{'mgmt'};
		$self->portMap->{'dist'} = $self->internalPortMap->{'dist'};
	} else {
		# For bridged networking, ports get assigned at start time
		my $portMapRef = $self->host->dockerPort($name);
		$self->portMap->{$self->getImpl()} = $portMapRef->{$self->internalPortMap->{$self->getImpl()}};
		$self->portMap->{'mgmt'} = $portMapRef->{$self->internalPortMap->{'mgmt'}};
		$self->portMap->{'dist'} = $portMapRef->{$self->internalPortMap->{'dist'}};
	}
	$self->registerPortsWithHost();

	$self->host->startNscd();

	sleep 30;

	$self->configureAfterIsUp($applog);

	close $applog;
}

sub configureAfterIsUp {
	my ( $self, $applog ) = @_;
	
	if ( $self->appInstance->getNumActiveOfServiceType('msgServer') > 1 ) {
		$self->configureAfterIsUpClusteredRabbitMQ($applog);
	}
	else {
		$self->configureAfterIsUpSingleRabbitMQ($applog);
	}
}

sub configureAfterIsUpSingleRabbitMQ {
	my ( $self, $applog ) = @_;
	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');

	# create the auction user and vhost	
	$self->host->dockerExec($applog, $name, "rabbitmqctl add_user auction auction");

	$self->host->dockerExec($applog, $name, "rabbitmqctl set_user_tags auction administrator");

	$self->host->dockerExec($applog, $name, "rabbitmqctl add_vhost auction");

	$self->host->dockerExec($applog, $name, "rabbitmqctl set_permissions -p auction auction \".*\" \".*\" \".*\"");
	
}

sub configureAfterIsUpClusteredRabbitMQ {
	my ( $self, $applog ) = @_;

	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');
	my $out; 
	my $appInstance = $self->appInstance;
	
	print $applog $self->meta->name . " In RabbitmqService::configureAfterIsUpClusteredRabbitMQ on $hostname\n";

	# If this is the first Rabbitmq service to run,
	# then configure the numRabbitmqProcessed variable
	if ( !$appInstance->has_rabbitmqClusterHosts() ) {
		$appInstance->rabbitmqClusterHosts( [] );

		$appInstance->numRabbitmqProcessed(1);
	}
	else {
		$appInstance->numRabbitmqProcessed( $appInstance->numRabbitmqProcessed + 1 );
	}

	if ( $appInstance->numRabbitmqProcessed == 1 ) {

		# This is the first node.  Just configure it normally.
		# create the auction user and vhost	
		$self->host->dockerExec($applog, $name, "rabbitmqctl add_user auction auction");

		$self->host->dockerExec($applog, $name, "rabbitmqctl set_user_tags auction administrator");

		$self->host->dockerExec($applog, $name, "rabbitmqctl add_vhost auction");

		$self->host->dockerExec($applog, $name, "rabbitmqctl set_policy -p auction ha-all \".*\" '{\"ha-mode\":\"all\", \"ha-sync-mode\":\"automatic\"}'");

		$self->host->dockerExec($applog, $name, "rabbitmqctl set_permissions -p auction auction \".*\" \".*\" \".*\"");
		
	}
	else {

		# Need to start this node and add it to a cluster
		# Get the hostname of a node already in the cluster
		my $hostsRef                = $appInstance->rabbitmqClusterHosts;
		my $clusterHost             = $hostsRef->[0];
		my $clusterHostname         = $clusterHost->hostName;

		# Need to use exactly the same hostname as the cluster host thinks it has,
		# which may not be the same as the hostname the service knows

		print $applog $self->meta->name
		  . " In RabbitmqService::configureAfterIsUpClusteredRabbitMQ on $hostname: Joining cluster on $clusterHostname\n";

		# Join it to the cluster
		$self->host->dockerExec($applog, $name, "rabbitmqctl stop_app");
		$self->host->dockerExec($applog, $name, "rabbitmqctl join_cluster rabbit\@$clusterHostname");
		$self->host->dockerExec($applog, $name, "rabbitmqctl start_app");

	}

	# If this is the last rabbit service to be processed,
	# then clear the static variables for the next action
	if ( $appInstance->numRabbitmqProcessed == $self->appInstance->getNumActiveOfServiceType('msgServer') ) {
		$appInstance->clear_numRabbitmqProcessed;
		$appInstance->clear_rabbitmqClusterHosts;
	}
	else {
		my $hostsRef = $appInstance->rabbitmqClusterHosts;
		push @$hostsRef, $self->host;
	}

}

sub isUp {
	my ( $self, $fileout ) = @_;
	
	if ( !$self->isRunning($fileout) ) {
		return 0;
	}
	
	return 1;
	
}


sub isRunning {
	my ( $self, $fileout ) = @_;

	return $self->host->dockerIsRunning($fileout, $self->getParamValue('dockerName'));

}

override 'remove' => sub {
	my ($self, $logPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/RemoveRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove($applog, $name);

	close $applog;
};

sub setPortNumbers {
	my ( $self ) = @_;
	
	my $serviceType = $self->getParamValue( 'serviceType' );
	my $impl = $self->getParamValue( $serviceType . "Impl" );
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset = $self->getParamValue($serviceType . 'PortStep') * $portMultiplier;
	$self->internalPortMap->{$impl} = $self->getParamValue(  'rabbitmqPort' ) + $portOffset;
	$self->internalPortMap->{'mgmt'} = 15672;
	$self->internalPortMap->{'dist'} = 20000 + $self->internalPortMap->{$impl};
}

sub setExternalPortNumbers {
	my ($self) = @_;
	
	my $name = $self->getParamValue('dockerName');
	my $portMapRef = $self->host->dockerPort($name);

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{$self->getImpl()} = $self->internalPortMap->{$self->getImpl()};
		$self->portMap->{'mgmt'} = $self->internalPortMap->{'mgmt'};
		$self->portMap->{'dist'} = $self->internalPortMap->{'dist'};
	} else {
		# For bridged networking, ports get assigned at start time
		$self->portMap->{$self->getImpl()} = $portMapRef->{$self->internalPortMap->{$self->getImpl()}};
		$self->portMap->{'mgmt'} = $portMapRef->{$self->internalPortMap->{'mgmt'}};
		$self->portMap->{'dist'} = $portMapRef->{$self->internalPortMap->{'dist'}};
	}
}

sub configure {
	my ( $self, $logPath, $users, $suffix) = @_;

}

sub stopStatsCollection {
	my ( $self, $host, $configPath ) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;


}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

}

sub cleanStatsFiles {
	my ($self) = @_;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $name = $self->getParamValue('dockerName');
	my $hostname         = $self->host->hostName;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/RabbitmqDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";
	  	
	my $logContents = $self->host->dockerGetLogs($applog, $self->getParamValue('dockerName')); 
	print $applog $logContents;
	
	close $applog;
}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $name = $self->getParamValue('dockerName');

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}
	my $logName          = "$logpath/GetConfigFilesRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerExec($applog, $name, "rabbitmqctl report > /tmp/${hostname}_rabbitmqctl_report.txt");

	$self->host->dockerScpFileFrom($applog, $name, "/tmp/{hostname}_rabbitmqctl_report.txt", "$logpath/.");
	$self->host->dockerScpFileFrom($applog, $name, "/etc/rabbitmq/*", "$logpath/.");
	close $applog;
	
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

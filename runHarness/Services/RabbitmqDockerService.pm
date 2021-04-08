# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");
	
	my $name = $self->name;
	my $hostname         = $self->host->name;
	my $impl = $self->getImpl();

	my $logName          = "$logPath/Create" . ucfirst($impl) . "Docker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	# The default create doesn't map any volumes
	my %volumeMap;
	
	my %envVarMap;
	$envVarMap{"RABBITMQ_NODE_PORT"} = $self->internalPortMap->{$self->getImpl()};
	$envVarMap{"RABBITMQ_DIST_PORT"} = $self->internalPortMap->{'dist'};

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
	$envVarMap{"RABBITMQ_MEMORY"} = "$totalMemory$totalMemoryUnit";
		
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
	
	$self->host->dockerRun($applog, $self->name, $impl, $directMap, 
		\%portMap, \%volumeMap, \%envVarMap,$self->dockerConfigHashRef,	
		$entryPoint, $cmd, $self->needsTty);
		
	$self->setExternalPortNumbers();
	
	close $applog;
};

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");
	$logger->debug("stop RabbitmqDockerService");

	my $hostname         = $self->host->name;
	my $name = $self->name;
	my $logName          = "$logPath/StopRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop($applog, $name);

	close $applog;
}


sub startInstance {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->name;
	my $name = $self->name;
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

	sleep 5;

	$self->configureAfterIsUp($applog);

	close $applog;
}

sub configureAfterIsUp {
	my ( $self, $applog ) = @_;
	
	if ( $self->appInstance->getTotalNumOfServiceType('msgServer') > 1 ) {
		$self->configureAfterIsUpClusteredRabbitMQ($applog);
	}
	else {
		$self->configureAfterIsUpSingleRabbitMQ($applog);
	}
}

sub configureAfterIsUpSingleRabbitMQ {
	my ( $self, $applog ) = @_;

}

sub configureAfterIsUpClusteredRabbitMQ {
	my ( $self, $applog ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");

	my $hostname         = $self->host->name;
	my $name = $self->name;
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
		my ($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl add_user auction auction");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}
		
		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl set_user_tags auction administrator");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl add_vhost auction");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl set_policy -p auction ha-all \".*\" '{\"ha-mode\":\"all\", \"ha-sync-mode\":\"automatic\"}'");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl set_permissions -p auction auction \".*\" \".*\" \".*\"");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}
		
	}
	else {

		# Need to start this node and add it to a cluster
		# Get the hostname of a node already in the cluster
		my $hostsRef                = $appInstance->rabbitmqClusterHosts;
		my $clusterHost             = $hostsRef->[0];
		my $clusterHostname         = $clusterHost->name;

		# Need to use exactly the same hostname as the cluster host thinks it has,
		# which may not be the same as the hostname the service knows

		print $applog $self->meta->name
		  . " In RabbitmqService::configureAfterIsUpClusteredRabbitMQ on $hostname: Joining cluster on $clusterHostname\n";

		# Join it to the cluster
		my ($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl stop_app");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl join_cluster rabbit\@$clusterHostname");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

		($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "rabbitmqctl start_app");
		if ($cmdFailed) {
			$logger->error("Error configuring RabbitMQ.  Error = $cmdFailed");	
		}

	}

	# If this is the last rabbit service to be processed,
	# then clear the static variables for the next action
	if ( $appInstance->numRabbitmqProcessed == $self->appInstance->getTotalNumOfServiceType('msgServer') ) {
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
	my ($cmdFailed, $out) = $self->host->dockerExec($fileout, $self->name, "perl /isUp.pl");
	if ($cmdFailed) {
		return 0;
	} else {
		return 1;
	}	
}


sub isRunning {
	my ( $self, $fileout ) = @_;

	return $self->host->dockerIsRunning($fileout, $self->name);

}

sub isStopped {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return !$self->host->dockerExists( $fileout, $name );
}

override 'remove' => sub {
	my ($self, $logPath ) = @_;

	my $name = $self->name;
	my $hostname         = $self->host->name;
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
	my $hostname = $self->host->name;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByHostnameAndServiceType($hostname,$serviceType);
	my $portOffset = $self->getParamValue($serviceType . 'PortStep') * $portMultiplier;
	$self->internalPortMap->{$impl} = $self->getParamValue(  'rabbitmqPort' ) + $portOffset;
	$self->internalPortMap->{'mgmt'} = 15672;
	$self->internalPortMap->{'dist'} = 20000 + $self->internalPortMap->{$impl};
}

sub setExternalPortNumbers {
	my ($self) = @_;
	
	my $name = $self->name;
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
	my ( $self, $users, $suffix) = @_;

}

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
}

sub stopStatsCollection {
	my ( $self, $host ) = @_;

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

	my $name = $self->name;
	my $hostname         = $self->host->name;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName          = "$logpath/RabbitmqDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";
	  	
	my $logContents = $self->host->dockerGetLogs($applog, $self->name); 
	print $applog $logContents;
	
	close $applog;
}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqDockerService");

	my $hostname         = $self->host->name;
	my $name = $self->name;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}
	my $logName          = "$logpath/GetConfigFilesRabbitmqDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";


	my ($cmdFailed, $out) = $self->host->dockerExec($applog, $name, "sh -c \"rabbitmqctl report > /tmp/${hostname}_rabbitmqctl_report.txt\"");
	$self->host->dockerCopyFrom($applog, $name, "/tmp/${hostname}_rabbitmqctl_report.txt", "$logpath/.");
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

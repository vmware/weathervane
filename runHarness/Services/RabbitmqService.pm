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
package RabbitmqService;

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
	"memory",         "messages",
	"messages_ready", "messages_unacked",
	"ack_rate",       "deliver_rate",
	"publish_rate",   "redeliver_rate",
	"unacked_rate"
);
my @rabbitmqStatText = (
	"memory",
	"messages",
	"messages_ready",
	"messages_unacknowledged",
	"message_stats.ack_details.rate",
	"message_stats.deliver_get_details.rate",
	"message_stats.publish_details.rate",
	"message_stats.redeliver_details.rate",
	"messages_unacknowledged_details.rate"
);

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqService");
	$logger->debug("stop RabbitmqService");

	if ( $self->appInstance->getNumActiveOfServiceType('msgServer') > 1 ) {
		$self->stopClusteredRabbitMQ($logPath);
	}
	else {
		$self->stopSingleRabbitMQ($logPath);
	}

}

sub stopClusteredRabbitMQ {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $logName = "$logPath/StopClusteredRabbitMQ-$hostname.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	my $out;

	print $applog $self->meta->name
	  . " In RabbitmqService::StopClusteredRabbitMQ on $hostname\n";

	# Reset the node and then stop it
	$out = `$sshConnectString \"rabbitmqctl stop_app 2>&1\"`;
	print $applog $out;
	$out = `$sshConnectString \"rabbitmqctl reset 2>&1\"`;
	print $applog $out;
	$out = `$sshConnectString \"rabbitmqctl start_app 2>&1\"`;
	print $applog $out;

	# Stop the node
	if ( $self->isRunning($applog) ) {

		# RabbitMQ is running.  Stop it.
		print $applog "Stopping RabbitMQ on $hostname\n";
		$out = `$sshConnectString \"rabbitmqctl stop 2>&1 \"`;
		print $applog $out;
	}
}

sub stopSingleRabbitMQ {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $logName = "$logPath/StopSingleRabbitMQ-$hostname.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	my $out;

	print $applog $self->meta->name
	  . " In RabbitmqService::stopSingleRabbitMQ on $hostname\n";

	# Reset the node and then stop it
	$out = `$sshConnectString \"rabbitmqctl stop_app 2>&1\"`;
	print $applog $out;
	$out = `$sshConnectString \"rabbitmqctl reset 2>&1\"`;
	print $applog $out;
	$out = `$sshConnectString \"rabbitmqctl start_app 2>&1\"`;
	print $applog $out;

	if ( $self->isRunning($applog) ) {

		# RabbitMQ is running.  Stop it.
		print $applog "Stopping RabbitMQ on $hostname\n";
		$out = `$sshConnectString \"rabbitmqctl stop 2>&1 \"`;
		print $applog $out;
	}

}

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $logger           = get_logger("Weathervane::Services::RabbitmqService");

	my $logName = "$logPath/StartRabbitMQ-$hostname.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	my $out;

	print $applog $self->meta->name
	  . " In RabbitmqService::startRabbitMQ on $hostname\n";

	$logger->debug(
		"In RabbitmqService::startRabbitMQ on $hostname, internal port = "
		  . $self->internalPortMap->{ $self->getImpl() } );
	$self->portMap->{ $self->getImpl() } =
	  $self->internalPortMap->{ $self->getImpl() };
	$logger->debug(
		"In RabbitmqService::startRabbitMQ on $hostname, external port = "
		  . $self->portMap->{ $self->getImpl() } );
	my $rabbitMQPort = $self->internalPortMap->{ $self->getImpl() };
	$logger->debug(
"In RabbitmqService::startRabbitMQ on $hostname, rabbitMQPort = $rabbitMQPort"
	);
	$self->registerPortsWithHost();

	$out =
`$sshConnectString \"RABBITMQ_NODE_PORT=$rabbitMQPort rabbitmq-server -detached 2>&1\"`;
	print $applog $out;

	my $isUp = 0;
	for ( my $i = 0 ; $i < $self->getParamValue('isUpRetries') ; $i++ ) {
		sleep 5;
		$isUp = $self->isUp($applog);
		if ($isUp) {
			last;
		}
	}
	if ( !$isUp ) {
		print $applog "Couldn't start RabbitMQ on $hostname : $out\n";
		die "Couldn't start RabbitMQ on $hostname : $out\n";
	}

	$self->configureAfterIsUp($applog);

	$self->host->startNscd();

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
	my $sshConnectString = $self->host->sshConnectString;

	# create the auction user and vhost
	my $out =
	  `$sshConnectString \"rabbitmqctl add_user auction auction 2>&1\"`;
	print $applog $out;
	$out =
`$sshConnectString \"rabbitmqctl set_user_tags auction administrator 2>&1\"`;
	print $applog $out;
	$out = `$sshConnectString \"rabbitmqctl add_vhost auction 2>&1\"`;
	print $applog $out;
	$out =
`$sshConnectString \"rabbitmqctl set_permissions -p auction auction \\\".*\\\" \\\".*\\\" \\\".*\\\" 2>&1\"`;
	print $applog $out;

}

sub configureAfterIsUpClusteredRabbitMQ {
	my ( $self, $applog ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $out;
	my $appInstance = $self->appInstance;

	print $applog $self->meta->name
	  . " In RabbitmqService::configureAfterIsUpClusteredRabbitMQ on $hostname\n";

	# If this is the first Rabbitmq service to run,
	# then configure the numRabbitmqProcessed variable
	if ( !$appInstance->has_rabbitmqClusterHosts() ) {
		$appInstance->rabbitmqClusterHosts( [] );

		$appInstance->numRabbitmqProcessed(1);
	}
	else {
		$appInstance->numRabbitmqProcessed(
			$appInstance->numRabbitmqProcessed + 1 );
	}

	if ( $appInstance->numRabbitmqProcessed == 1 ) {

		# This is the first node.  Just configure it normally.
		# create the auction user and vhost
		$out =
`$sshConnectString \"rabbitmqctl add_user auction auction 2>&1\"`;
		print $applog $out;
		$out =
`$sshConnectString \"rabbitmqctl set_user_tags auction administrator 2>&1\"`;
		print $applog $out;
		$out = `$sshConnectString \"rabbitmqctl add_vhost auction 2>&1\"`;
		print $applog $out;
		$out =
`$sshConnectString \"rabbitmqctl set_policy -p auction ha-all \\\".*\\\" '{\\\"ha-mode\\\":\\\"all\\\", \\\"ha-sync-mode\\\":\\\"automatic\\\"}' 2>&1\"`;
		print $applog $out;
		$out =
`$sshConnectString \"rabbitmqctl set_permissions -p auction auction \\\".*\\\" \\\".*\\\" \\\".*\\\" 2>&1\"`;
		print $applog $out;
	}
	else {

		# Need to start this node and add it to a cluster
		# Get the hostname of a node already in the cluster
		my $hostsRef                = $appInstance->rabbitmqClusterHosts;
		my $clusterHost             = $hostsRef->[0];
		my $clusterHostname         = $clusterHost->hostName;
		my $clusterSshConnectString = $clusterHost->sshConnectString;

	  # Need to use exactly the same hostname as the cluster host thinks it has,
	  # which may not be the same as the hostname the service knows

		print $applog $self->meta->name
		  . " In RabbitmqService::configureAfterIsUpClusteredRabbitMQ on $hostname: Joining cluster on $clusterHostname\n";

		# Join it to the cluster
		$out = `$sshConnectString \"rabbitmqctl stop_app 2>&1\"`;
		print $applog $out;
		$out =
`$sshConnectString \"rabbitmqctl join_cluster rabbit\@$clusterHostname 2>&1\"`;
		print $applog $out;
		$out = `$sshConnectString \"rabbitmqctl start_app 2>&1\"`;
		print $applog $out;

	}

	# If this is the last rabbit service to be processed,
	# then clear the static variables for the next action
	if ( $appInstance->numRabbitmqProcessed ==
		$self->appInstance->getNumActiveOfServiceType('msgServer') )
	{
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

	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString \"rabbitmqctl status 2>&1\"`;
	print $fileout "RabbitMQ status:\n";
	print $fileout $out;
	if ( $out =~ /nodedown/ ) {
		return 0;
	}
	else {
		return 1;
	}

}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getParamValue( $serviceType . "Impl" );
	my $portMultiplier =
	  $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset =
	  $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;
	$self->internalPortMap->{$impl} =
	  $self->getParamValue('rabbitmqPort') + $portOffset;
}

sub setExternalPortNumbers {
	my ($self) = @_;
	$self->portMap->{ $self->getImpl() } =
	  $self->internalPortMap->{ $self->getImpl() };

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');

	# Modify rabbitmq-env.conf and then copy to app server
	open( FILEIN, "$configDir/rabbitmq/rabbitmq-env.conf" )
	  or die "Can't open file $configDir/rabbitmq/rabbitmq-env.conf: $!\n";
	open( FILEOUT, ">/tmp/rabbitmq-env$suffix.conf" )
	  or die "Can't open file /tmp/rabbitmq-env$suffix.conf: $!\n";

	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^NODENAME/ ) {
			print FILEOUT "NODENAME=rabbit\@$hostname\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	close FILEIN;
	close FILEOUT;

`$scpConnectString /tmp/rabbitmq-env$suffix.conf root\@$scpHostString:/etc/rabbitmq/rabbitmq-env.conf`;

}

sub stopStatsCollection {
	my ( $self, $host, $configPath ) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
#	my $logger           = get_logger("Weathervane::Services::RabbitmqService");
#	my $console_logger   = get_logger("Console");
#	my $hostname         = $self->host->hostName;
#	my $sshConnectString = $self->host->sshConnectString;
#	$logger->debug("startStatsCollection");
#
#	my $pid              = fork();
#	# We fork a process to get RabbitMQ statistics at regular intervals.
#	if ( $pid == 0 ) {
#		my $time = 0;
#
#		my %queueStats;
#		my %outfile;
#
#		# Create a statistics object for each queue we will be following
#		my $data =
#`$sshConnectString /usr/local/bin/rabbitmqadmin -d 3 -f long -V auction -u auction -p auction list queues name  2>/tmp/rabbitMQStats_${hostname}.stderr`;
#		if ( -s "/tmp/${hostname}_esxtop.stderr" ) {
#				$logger->debug("rabbitmqadmin did not run successfully for $hostname.");
#
#				# An error occurred when running rabbitmqadmin
#				my $errorContents = "";
#				{
#					local $/ = undef;
#					open FILE, "/tmp/rabbitMQStats_${hostname}.stderr"
#					  or die "Couldn't open /tmp/${hostname}_esxtop.stderr: $!";
#					$errorContents = <FILE>;
#					close FILE;
#				}
#				$console_logger->error(
#					"Could not collect RabbitMQ stats $hostname. Error is:\n",
#					$errorContents );
#				exit(-1);
#		}
#
#		my @data = split /\n/, $data;
#		while (@data) {
#			my $inline = shift @data;
#			if ( $inline =~ /^\s*name:\s+(\S+)\s*$/ ) {
#				my $queue = $1;
#				$queueStats{$queue} = {};
#				foreach my $stat (@RabbitmqService::rabbitmqStatNames) {
#					$queueStats{$queue}->{$stat} =
#					  Statistics::Descriptive::Full->new();
#				}
#
#				# Open a file to log the interval results
#				open( $outfile{$queue},
#					">/tmp/rabbitMQStats_${hostname}_$queue.csv" )
#				  or die
#				  "Can't open /tmp/rabbitMQStats_${hostname}_$queue.csv : $!";
#				my $filehandle = $outfile{$queue};
#				print $filehandle "Time into Steady-State";
#				foreach my $stat (@RabbitmqService::rabbitmqStatNames) {
#					print $filehandle ", $stat";
#				}
#				print $filehandle "\n";
#			}
#		}
#
#		for ( my $i = 0 ; $i < $numIntervals ; $i++ ) {
#
#			# Get the queue info
#			$logger->debug(
#				"startStatsCollection.  Getting RabbitMQ Queue Data");
#			my $data =
#`$sshConnectString /usr/local/bin/rabbitmqadmin -d 3 -f long -V auction -u auction -p auction list queues 2>/tmp/rabbitMQStats_${hostname}.stderr`;
#
#			if ( -s "/tmp/${hostname}_esxtop.stderr" ) {
#				$logger->debug("rabbitmqadmin did not run successfully for $hostname.");
#
#				# An error occurred when running rabbitmqadmin
#				my $errorContents = "";
#				{
#					local $/ = undef;
#					open FILE, "/tmp/rabbitMQStats_${hostname}.stderr"
#					  or die "Couldn't open /tmp/${hostname}_esxtop.stderr: $!";
#					$errorContents = <FILE>;
#					close FILE;
#				}
#				$console_logger->error(
#					"Could not collect RabbitMQ stats $hostname. Error is:\n",
#					$errorContents );
#				exit(-1);
#			}
#
#			my @data = split /\n/, $data;
#
#			while (@data) {
#				my $inline = shift @data;
#				if ( $inline =~ /\s+name:\s+([^\s]+)\s*$/ ) {
#					my $queueName = $1;
#
#					my $filehandle = $outfile{$queueName};
#					my %values;
#					foreach my $stat (@RabbitmqService::rabbitmqStatNames) {
#						$values{$stat} = -1;
#					}
#
#					print $filehandle "$time";
#					while ( !( $inline =~ /-----------------------/ ) ) {
#						$inline = shift @data;
#
#						for (
#							my $j = 0 ;
#							$j < $#RabbitmqService::rabbitmqStatText ;
#							$j++
#						  )
#						{
#							my $stat;
#							my $statName;
#							my $matchText =
#							  $RabbitmqService::rabbitmqStatText[$j];
#							if ( $inline =~ /$matchText:(.*+)$/ ) {
#								my $value = $1;
#								$statName =
#								  $RabbitmqService::rabbitmqStatNames[$j];
#								if ( $value =~ /\s([\d\.]+)[^\d]*$/ ) {
#									$stat =
#									  $queueStats{$queueName}->{$statName};
#									$stat->add_data($1);
#									$values{$statName} = $1;
#								}
#							}
#						}
#					}
#
#					foreach my $stat (@RabbitmqService::rabbitmqStatNames) {
#						print $filehandle ", $values{$stat}";
#					}
#					print $filehandle "\n";
#				}
#			}
#			sleep $intervalLengthSec;
#			$time += $intervalLengthSec;
#		}
#
#		open( OUTFILE, ">/tmp/rabbitMQStats_${hostname}_summary.txt" )
#		  or die "Can't open /tmp/rabbitMQStats_${hostname}_summary.txt : $!";
#		foreach my $queue ( keys %queueStats ) {
#			my $filehandle = $outfile{$queue};
#			close $filehandle;
#
#			foreach my $stat (@RabbitmqService::rabbitmqStatNames) {
#				my $mean = $queueStats{$queue}->{$stat}->mean();
#				$queue =~ /auction\.(\w+)\.queue/;
#				my $queueName = $1;
#				print OUTFILE "${queueName}_$stat : $mean\n";
#			}
#		}
#		close OUTFILE;
#		exit;
#	}

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger   = get_logger("Weathervane::Services::RabbitmqService");
	my $hostname = $self->host->hostName;

#	my $out = `mv /tmp/rabbitMQStats_${hostname}* $destinationPath/. 2>&1`;

}

sub cleanStatsFiles {
	my ($self)   = @_;
	my $logger   = get_logger("Weathervane::Services::RabbitmqService");
	my $hostname = $self->host->hostName;

#	my $out = `rm -f /tmp/rabbitMQStats_${hostname}* 2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqService");

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $hostname         = $self->host->hostName;

	my $maxLogLines = $self->getParamValue('maxLogLines');
	$self->checkSizeAndTruncate( "/var/log/rabbitmq", "rabbit\@$hostname.log",
		$maxLogLines );

	my $out =
`$scpConnectString root\@$scpHostString:/var/log/rabbitmq/rabbit\@$hostname.log $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqService");

	my $sshConnectString = $self->host->sshConnectString;
	my $out = `$sshConnectString \"rm -f /var/log/rabbitmq/* 2>&1\"`;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::RabbitmqService");

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	`mkdir -p $destinationPath`;

	my $out =
`$sshConnectString \"rabbitmqctl report > /tmp/${hostname}_rabbitmqctl_report.txt\" 2>&1`;
	$out =
`$scpConnectString root\@$scpHostString:/tmp/${hostname}_rabbitmqctl_report.txt $destinationPath/. 2>&1`;
	$out =
`$scpConnectString root\@$scpHostString:/etc/rabbitmq/* $destinationPath/. 2>&1`;

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

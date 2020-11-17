# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package ZookeeperDockerService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);
use WeathervaneTypes;
use JSON;

use LWP;
use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

# Need to override start so that we can write ZK_SERVERS file after
# all containers are up
override 'start' => sub {
	my ($self, $serviceType, $users, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerServer");
	$logger->debug(
		"start serviceType $serviceType, Workload ",
		$self->appInstance->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $servicesRef = $self->appInstance->getAllServicesByType($serviceType);

	foreach my $service (@$servicesRef) {
		$logger->debug( "Start " . $service->name . "\n" );
		$service->startInstance($logPath);
	}
	
	sleep 10;
		
	foreach my $service (@$servicesRef) {
		$logger->debug( "SetZkServers " . $service->name . "\n" );
		$service->setZkServers( );
	}
};

sub startInstance {
	my ($self, $logPath)            = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerServer");

	my $impl     = $self->getImpl();		
	my $hostname = $self->host->name;
	my $name     = $self->name;
	my $instanceNum = $self->instanceNum;

	$logger->debug("CreateZookeeperDocker-${name}");
	my $logName = "$logPath/CreateZookeeperDocker-${name}.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# doesn't map any volumes
	my %volumeMap;

	# Set environment variables for startup configuration
	
	my %envVarMap;
	$envVarMap{"ZK_CLIENT_PORT"} = $self->internalPortMap->{"client"};
	$envVarMap{"ZK_ID"} = $instanceNum;
	$logger->debug("CreateZookeeperDocker-${name} envVarMap{\"ZK_CLIENT_PORT\"} = " 
				. $envVarMap{"ZK_CLIENT_PORT"} .  ", envVarMap = " . (values %envVarMap));
		
	# Create the container
	my %portMap;
	my $directMap = 1;
	foreach my $key ( keys %{ $self->internalPortMap } ) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}
	
	my $cmd        = "";
	my $entryPoint = "";
	$self->host->dockerRun(
		$applog, $self->name,
		$impl, $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef,
		$entryPoint, $cmd, $self->needsTty
	);

	$self->setExternalPortNumbers();
	close $applog;
}

sub setZkServers {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerServer");
	my $name = $self->name;
	my $instanceNum = $self->instanceNum;

	my $zookeeperServersRef = $self->appInstance->getAllServicesByType("coordinationServer");
	my $zookeeperServers = "";
	foreach my $zookeeperServer (@$zookeeperServersRef) {
		my $id =  $zookeeperServer->instanceNum;
		my $hostname;
		my $peerPort;
		my $electionPort;			
		if ($id == $instanceNum) {
			$hostname = "0.0.0.0";
			$peerPort = $zookeeperServer->internalPortMap->{"peer"};
			$electionPort = $zookeeperServer->internalPortMap->{"election"};			
		} else {
			$hostname = $self->getHostnameForUsedService($zookeeperServer);
			$peerPort = $self->getPortNumberForUsedService( $zookeeperServer, "peer" );
			$electionPort = $self->getPortNumberForUsedService( $zookeeperServer, "election" );
		}
		$zookeeperServers .= "server." . $id . "=" . $hostname. ":" .
							$peerPort . ":" . $electionPort . "," ;
	}
	chop($zookeeperServers);
	
	$logger->debug("setZkServers-${name} zookeeperServers = $zookeeperServers");
	
	# Now write zookeeperServers to a file and copy the file to the container
	open( FILEOUT, ">/tmp/zookeeperServers-${instanceNum}.txt" )
	  or die "Can't open file /tmp/zookeeperServers-${instanceNum}.txt: $!";
	print FILEOUT "$zookeeperServers\n";
	close FILEOUT;
	
	$self->host->dockerCopyTo($name, "/tmp/zookeeperServers-${instanceNum}.txt", "/zookeeperServers.txt");
	
}

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerServer");
	
	my $hostname         = $self->host->name;
	my $name             = $self->name;
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StopZookeeperDocker-$hostname-$name-$time.log";
	$logger->debug("stop ZookeeperDockerServer");

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStop( $applog, $name );

	close $applog;
	
}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerService");
	my $hostname = $self->host->name;
	my $name     = $self->name;
	$logger->debug("remove. logPath = $logPath, hostname = $hostname, name = $name");
	my $logName  = "$logPath/RemoveZookeeperDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerStopAndRemove( $applog, $name );

	close $applog;
};

sub isUp {
	my ( $self, $fileout ) = @_;

	return $self->isRunning($fileout);

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return $self->host->dockerIsRunning( $fileout, $name );
}

sub isStopped {
	my ( $self, $fileout ) = @_;
	my $name = $self->name;

	return !$self->host->dockerExists( $fileout, $name );
}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType    = $self->getParamValue('serviceType');
	my $impl           = $self->getParamValue( $serviceType . "Impl" );
	my $hostname = $self->host->name;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByHostnameAndServiceType($hostname,$serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	$self->internalPortMap->{"client"}   = $self->getParamValue('zookeeperClientPort') + $portOffset;
	$self->internalPortMap->{"peer"}     = $self->getParamValue('zookeeperPeerPort') + $portOffset;
	$self->internalPortMap->{"election"} = $self->getParamValue('zookeeperElectionPort') + $portOffset;

}

sub setExternalPortNumbers {
	my ($self) = @_;
	# For bridged networking, ports get assigned at start time
	my $name = $self->name;
	$self->portMap->{"client"}   = $self->internalPortMap->{"client"};
	$self->portMap->{"peer"}     = $self->internalPortMap->{"peer"};
	$self->portMap->{"election"} = $self->internalPortMap->{"election"};
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
	my $hostname = $self->host->name;

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->name;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	
	my $name     = $self->name;
	my $hostname = $self->host->name;

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/ZookeeperDockerLogs-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening $logName:$!";

	my $logContents = $self->host->dockerGetLogs( $applog, $name );

	print $applog $logContents;

	close $applog;


}

sub cleanLogFiles {
	my ($self)           = @_;
	
}

sub parseLogFiles {
	my ( $self, $host ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	
	my $name     = $self->name;
	my $hostname = $self->host->name;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/GetConfigFilesZookeeperDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerCopyFrom( $applog, $name, "$zookeeperRoot/conf/zoo.cfg", "$logpath/." );

	close $applog;

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

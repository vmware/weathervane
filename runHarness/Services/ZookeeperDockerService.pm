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

has '+name' => ( default => 'ZookeeperServer', );

has '+version' => ( default => 'xx', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

override 'create' => sub {
	my ( $self, $logPath ) = @_;

	if ( !$self->getParamValue('useDocker') ) {
		return;
	}

	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $impl     = $self->getImpl();

	my $logName = "$logPath/CreateZookeeperDocker-$hostname-$name.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# The default create doesn't map any volumes
	my %volumeMap;

	# Set environment variables for startup configuration
	my $numZookeeperServers = $self->appInstance->getMaxNumOfServiceType("coordinationServer");
	my $zookeeperServersRef = $self->appInstance->getActiveServicesByType("coordinationServer");
	my $instanceNum = $self->getParamValue("instanceNum");
	my $zookeeperServers = "";
	foreach my $zookeeperServer (@$zookeeperServersRef) {
		my $id =  $zookeeperServer->getParamValue("instanceNum");
		my $peerPort;
		my $electionPort;
		if ($instanceNum == $id) {	
			$peerPort = $zookeeperServer->internalPortMap->{"peer"};
			$electionPort = $zookeeperServer->internalPortMap->{"election"};			
		} else {
			$peerPort = $zookeeperServer->portMap->{"peer"};
			$electionPort = $zookeeperServer->portMap->{"election"};
		}
		$zookeeperServers .= "server." . $id . "=" . $zookeeperServer->host->hostName . ":" .
							$peerPort . ":" . $electionPort . "," ;
	}
	chop($zookeeperServers);
	
	my %envVarMap;
	$envVarMap{"ZK_CLIENT_PORT"} = $self->internalPortMap->{"client"};
	$envVarMap{"ZK_PEER_PORT"} = $self->internalPortMap->{"peer"};
	$envVarMap{"ZK_ELECTION_PORT"} = $self->internalPortMap->{"election"};
	$envVarMap{"ZK_SERVERS"} = $zookeeperServers;
	$envVarMap{"ZK_ID"} = $instanceNum;
	
	
	# Create the container
	my %portMap;
	my $directMap = 0;
	my $useVirtualIp     = $self->getParamValue('useVirtualIp');
	if ( $self->isEdgeService() && $useVirtualIp ) {
		# This is an edge service and we are using virtual IPs.  Map the internal ports to the host ports
		$directMap = 1;
	}
	foreach my $key ( keys %{ $self->internalPortMap } ) {
		my $port = $self->internalPortMap->{$key};
		$portMap{$port} = $port;
	}

	my $cmd        = "";
	my $entryPoint = "";

	$self->host->dockerRun(
		$applog, $self->getParamValue('dockerName'),
		$impl, $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef,
		$entryPoint, $cmd, $self->needsTty
	);

	close $applog;
};

sub stop {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerServer");
	
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
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

sub start {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $name             = $self->getParamValue('dockerName');
	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName          = "$logPath/StartZookeeperDocker-$hostname-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->setExternalPortNumbers();

	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
	
}

override 'remove' => sub {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperDockerService");
	my $hostname = $self->host->hostName;
	my $name     = $self->getParamValue('dockerName');
	$logger->debug("remove. logPath = $logPath, hostname = $hostname, dockerName = $name");
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
	my $name = $self->getParamValue('dockerName');

	return $self->host->dockerIsRunning( $fileout, $name );
}

sub setPortNumbers {
	my ($self) = @_;

	my $serviceType    = $self->getParamValue('serviceType');
	my $impl           = $self->getParamValue( $serviceType . "Impl" );
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset     = $self->getParamValue( $serviceType . 'PortStep' ) * $portMultiplier;

	$self->internalPortMap->{"client"}   = $self->getParamValue('zookeeperClientPort') + $portOffset;
	$self->internalPortMap->{"peer"}     = $self->getParamValue('zookeeperPeerPort') + $portOffset;
	$self->internalPortMap->{"election"} = $self->getParamValue('zookeeperElectionPort') + $portOffset;

}

sub setExternalPortNumbers {
	my ($self) = @_;

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {
		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"client"}   = $self->internalPortMap->{"client"};
		$self->portMap->{"peer"}     = $self->internalPortMap->{"peer"};
		$self->portMap->{"election"} = $self->internalPortMap->{"election"};
	}
	else {
		# For bridged networking, ports get assigned at start time
		my $name = $self->getParamValue('dockerName');
		my $portMapRef = $self->host->dockerPort($name );
		$self->portMap->{"client"}   = $portMapRef->{ $self->internalPortMap->{"client"} };
		$self->portMap->{"peer"}     = $portMapRef->{ $self->internalPortMap->{"peer"} };
		$self->portMap->{"election"} = $portMapRef->{ $self->internalPortMap->{"election"} };
	}

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;

}

sub stopStatsCollection {
	my ( $self, $host, $configPath ) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
	
	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;

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
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	
	my $name     = $self->getParamValue('dockerName');
	my $hostname = $self->host->hostName;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');

	my $logpath = "$destinationPath/$name";
	if ( !( -e $logpath ) ) {
		`mkdir -p $logpath`;
	}

	my $logName = "$logpath/GetConfigFilesZookeeperDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	$self->host->dockerScpFileFrom( $applog, $name, "$zookeeperRoot/conf/zoo.cfg", "$logpath/." );

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

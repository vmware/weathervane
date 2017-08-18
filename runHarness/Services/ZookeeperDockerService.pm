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

	my $portMapRef = $self->host->dockerReload( $applog, $name );

	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"client"}   = $self->internalPortMap->{"client"};
		$self->portMap->{"peer"}     = $self->internalPortMap->{"peer"};
		$self->portMap->{"election"} = $self->internalPortMap->{"election"};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{"client"}   = $portMapRef->{ $self->internalPortMap->{"client"} };
		$self->portMap->{"peer"}     = $portMapRef->{ $self->internalPortMap->{"peer"} };
		$self->portMap->{"election"} = $portMapRef->{ $self->internalPortMap->{"election"} };
	}
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

	my $name = $self->getParamValue('dockerName');
	
	my $portMapRef = $self->host->dockerPort($name );
	if ( $self->host->dockerNetIsHostOrExternal($self->getParamValue('dockerNet') )) {

		# For docker host networking, external ports are same as internal ports
		$self->portMap->{"client"}   = $self->internalPortMap->{"client"};
		$self->portMap->{"peer"}     = $self->internalPortMap->{"peer"};
		$self->portMap->{"election"} = $self->internalPortMap->{"election"};
	}
	else {

		# For bridged networking, ports get assigned at start time
		$self->portMap->{"client"}   = $portMapRef->{ $self->internalPortMap->{"client"} };
		$self->portMap->{"peer"}     = $portMapRef->{ $self->internalPortMap->{"peer"} };
		$self->portMap->{"election"} = $portMapRef->{ $self->internalPortMap->{"election"} };
	}

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname  = $self->host->hostName;
	my $configDir = $self->getParamValue('configDir');
	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');
	my $zookeeperDataDir = $self->getParamValue("zookeeperDataDir");
	my $name             = $self->getParamValue('dockerName');

	my $logName = "$logPath/ConfigureZookeeperDocker-$hostname-$name.log";

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	
	my $configFileName = "$configDir/zookeeper/zoo.cfg";
	open( FILEIN,  $configFileName )        or die "Can't open file $configFileName: $!";
	open( FILEOUT, ">/tmp/zoo-$name$suffix.cfg" ) or die "Can't open file /tmp/zoo-$name$suffix.cfg: $!";
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^\s*clientPort=/ ) {
			print FILEOUT "clientPort=" . $self->internalPortMap->{"client"} . "\n";
		} elsif ($inline =~ /^\s*dataDir=/ ) {
			print FILEOUT "dataDir=$zookeeperDataDir\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	my $numZookeeperServers = $self->appInstance->getMaxNumOfServiceType("coordinationServer");
	if ($numZookeeperServers > 1) {
		# Add server info for a replicated config
		print FILEOUT "initLimit=5\n";
		print FILEOUT "syncLimit=2\n";
		my $instanceNum = $self->getParamValue("instanceNum");
		
		my $zookeeperServersRef = $self->appInstance->getActiveServicesByType("coordinationServer");
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
			print FILEOUT "server." . $id . "=" . $zookeeperServer->host->hostName . ":" .
								$peerPort . ":" .
								$electionPort . "\n" ;
		}
		
		open( MYIDFILE, ">/tmp/myid-$name$suffix" ) or die "Can't open file /tmp/myid-$name$suffix: $!";
		print MYIDFILE "$instanceNum\n";
		close MYIDFILE;
		$self->host->dockerScpFileTo( $applog, $name, "/tmp/myid-$name$suffix", "$zookeeperDataDir/myid" );
		
	}	

	close FILEIN;
	close FILEOUT;


	# Push the config file to the docker container
	$self->host->dockerScpFileTo( $applog, $name, "/tmp/zoo-$name$suffix.cfg", "$zookeeperRoot/conf/zoo.cfg" );
	
	close $applog;

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

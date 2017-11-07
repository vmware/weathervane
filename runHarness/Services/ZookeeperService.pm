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
package ZookeeperService;

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

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperServer");
	$logger->debug("stop ZookeeperServer");
	my $sshConnectString = $self->host->sshConnectString;
	my $hostname         = $self->host->hostName;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');

	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $logName        = "$logPath/StopZookeeper-$hostname-W${workloadNum}I${appInstanceNum}.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog "Checking whether zookeeper is up on $hostname\n";
	if ( $self->isRunning($applog) ) {

		# The server is running
		print $applog "Stopping zookeeper on $hostname\n";
		my $cmdOut = `$sshConnectString $zookeeperRoot/bin/zkServer.sh stop 2>&1`;
		print $applog $cmdOut;

		if ( $self->isRunning($applog) ) {
			print $applog "Couldn't stop zookeeper on $hostname: $cmdOut";
			die "Couldn't stop zookeeper on $hostname: $cmdOut";
		}

	}
	
	# Check for old processes
	my $cmdOut = `$sshConnectString ps x`;
	if ($cmdOut =~ /^\s*(\d+)\s+.*:\d\d\s+.*java.*zookeeper/m) {
		my $pid = $1;
		$logger->debug( "Found pid "
                      . $pid
                      . " for zookeeper W${workloadNum}I${appInstanceNum} on "
                      . $hostname );
		$cmdOut = `$sshConnectString kill $pid`;
		print $applog "$cmdOut\n";
	}

	close $applog;
}

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $workloadNum      = $self->getParamValue('workloadNum');
	my $appInstanceNum   = $self->getParamValue('appInstanceNum');
	my $logName          = "$logPath/StartZookeeper-$hostname-W${workloadNum}I${appInstanceNum}.log";
	my $logger           = get_logger("Weathervane::Services::ZookeeperServer");
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');
	my $zookeeperDataDir = $self->getParamValue("zookeeperDataDir");

	my $serviceType = $self->getParamValue('serviceType');
	my $impl        = $self->getImpl();

	$self->portMap->{"client"}   = $self->internalPortMap->{"client"};
	$self->portMap->{"peer"}     = $self->internalPortMap->{"peer"};
	$self->portMap->{"election"} = $self->internalPortMap->{"election"};
	$self->registerPortsWithHost();

	my $applog;
	open( $applog, ">$logName" ) || die "Error opening /$logName:$!";
	print $applog "Checking whether zookeeper is up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is running
		print $applog "Starting zookeeper on $hostname\n";
		my $cmdOut = `$sshConnectString \"cd  $zookeeperDataDir;$zookeeperRoot/bin/zkServer.sh start 2>&1\"`;
		print $applog $cmdOut;
	}

	close $applog;

}

sub isUp {
	my ( $self, $fileout ) = @_;
	my $logger = get_logger("Weathervane::Services::ZookeeperServer");

	return $self->isRunning($fileout);

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	my $hostName         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $logger           = get_logger("Weathervane::Services::ZookeeperServer");
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');

	print $fileout "Checking whether Zookeeper is running on $hostName";
	my $cmdOut = `$sshConnectString $zookeeperRoot/bin/zkServer.sh status 2>&1`;
	print $fileout "$cmdOut\n";
	if ( $cmdOut =~ /Error contacting/ ) {
		print $fileout "Zookeeper is not running on $hostName";
		return 0;
	}
	else {
		print $fileout "Zookeeper is running on $hostName";
		return 1;
	}
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

	$self->internalPortMap->{"client"}   = $self->internalPortMap->{"client"};
	$self->internalPortMap->{"peer"}     = $self->internalPortMap->{"peer"};
	$self->internalPortMap->{"election"} = $self->internalPortMap->{"election"};

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname  = $self->host->hostName;
	my $configDir = $self->getParamValue('configDir');
	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');
	my $zookeeperDataDir = $self->getParamValue("zookeeperDataDir");
	
	my $configFileName = "$configDir/zookeeper/zoo.cfg";
	open( FILEIN,  $configFileName )        or die "Can't open file $configFileName: $!";
	open( FILEOUT, ">/tmp/zoo$suffix.cfg" ) or die "Can't open file /tmp/zoo$suffix.cfg: $!";
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
		
		my $zookeeperServersRef = $self->appInstance->getActiveServicesByType("coordinationServer");
		foreach my $zookeeperServer (@$zookeeperServersRef) {
			my $id =  $zookeeperServer->getParamValue("instanceNum");
			my $peerPort = $zookeeperServer->internalPortMap->{"peer"};
			my $electionPort = $zookeeperServer->internalPortMap->{"election"};
			print FILEOUT "server." . $id . "=" . $zookeeperServer->host->hostName . ":" .
								$peerPort . ":" .
								$electionPort . "\n" ;
		}
		
		open( MYIDFILE, ">/tmp/myid$suffix" ) or die "Can't open file /tmp/myid$suffix: $!";
		print MYIDFILE $self->getParamValue("instanceNum") . "\n";
		close MYIDFILE;
		`$scpConnectString /tmp/myid$suffix root\@$scpHostString:$zookeeperDataDir/myid`;
		
	}	

	close FILEIN;
	close FILEOUT;

	`$scpConnectString /tmp/zoo$suffix.cfg root\@$scpHostString:$zookeeperRoot/conf/zoo.cfg`;

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
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $zookeeperDataDir    = $self->getParamValue('zookeeperDataDir');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:$zookeeperDataDir/zookeeper.out $destinationPath/. 2>&1`;


}

sub cleanLogFiles {
	my ($self)           = @_;
	my $sshConnectString = $self->host->sshConnectString;
	my $zookeeperDataDir    = $self->getParamValue('zookeeperDataDir');
	my $out = `$sshConnectString rm -rf $zookeeperDataDir/*`;
	
}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $scpConnectString  = $self->host->scpConnectString;
	my $scpHostString     = $self->host->scpHostString;
	my $zookeeperRoot    = $self->getParamValue('zookeeperRoot');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:$zookeeperRoot/conf/zoo.cfg $destinationPath/. 2>&1`;

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

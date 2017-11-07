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
package KeepalivedService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);
use Utils qw(getIpAddresses getIpAddress);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'Keepalived', );

has '+version' => ( default => '1.2.13', );

has '+description' => ( default => 'Keepalived Virtual Server', );

has 'backupPriority' => (
	is      => 'rw',
	isa     => 'Int',
	default => 100,
);

has 'masterPriority' => (
	is      => 'rw',
	isa     => 'Int',
	default => 150,
);

override 'initialize' => sub {
	my ( $self, $numIpManagers ) = @_;
	my $logger            = get_logger("Weathervane::Services::KeepalivedService");
	$logger->debug("initialize called with numIpManagers = $numIpManagers");

	super();
};

# Make sure we don't report that keepalived is using docker, because it
# never does, even if the config file default is true
override 'useDocker' => sub {
	my ( $self ) = @_;
	return 0;
};

sub startInstance {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartKeepalived-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $keepalivedServerRoot = $self->getParamValue('keepalivedServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog $self->meta->name . " In KeepalivedService::start\n";

	# Check whether the keepalived is up
	print $applog "Checking whether keepalived is already up on $hostname\n";
	if ( !$self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting keepalived on $hostname\n";
		print $applog "$sshConnectString service keepalived start\n";
		my $out = `$sshConnectString service keepalived start 2>&1`;
		print $applog "$out\n";
	}
	$self->registerPortsWithHost();

	$self->host->startNscd();

	close $applog;
}

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::KeepalivedService");
	$logger->debug("stop KeepalivedService");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopKeepalived-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;

	my $keepalivedServerRoot = $self->getParamValue('keepalivedServerRoot');

	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog $self->meta->name . " In KeepalivedService::stop\n";

	# Check whether the app server is up
	print $applog "Checking whether keepalived is already up on $hostname\n";
	if ( $self->isRunning($applog) ) {

		# The server is running
		print $applog "Stopping keepalived on $hostname\n";
		print $applog "$sshConnectString service keepalived stop\n";
		my $out = `$sshConnectString service keepalived stop 2>&1`;
		print $applog "$out\n";

	}

	close $applog;
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

	my $out = `$sshConnectString service keepalived status 2>&1`;
	print $fileout $out;
	if (($out =~ /is running/ ) || ($out =~ /active\s+\(running/)) {
		return 1;
	}
	else {
		return 0;
	}
}

sub netmaskHexToBits {
	my ($hex) = @_;

	if    ( $hex == 0 )   { return 0; }
	elsif ( $hex == 128 ) { return 1; }
	elsif ( $hex == 192 ) { return 2; }
	elsif ( $hex == 224 ) { return 3; }
	elsif ( $hex == 240 ) { return 4; }
	elsif ( $hex == 248 ) { return 5; }
	elsif ( $hex == 252 ) { return 6; }
	elsif ( $hex == 254 ) { return 7; }
	elsif ( $hex == 255 ) { return 8; }
}

sub setPortNumbers {
	my ( $self ) = @_;
	
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $logger     = get_logger("Weathervane::Services::KeepalivedService");

	my $server               = $self->host->hostName;
	my $keepalivedServerRoot = $self->getParamValue('keepalivedServerRoot');
	my $scpConnectString     = $self->host->scpConnectString;
	my $scpHostString        = $self->host->scpHostString;
	my $sshConnectString     = $self->host->sshConnectString;
	my $configDir            = $self->getParamValue('configDir');
	my $numIpManagers        = $self->appInstance->getNumActiveOfServiceType('ipManager');
	my $instanceNum          = $self->getParamValue('instanceNum');
	my $appInstance = $self->appInstance;
	# get the IP address and the netmask for the www host
	my $wwwHostname = $self->getParamValue('wwwHostname');
	$logger->debug("Configuring keepalived for host ", $self->host->hostName, ", wwwHostname = " , $wwwHostname);
	my $wwwIpAddrsRef;
	if ( !( $appInstance->has_wwwIpAddrs ) ) {
		$wwwIpAddrsRef = getIpAddresses($wwwHostname);
		$appInstance->wwwIpAddrs($wwwIpAddrsRef);
	}
	else {
		$wwwIpAddrsRef = $appInstance->wwwIpAddrs;
	}

	my $ipAddr = Utils::getIpAddress($server);
	my $mask;
	my $nicName;

	open my $ifConfigIn, "$sshConnectString ifconfig |"
	  or die "Can't fork read ifconfig from $server : $!";
	while ( my $inline = <$ifConfigIn> ) {
		if ( $inline =~ /$ipAddr.*mask\s+(\d+)\.(\d+)\.(\d+)\.(\d+)/ ) {
			$mask = netmaskHexToBits($1) + netmaskHexToBits($2) + netmaskHexToBits($3) + netmaskHexToBits($4);
			last;
		}
		elsif ( $inline =~ /$ipAddr.*Mask:(\d+)\.(\d+)\.(\d+)\.(\d+)/ ) {
			$mask = netmaskHexToBits($1) + netmaskHexToBits($2) + netmaskHexToBits($3) + netmaskHexToBits($4);
			last;
		}
		elsif ( $inline =~ /^(eth\d+)\s/ ) {
			$nicName = $1;
		} elsif ( $inline =~ /^(eno\d+):/ ) {
			$nicName = $1;
		}
	}
	close $ifConfigIn;

	# Write a config file with one vrrp server instance for each virtual
	# IP address associated with the www hostname.
	# This node is the master for only 1 IP
	my $numVIPs = $#{$wwwIpAddrsRef} + 1;
	
	open( FILEOUT, ">/tmp/keepalived$suffix.conf" ) or die "Error opening file /tmp/keepalived$suffix.conf: $!";
	for ( my $vrrpNum = 0 ; $vrrpNum < $numVIPs ; $vrrpNum++ ) {
		my $vrrpInstNum = $vrrpNum + 1;
		print FILEOUT "vrrp_instance VI_$vrrpInstNum {\n";

		if ( ( $vrrpNum % $numIpManagers ) == ( $instanceNum - 1 ) ) {
			print FILEOUT "    state MASTER\n";
			print FILEOUT "    priority " . $self->masterPriority . "\n";
		}
		else {
			print FILEOUT "    state BACKUP\n";
			print FILEOUT "    priority " . $self->backupPriority . "\n";
		}
		print FILEOUT "    interface $nicName\n";

		print FILEOUT "    virtual_router_id $vrrpInstNum\n";
		print FILEOUT "    virtual_ipaddress {\n";
		print FILEOUT "    " . $wwwIpAddrsRef->[$vrrpNum] . "/" . $mask . "\n";
		print FILEOUT "    }\n";
		print FILEOUT "}\n";

	}

	close FILEOUT;

	`$scpConnectString /tmp/keepalived$suffix.conf root\@$scpHostString:$keepalivedServerRoot/keepalived.conf`;
}

sub stopStatsCollection {
	my ($self) = @_;

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

	# keepalived logs in /var/log/messages
	#	my $scpConnectString = $self->host->scpConnectString;
	#	my $scpHostString = $self->host->scpHostString;
	#	my $out      = `$scpConnectString root\@$scpHostString:/var/log/keepalived.log $destinationPath/.`;

}

sub cleanLogFiles {
	my ($self) = @_;

	#	my $sshConnectString = $self->host->sshConnectString;
	#	my $out              = `$sshConnectString \"rm /var/log/keepalived.log 2>&1\"`;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString     = $self->host->scpConnectString;
	my $scpHostString        = $self->host->scpHostString;
	my $keepalivedServerRoot = $self->getParamValue('keepalivedServerRoot');
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:$keepalivedServerRoot/keepalived.conf $destinationPath/.`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

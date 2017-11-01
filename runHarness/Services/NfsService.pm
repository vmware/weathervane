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
package NfsService;

use Moose;
use MooseX::Storage;
use Log::Log4perl qw(get_logger);

use Services::Service;
use Parameters qw(getParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'Network File System', );

has '+version' => ( default => 'xx', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ( $self, $numFileServers ) = @_;

	super();

};

sub stop {
	my ( $self, $logPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $serviceName = $self->getParamValue('nfsServiceName');
	my $logger = get_logger("Weathervane::Services::NfsService");
	$logger->debug("stop NfsService");

	my $hostname = $self->host->hostName;
	my $logName  = "$logPath/StopNfs-$hostname.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Want to unmount all NFS filesystems that are exported by this
	# service before we stop NFS.  Start by getting /etc/exports and
	# finding the names of the exported filesystems
	`$scpConnectString root\@$scpHostString:/etc/exports /tmp/exports-$hostname`;
	open( FILEIN, "/tmp/exports-$hostname" ) or die "Can't open file /tmp/exports-$hostname copied from $hostname: $!";
	my @exports = ();
	while ( my $inline = <FILEIN> ) {
		$inline =~ /^\s*([a-zA-Z\_\/]+)\s/;
		push @exports, $1;
	}
	close FILEIN;

	print $applog $self->meta->name . " In NfsService::stop.  $hostname exports @exports\n";

	# Unmount on all web and app servers
	my $webServersRef  =  $self->appInstance->getActiveServicesByType('webServer');
	my $appServersRef  = $self->appInstance->getActiveServicesByType('appServer');

	my @servers = ();
	if ( $#$webServersRef >= 0 ) {
		push @servers, @$webServersRef;
	}
	push @servers, @$appServersRef;

	# The dataManager must also mount NFS, unless
	# the datamanager host is the NFS host
	my $dataManager = $self->appInstance->dataManager;
	if (!$self->host->equals($dataManager->host)) {
		push @servers, $dataManager;
	}
	
	foreach my $server (@servers) {
		my $serverHostname   = $server->host->hostName;
		my $sshConnectString = $server->host->sshConnectString;
		$scpConnectString = $server->host->scpConnectString;
		$scpHostString    = $server->host->scpHostString;

		# get fstab to find the mount point of the exports
		`$scpConnectString root\@$scpHostString:/etc/fstab /tmp/fstab-$serverHostname.in`;
		open( FILEIN,  "/tmp/fstab-$serverHostname.in" ) or die "Can't open file /tmp/fstab-$serverHostname.in copied from $serverHostname: $!";
		open( FILEOUT, ">/tmp/fstab-$serverHostname" )   or die "Can't open file /tmp/fstab-$serverHostname: $!";

		my @imports = ();
		while ( my $inline = <FILEIN> ) {
			if ( $inline =~ /[^#]\S*:(\S+)\s+(\S+)\s+nfs/ ) {
				if ( $1 ~~@exports ) {
					print $applog $self->meta->name . " In NfsService::stop.  $serverHostname imports $1 at $2\n";
					push @imports, $2;
					next;
				}
			}
			print FILEOUT $inline;
		}
		close FILEIN;
		close FILEOUT;
		`$scpConnectString /tmp/fstab-$serverHostname root\@$scpHostString:/etc/fstab`;

		foreach my $import (@imports) {
			my $out = `$sshConnectString umount $import 2>&1`;
			print $applog $out;
		}
	}

	# Now restart NFS
	# We don't really stop it because that can mess up
	# new guest hosts that are powered on for the next run
	print $applog "Checking whether NFS is already up on $hostname\n";
	my $sshConnectString = $self->host->sshConnectString;

	if ( $self->isRunning($applog) ) {

		# The server is running
		print $applog "Restarting NFS on $hostname\n";
		print $applog "$sshConnectString service $serviceName restart\n";
		my $out = `$sshConnectString service $serviceName restart 2>&1`;
		print $applog "$out\n";

	}

	close $applog;

}

sub start {
	my ( $self, $logPath ) = @_;
	my $console_logger = get_logger("Console");

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartNfs-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	my $configDir        = $self->getParamValue('configDir');
	my $serviceName = $self->getParamValue('nfsServiceName');
	my $out;
	
	$self->portMap->{"nfs"} = $self->internalPortMap->{"nfs"};
	$self->registerPortsWithHost();
	
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	# Check whether nfs is up
	print $applog "Checking whether NFS is already up on $hostname\n";
	if ( $self->isRunning($applog) ) {

		# The server is not running
		print $applog "Starting NFS on $hostname\n";
		print $applog "$sshConnectString service $serviceName start\n";
		$out = `$sshConnectString service $serviceName start 2>&1`;
		print $applog "$out\n";
	}
	else {

		# even if it is up, restart it
		print $applog "Restarting NFS on $hostname\n";
		print $applog "$sshConnectString service $serviceName restart\n";
		$out = `$sshConnectString service $serviceName restart 2>&1`;
		print $applog "$out\n";
	}
	
	# We really need NFS to be up before proceeding, so test
	# here as well as normal isUp path
	my $isUp = 0;
	for (my $i = 0; $i < $self->getParamValue('isUpRetries'); $i++) {
		sleep 5;	
		$isUp = $self->isUp($applog);
		if ($isUp) {
			last;
		}
	}
	if ( !$isUp ) {
		$console_logger->error("Can't start NFS on $hostname : $out");
		return;
	}
	
	# For each web, app, and primary driver, edit /etc/fstab
	# to remove all mounts from this host.  Then add proper mounts.
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	`$scpConnectString root\@$scpHostString:/etc/exports /tmp/exports-$hostname`;
	open( FILEIN, "/tmp/exports-$hostname" ) or die "Can't open file /tmp/exports-$hostname copied from $hostname: $!";
	my @exports = ();
	while ( my $inline = <FILEIN> ) {
		$inline =~ /^\s*([a-zA-Z\_\/]+)\s/;
		push @exports, $1;
	}
	close FILEIN;

	my $webServersRef  =  $self->appInstance->getActiveServicesByType('webServer');
	my $appServersRef  = $self->appInstance->getActiveServicesByType('appServer');
	my @servers = ();
	
	foreach my $server (@$webServersRef) {
		if (!$self->host->equals($server->host)) {
			push @servers, $server;
		}
	}
	foreach my $server (@$appServersRef) {
		if (!$self->host->equals($server->host)) {
			push @servers, $server;
		}		
	}
	# The dataManager must also mount NFS, unless
	# the datamanager host is the NFS host
	my $dataManager = $self->appInstance->dataManager;
	if (!$self->host->equals($dataManager->host)) {
		push @servers, $dataManager;
	}
	
	my $nfsHostname = $self->host->hostName;
	foreach my $server (@servers) {
		$scpConnectString = $server->host->scpConnectString;
		$scpHostString    = $server->host->scpHostString;
		my $serverHostName = $server->host->hostName;

		`$scpConnectString root\@$scpHostString:/etc/fstab /tmp/fstab-$serverHostName.in`;
		open( FILEIN, "/tmp/fstab-$serverHostName.in" ) or die "Can't open file /tmp/fstab-$serverHostName.in: $!";
		open( FILEOUT, ">/tmp/fstab-$serverHostName" ) or die "Can't open file /tmp/fstab-$serverHostName: $!";

		# Remove all old lines from fstab for the mounts from this service
		while ( my $inline = <FILEIN> ) {
			if ( !( $inline =~ /[^#]\S*:(\S+)\s+(\S+)\s+nfs/ ) ) {

				# Not a line mounting an nfs mount
				print FILEOUT $inline;
			}
			else {
				if ( !( $1 ~~ @exports ) ) {

					# Not mounting one of the exports
					print FILEOUT $inline;
				}
			}
		}
		close FILEIN;
		foreach my $export (@exports) {
			my $rsize = $self->getParamValue('nfsRsize');
			my $wsize = $self->getParamValue('nfsWsize');
			my $async = "sync";
			if ( $self->getParamValue('nfsClientAsync') ) {
				$async = "async";
			}
			print FILEOUT "$nfsHostname:$export $export nfs rsize=$rsize,wsize=$wsize,$async,noatime,nodiratime,actimeo=120\n";
		}
		close FILEOUT;
		
		print $applog "$scpConnectString /tmp/fstab-$serverHostName root\@$scpHostString:/etc/fstab\n";
		$out = `$scpConnectString /tmp/fstab-$serverHostName root\@$scpHostString:/etc/fstab`;
		print $applog "$out\n";
	}
	

	## Make sure NFS is mounted on all of the services that need it,
	# which means all web servers, if any, all app servers,
	# and the primary workload driver
	foreach my $server (@servers) {
		$sshConnectString = $server->host->sshConnectString;

		print $applog "$sshConnectString mount -a\n";
		$out = `$sshConnectString mount -a`;
		print $applog "$out\n";
	}
	
	$self->host->startNscd();

	close $applog;

}

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $hostname    = $self->host->hostName;
	my $logName     = "$logPath/NFS-clearData-$hostname.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";

	my $sshConnectString = $self->host->sshConnectString;
	print $applog "Clearing old NFS data on " . $hostname . "\n";

	my $imageStoreDataDir = $self->getParamValue('imageStoreDir');
	print $applog "Clearing the old filesystem contents on " . $hostname . "\n";
	my $cmdout = `$sshConnectString \"find $imageStoreDataDir/* -delete 2>&1\"`;
	print $applog $cmdout;

	close $applog;

}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	
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
	my $serviceName = $self->getParamValue('nfsServiceName');

	my $out = `$sshConnectString service $serviceName status 2>&1`;
	print $fileout $out;
	if ( $out =~ /Active:\s+active/ ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub setPortNumbers {
	my ( $self ) = @_;
	
	$self->internalPortMap->{"nfs"} = 2049;
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	
	$self->portMap->{"nfs"} = $self->internalPortMap->{"nfs"};
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;

	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');

	open( EXPORTSFILEIN,  "$configDir/nfs/exports" ) or die "Can't open file $configDir/nfs/exports: $!";
	open( EXPORTSFILEOUT, ">/tmp/exports$suffix" )          or die "Can't open file /tmp/exports$suffix : $!";
	my @exports = ();
	while ( my $inline = <EXPORTSFILEIN> ) {
		$inline =~ /^\s*([a-zA-Z\_\/]+)\s/;
		my $async = "sync";
		if ( $self->getParamValue('nfsServerAsync') ) {
			$async = "async";
		}
		print EXPORTSFILEOUT "$1 *(rw,no_root_squash,$async)\n";

		push @exports, $1;

	}
	close EXPORTSFILEOUT;
	close EXPORTSFILEIN;
	`$scpConnectString /tmp/exports$suffix root\@$scpHostString:/etc/exports`;

	#	print $self->meta->name . " In NfsService::configure.  $hostname exports @exports\n";

	# Edit the number of processes in /etc/sysconfig/nfs
	open( FILEIN,  "$configDir/nfs/nfs" ) or die "Can't open file $configDir/nfs/nfs: $!";
	open( FILEOUT, ">/tmp/nfs$suffix" )          or die "Can't open file /tmp/nfs$suffix: $!";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /RPCNFSDCOUNT/ ) {
			my $numProc = $self->getParamValue('nfsProcessCount');
			print FILEOUT "RPCNFSDCOUNT=$numProc\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEOUT;
	close FILEIN;
	`$scpConnectString /tmp/nfs$suffix root\@$scpHostString:/etc/sysconfig/nfs`;
	
}

sub stopStatsCollection {
	my ($self)           = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString \"nfsstat -s > /tmp/nfsstat-s_end_$hostname.txt\"`;

	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	foreach my $webServer (@$webServersRef) {
		my $webHostname = $webServer->host->hostName;
		$sshConnectString = $webServer->host->sshConnectString;
		$out              = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_end_$webHostname.txt\"`;
		$out              = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_end_$webHostname.txt\"`;
	}
	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $appServer->host->hostName;
		$sshConnectString = $appServer->host->sshConnectString;
		$out              = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_end_$appHostname.txt\"`;
		$out              = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_end_$appHostname.txt\"`;
	}
	my $wkldHostname = $self->appInstance->dataManager->host->hostName;
	$sshConnectString = $self->appInstance->dataManager->host->sshConnectString;
	$out              = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_end_$wkldHostname.txt\"`;
	$out              = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_end_$wkldHostname.txt\"`;
}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString \"nfsstat -s > /tmp/nfsstat-s_start_$hostname.txt\"`;

	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	foreach my $webServer (@$webServersRef) {
		my $webHostname = $webServer->host->hostName;
		$sshConnectString = $webServer->host->sshConnectString;

		$out = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_start_$webHostname.txt\"`;
		$out = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_start_$webHostname.txt\"`;
	}
	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $appServer->host->hostName;
		$sshConnectString = $appServer->host->sshConnectString;

		$out = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_start_$appHostname.txt\"`;
		$out = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_start_$appHostname.txt\"`;
	}

	my $wkldHostname = $self->appInstance->dataManager->host->hostName;
	$sshConnectString = $self->appInstance->dataManager->host->sshConnectString;
	$out              = `$sshConnectString \"nfsstat -c > /tmp/nfsstat-c_start_$wkldHostname.txt\"`;
	$out              = `$sshConnectString \"nfsstat -m > /tmp/nfsstat-m_start_$wkldHostname.txt\"`;
}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;

	my $out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-s_start_$hostname.txt $destinationPath/. 2>&1`;
	$out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-s_end_$hostname.txt $destinationPath/. 2>&1`;

	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	foreach my $webServer (@$webServersRef) {
		my $webHostname = $webServer->host->hostName;
		$scpConnectString = $webServer->host->scpConnectString;
		$scpHostString    = $webServer->host->scpHostString;

		$out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_start_$webHostname.txt $destinationPath/. 2>&1`;
		$out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_end_$webHostname.txt $destinationPath/. 2>&1`;
		$out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_start_$webHostname.txt $destinationPath/. 2>&1`;
		$out = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_end_$webHostname.txt $destinationPath/. 2>&1`;
	}
	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $appServer->host->hostName;
		$scpConnectString = $appServer->host->scpConnectString;
		$scpHostString    = $appServer->host->scpHostString;
		$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_start_$appHostname.txt $destinationPath/. 2>&1`;
		$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_end_$appHostname.txt $destinationPath/. 2>&1`;
		$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_start_$appHostname.txt $destinationPath/. 2>&1`;
		$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_end_$appHostname.txt $destinationPath/. 2>&1`;
	}
	my $wkldHostname = $self->appInstance->dataManager->host->hostName;
	$scpConnectString = $self->appInstance->dataManager->host->scpConnectString;
	$scpHostString    = $self->appInstance->dataManager->host->scpHostString;
	$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_start_$wkldHostname.txt $destinationPath/. 2>&1`;
	$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-c_end_$wkldHostname.txt $destinationPath/. 2>&1`;
	$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_start_$wkldHostname.txt $destinationPath/. 2>&1`;
	$out              = `$scpConnectString root\@$scpHostString:/tmp/nfsstat-m_end_$wkldHostname.txt $destinationPath/. 2>&1`;
}

sub cleanStatsFiles {
	my ($self)           = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $out              = `$sshConnectString \"rm tmp/nfsstat-s_start_$hostname.txt 2>&1\" `;
	$out = `$sshConnectString \"rm /tmp/nfsstat-s_end_$hostname.txt 2>&1\"`;

	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	foreach my $webServer (@$webServersRef) {
		my $webHostname = $webServer->host->hostName;
		$sshConnectString = $webServer->host->sshConnectString;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-c_start_$webHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-c_end_$webHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-m_start_$webHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-m_end_$webHostname.txt 2>&1\"`;
	}
	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		my $appHostname = $appServer->host->hostName;
		$sshConnectString = $appServer->host->sshConnectString;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-c_start_$appHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-c_end_$appHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-m_start_$appHostname.txt 2>&1\"`;
		$out              = `$sshConnectString \"rm /tmp/nfsstat-m_end_$appHostname.txt 2>&1\"`;
	}
	my $wkldHostname = $self->appInstance->dataManager->host->hostName;
	$sshConnectString = $self->appInstance->dataManager->host->sshConnectString;
	$out              = `$sshConnectString \"rm /tmp/nfsstat-c_start_$wkldHostname.txt 2>&1\"`;
	$out              = `$sshConnectString \"rm /tmp/nfsstat-c_end_$wkldHostname.txt 2>&1\"`;
	$out              = `$sshConnectString \"rm /tmp/nfsstat-m_start_$wkldHostname.txt 2>&1\"`;
	$out              = `$sshConnectString \"rm /tmp/nfsstat-m_end_$wkldHostname.txt 2>&1\"`;
}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

}

sub cleanLogFiles {
	my ($self) = @_;

}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	`mkdir -p $destinationPath`;

	`$scpConnectString root\@$scpHostString:/etc/exports $destinationPath/.`;
	`$scpConnectString root\@$scpHostString:/etc/sysconfig/nfs $destinationPath/.`;

	# For each web, app, and primary driver, edit /etc/fstab
	# to remove all mounts from this host.  Then add proper mounts.
	my $webServersRef  = $self->appInstance->getActiveServicesByType('webServer');
	foreach my $webServer (@$webServersRef) {
		$scpConnectString = $webServer->host->scpConnectString;
		$scpHostString    = $webServer->host->scpHostString;
		my $webHostname = $webServer->host->hostName;
		`$scpConnectString root\@$scpHostString:/etc/fstab $destinationPath/fstab_$webHostname`;
	}
	my $appServersRef = $self->appInstance->getActiveServicesByType('appServer');
	foreach my $appServer (@$appServersRef) {
		$scpConnectString = $appServer->host->scpConnectString;
		$scpHostString    = $appServer->host->scpHostString;
		my $appHostname = $appServer->host->hostName;
		`$scpConnectString root\@$scpHostString:/etc/fstab $destinationPath/fstab_$appHostname`;
	}
	my $wkldHostname = $self->appInstance->dataManager->host->hostName;
	$scpConnectString = $self->appInstance->dataManager->host->scpConnectString;
	$scpHostString    = $self->appInstance->dataManager->host->scpHostString;
	`$scpConnectString root\@$scpHostString:/etc/fstab $destinationPath/fstab_$wkldHostname`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"nfsProcessCount"} = $self->getParamValue('nfsProcessCount');
	$csv{"nfsRsize"}        = $self->getParamValue('nfsRsize');
	$csv{"nfsWsize"}        = $self->getParamValue('nfsWsize');
	$csv{"nfsServerAsync"}  = $self->getParamValue('nfsServerAsync');
	$csv{"nfsClientAsync"}  = $self->getParamValue('nfsClientAsync');
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

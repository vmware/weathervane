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
package Workload;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);
use Instance;
use Utils qw(callMethodOnObjectsParallel callMethodsOnObjectParallel callBooleanMethodOnObjectsParallel1
  callBooleanMethodOnObjectsParallel2 callMethodOnObjectsParallel1 callMethodOnObjectsParallel2
  callMethodsOnObject1 callMethodOnObjects1);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'Instance';

has 'primaryDriver' => (
	is  => 'rw',
	isa => 'WorkloadDriver',
);

has 'appInstancesRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef',
);

has 'suffix' => (
	is  => 'rw',
	isa => 'Str',
);

override 'initialize' => sub {
	my ($self) = @_;

	$self->suffix( "-W" . $self->instanceNum );

	super();
	
};

sub setPrimaryDriver {
	my ( $self, $primaryDriver ) = @_;
	$self->primaryDriver($primaryDriver);
}

sub setAppInstances {
	my ( $self, $applicationsRef ) = @_;
	$self->appInstancesRef($applicationsRef);
}

sub killOldWorkloadDrivers {
	my ($self, $setupLogDir) = @_;

	$self->primaryDriver->killOld($setupLogDir);

}

sub sanityCheckServices {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'sanityCheckServices', $self->appInstancesRef, $cleanupLogDir );
}

sub cleanupAppInstances {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'cleanup', $self->appInstancesRef, $cleanupLogDir );
}

sub cleanData {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'cleanData', $self->appInstancesRef, $cleanupLogDir );
}

sub prepareData {
	my ( $self, $setupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'prepareData', $self->appInstancesRef, $setupLogDir );
}

sub prepareDataServices {
	my ( $self, $setupLogDir ) = @_;
	# If the driver is running on Kubernetes clusters, then
	# we can do the prepare in parallel
	# If all of the dataManagers are running on Kubernetes clusters, then
	# we can do the prepare in parallel
	my $allK8s = 1;
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstanceRef (@{$appInstancesRef}) {
		my $dataManager = $appInstanceRef->dataManager;
		if ((ref $dataManager->host) ne 'KubernetesCluster') {
			$allK8s = 0;
		}
	}
	if ($allK8s) {
		callMethodOnObjectsParallel1( 'prepareDataServices', $self->appInstancesRef, $setupLogDir );		
	} else {
		callMethodOnObjects1( 'prepareDataServices', $self->appInstancesRef, $setupLogDir );		
	}
}

sub clearReloadDb {
	my ($self) = @_;
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->clearReloadDb();
	}
}

sub clearResults {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	$logger->debug("clearResults");
	return $self->primaryDriver->clearResults();
}

sub initializeRun {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	$logger->debug("initialize: seqnum = $seqnum, tmpDir = $tmpDir");
	return $self->primaryDriver->initializeRun( $seqnum, $tmpDir, $self->suffix, $tmpDir );
}

sub startRun {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	$logger->debug("run: seqnum = $seqnum, tmpDir = $tmpDir");
	return $self->primaryDriver->startRun( $seqnum, $tmpDir, $self->suffix, $tmpDir );
}

sub stopRun {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	$logger->debug("stop: seqnum = $seqnum, tmpDir = $tmpDir");
	return $self->primaryDriver->stopRun( $seqnum, $tmpDir, $self->suffix );
}

# We have found the maximum if all appInstances have hit a maximum
sub foundMax {
	my ($self)   = @_;
	
	my $foundMax = 1;

	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$foundMax &= $appInstance->foundMax();
	}

	return $foundMax;
}

sub printFindMaxResult {
	my ($self)   = @_;
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->printFindMaxResult();
	}
}

sub adjustUsersForFindMax {
	my ($self)         = @_;
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->adjustUsersForFindMax();
	}
}

sub resetFindMax {
	my ($self) = @_;
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->resetFindMax();
	}
}

sub getFindMaxInfoString {
	my ($self) = @_;
	my $returnString = "";
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$returnString .= $appInstance->getFindMaxInfoString();
	}
	
	return $returnString;
}

sub setPortNumbers {
	my ( $self ) = @_;
	
	$self->primaryDriver->setPortNumbers();
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->setPortNumbers();
	}
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	$self->primaryDriver->setExternalPortNumbers();
	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->setExternalPortNumbers();
	}
}

sub isUp {
	my ( $self, $logDir ) = @_;

	my $retries = $self->getParamValue('isUpRetries');
	my $allUp   = 0;
	do {
		sleep 30;
		$retries--;
		$allUp = callBooleanMethodOnObjectsParallel2( 'isUp', $self->appInstancesRef, $retries, $logDir );
	} while ( ( $retries > 0 ) && !$allUp );

	return $allUp;

}


sub isDriverUp {
	my ( $self ) = @_;

	return $self->primaryDriver->isUp();

}

sub isDriverStarted {
	my ( $self ) = @_;

	return $self->primaryDriver->isStarted();

}

sub isPassed {
	my ( $self, $tmpDir ) = @_;
	my $console_logger    = get_logger("Console");
	my $logger = get_logger("Weathervane::Workload::Workload");

	my $workloadNum = $self->instanceNum;
	
	my $passed = 1;
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstanceRef (@$appInstancesRef) {
		$logger->debug("Calling isPassed with appInstanceRef for appInstanceNum " . $appInstanceRef->instanceNum);
		
		my $aiPassed = $self->primaryDriver->isPassed($appInstanceRef, $tmpDir); 
		$passed &= $aiPassed;
		
		$appInstanceRef->passedLast($passed);
		
		my $appInstanceNum = $appInstanceRef->instanceNum;
		my $resultString = "failed";
		if ($aiPassed) {
			$resultString = "passed";
		} 
		$console_logger->info("Workload $workloadNum AppInstance $appInstanceNum $resultString.");	
	}

	return $passed;
}

sub setLoadPathType {
	my ( $self, $loadPathType ) = @_;
	my $logger         = get_logger("Weathervane::Workload::Workload");
	$logger->debug("setLoadPathType for all appInstances to $loadPathType");

	my $appInstanceRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstanceRef) {
		$appInstance->setLoadPathType($loadPathType);
	}
}

sub startServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	# If all of the dataManagers are running on Kubernetes clusters, then
	# we can do the start in parallel
	my $allK8s = 1;
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstanceRef (@{$appInstancesRef}) {
		my $dataManager = $appInstanceRef->dataManager;
		if ((ref $dataManager->host) ne 'KubernetesCluster') {
			$allK8s = 0;
		}
	}
	if ($allK8s) {
		callMethodOnObjectsParallel2( 'startServices', $appInstancesRef, $serviceTier, $setupLogDir );
	} else {
		foreach my $appInstance (@$appInstancesRef) {
			$appInstance->startServices($serviceTier, $setupLogDir);
		}
	}
}

sub stopServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $appInstanceRef = $self->appInstancesRef;
	
	callMethodOnObjectsParallel2( 'stopServices', $self->appInstancesRef, $serviceTier, $setupLogDir );
	
}

sub stopDataManager {
	my ( $self, $setupLogDir ) = @_;
	my $logger         = get_logger("Weathervane::Workload::Workload");
	$logger->debug("stopDataManager with logDir $setupLogDir");
	
	callMethodOnObjectsParallel1( 'stopDataManager', $self->appInstancesRef, $setupLogDir );
}

sub removeServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger         = get_logger("Weathervane::Workload::Workload");
	$logger->debug("removing $serviceTier services with log dir $setupLogDir");
	
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		$appInstance->removeServices($serviceTier, $setupLogDir);
	}
}

sub clearDataServicesBeforeStart {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'clearDataServicesBeforeStart', $self->appInstancesRef, $setupLogDir );
}

sub clearDataServicesAfterStart {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'clearDataServicesAfterStart', $self->appInstancesRef, $setupLogDir );
}

sub configureWorkloadDriver {
	my ($self, $tmpDir) = @_;
	my $workloadDriver = $self->primaryDriver;

	$workloadDriver->configure( $self->appInstancesRef, $self->suffix, $tmpDir );
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $pid;
	my @pids;

	my $workloadDriver = $self->primaryDriver;
	my $logLevel       = $self->getParamValue('logLevel');

	$logger->debug(": CleanStatsFiles\n");

	# clean application-level stats from workload driver
	$pid = fork();
	if ( !defined $pid ) {
		$logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		$workloadDriver->cleanAppStatsFiles();
		exit;
	}
	else {
		push @pids, $pid;
	}

	if ( $logLevel >= 3 ) {

		# Start stops collection on workload driver
		$logger->debug(": CleanStatsFiles for workload drivers\n");
		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$workloadDriver->cleanStatsFiles();
			exit;
		}
		else {
			push @pids, $pid;
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	my $pid;
	my @pids;
	$logger->debug(": CleanLogFiles\n");

	my $workloadDriver = $self->primaryDriver;

	# clean log files on workload driver
	$pid = fork();
	if ( !defined $pid ) {
		$logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		$logger->debug(": CleanLogFiles for workload drivers\n");
		$workloadDriver->cleanLogFiles();
		exit;
	}
	else {
		push @pids, $pid;
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub startStatsCollection {
	my ($self, $tmpDir)            = @_;
	my $console_logger    = get_logger("Console");
	my $workloadDriver    = $self->primaryDriver;
	my $intervalLengthSec = $self->getParamValue('statsInterval');
	my $steadyStateLength = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $numIntervals = floor( $steadyStateLength / ( $intervalLengthSec * 1.0 ) );
	my $logLevel = $self->getParamValue('logLevel');

	# Get application-level stats from workload driver
	$workloadDriver->startAppStatsCollection( $intervalLengthSec, $numIntervals );

	if ( $logLevel >= 3 ) {
		callMethodOnObjectsParallel1( 'startStatsCollection', $self->appInstancesRef, $tmpDir );

		# Start starts collection on workload driver
		$workloadDriver->startStatsCollection( $intervalLengthSec, $numIntervals );

	}
}

sub stopStatsCollection {
	my ($self)         = @_;
	my $logger = get_logger("Weathervane::Workload::Workload");
	$logger->debug("stopStatsCollection for workload " .  $self->instanceNum  );
	my $workloadDriver = $self->primaryDriver;

	# stop application-level stats from workload driver
	$workloadDriver->stopAppStatsCollection();

	if ( $self->getParamValue('logLevel') >= 3 ) {

		callMethodOnObjectsParallel( 'stopStatsCollection', $self->appInstancesRef );

		# Start stats collection on workload driver
		$workloadDriver->stopStatsCollection();
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $fullFilePath = $self->getParamValue('fullFilePath');

	my $workloadDriver         = $self->primaryDriver;
	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/workload" . $self->instanceNum;
	}

	my $destinationPath = $newBaseDestinationPath . "/application";
	if ( !( -e $destinationPath ) ) {
		`mkdir -p $destinationPath`;
	}
	$workloadDriver->getAppStatsFiles($destinationPath);

	if ( $self->getParamValue('logLevel') >= 3 ) {

		if ( ( $#{ $self->appInstancesRef } > 0 ) || ($fullFilePath) ) {
			$usePrefix = 1;
		}
		else {
			$usePrefix = 0;
		}
		callMethodOnObjectsParallel2( 'getStatsFiles', $self->appInstancesRef, $newBaseDestinationPath, $usePrefix );

		$destinationPath = $newBaseDestinationPath . "/workloadDriver";
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$workloadDriver->getStatsFiles($destinationPath);

	}

}

sub getLogFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $pid;
	my @pids;
	my $console_logger = get_logger("Console");
	my $fullFilePath   = $self->getParamValue('fullFilePath');

	my $workloadDriver         = $self->primaryDriver;
	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/workload" . $self->instanceNum;
	}

	#  collection on services
	$pid = fork();
	if ( !defined $pid ) {
		$console_logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		if ( ( $#{ $self->appInstancesRef } > 0 ) || ($fullFilePath) ) {
			$usePrefix = 1;
		}
		else {
			$usePrefix = 0;
		}
		callMethodOnObjectsParallel2( 'getLogFiles', $self->appInstancesRef, $newBaseDestinationPath, $usePrefix );
		exit;
	}
	else {
		push @pids, $pid;
	}

	$pid = fork();
	if ( !defined $pid ) {
		$console_logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		my $destinationPath = $newBaseDestinationPath . "/workloadDriver/" . $workloadDriver->host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$workloadDriver->getLogFiles($destinationPath);
		exit;
	}
	else {
		push @pids, $pid;
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub getConfigFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $pid;
	my @pids;
	my $console_logger = get_logger("Console");
	my $fullFilePath   = $self->getParamValue('fullFilePath');

	my $workloadDriver         = $self->primaryDriver;
	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/workload" . $self->instanceNum;
	}

	#  collection on services
	$pid = fork();
	if ( !defined $pid ) {
		$console_logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {

		if ( ( $#{ $self->appInstancesRef } > 0 ) || ($fullFilePath) ) {
			$usePrefix = 1;
		}
		else {
			$usePrefix = 0;
		}
		callMethodOnObjectsParallel2( 'getConfigFiles', $self->appInstancesRef, $newBaseDestinationPath, $usePrefix );
		exit;
	}
	else {
		push @pids, $pid;
	}

	$pid = fork();
	if ( !defined $pid ) {
		$console_logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		my $destinationPath = $newBaseDestinationPath . "/workloadDriver/" . $workloadDriver->host->name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$workloadDriver->getConfigFiles($destinationPath, $self->suffix);
		exit;
	}
	else {
		push @pids, $pid;
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub redeploy {
	my ( $self, $setupLogDir, $hostsRef ) = @_;
	my $workloadNum = $self->instanceNum;
	my $logName = "$setupLogDir/Redeploy" . $self->suffix . ".log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";
	my $logger = get_logger("Weathervane::Workload::Workload");

	$logger->debug("redeploy for workload $workloadNum: Redeploy on driver");
	$self->primaryDriver->redeploy($applog, $hostsRef);

	$logger->debug("redeploy for workload $workloadNum: Redeploy on appInstances");
	callMethodOnObjectsParallel1( 'redeploy', $self->appInstancesRef, $applog );

	close $applog;
}

sub getWorkloadStatsSummary {
	my ( $self, $tmpDir ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	$csv{'workload'} = $self->getParamValue('workloadImpl');

	$csv{'workloadProfile'} = $self->getParamValue( 'workloadProfile' );

	$self->primaryDriver->getWorkloadStatsSummary( \%csv, $tmpDir );

	return \%csv;
}

sub getWorkloadSummary {
	my ( $self, $tmpDir ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	$self->primaryDriver->getWorkloadSummary( \%csv, $tmpDir );

	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $prefix = "";
		if ( $#{$appInstancesRef} > 0 ) {
			$prefix = "appInstance" . $appInstance->instanceNum . "-";
		}

		$csv{"maxUsers"} = $appInstance->getUsers();

	}

	return \%csv;
}

sub getAppInstanceStatsSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );

	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $prefix = "";
		if ( $#{$appInstancesRef} > 0 ) {
			$prefix = "appInstance" . $appInstance->instanceNum . "-";
		}

		my $impl         = $self->getParamValue('workloadImpl');
		my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
		foreach my $serviceType (@$serviceTypes) {
			my $servicesListRef = $appInstance->getAllServicesByType($serviceType);
			my $numServices     = $appInstance->getTotalNumOfServiceType($serviceType);
			if ( $numServices < 1 ) {

				# Only include services for which there is an instance
				next;
			}
			$csv{ $prefix . $serviceType . "Impl" } = $appInstance->getParamValue( $serviceType . "Impl" );
			$csv{ $prefix . "num" . ucfirst($serviceType) . "s" } = $numServices;
		}

		$csv{ $prefix . "imageStoreType" } = $appInstance->getParamValue("imageStoreType");

		foreach my $serviceType (@$serviceTypes) {
			my $servicesListRef = $appInstance->getAllServicesByType($serviceType);
			my $numServices     = $appInstance->getTotalNumOfServiceType($serviceType);
			if ( $numServices < 1 ) {

				# Only include services for which there is an instance
				next;
			}

			# Only call getConfigSummary on one service of each type.
			my $service   = $servicesListRef->[0];
			my $tmpCsvRef = $service->getConfigSummary();
			@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
		}

	}

	return \%csv;
}

sub getWorkloadAppStatsSummary {
	my ($self, $tmpDir) = @_;
	tie( my %csv, 'Tie::IxHash' );

	return $self->primaryDriver->getWorkloadAppStatsSummary($tmpDir);

}

sub getHostStatsSummary {
	my ( $self, $statsLogPath, $basePrefix ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	# First get the host stats for the workload driver hosts
	$self->primaryDriver->getHostStatsSummary( \%csv, $statsLogPath, $basePrefix );

	# Get the host stats by service type for each app instance
	my $prefix          = "";
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		if ( $#{$appInstancesRef} > 0 ) {
			$prefix = $basePrefix . "appInstance" . $appInstance->instanceNum . "-";
		}

		$appInstance->getHostStatsSummary( \%csv, $statsLogPath, $basePrefix, $prefix );

	}

	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $usePrefix, $tmpDir ) = @_;

	tie( my %csv, 'Tie::IxHash' );
	my $newBaseDestinationPath = $statsLogPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/workload" . $self->instanceNum;
	}

	# First get the stats for the workload driver
	$self->primaryDriver->getStatsSummary( \%csv, $newBaseDestinationPath . "/workloadDriver", $tmpDir );

	# Get the host stats by service type for each app instance
	my $appInstancesRef = $self->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $prefix = "";
		my $subDir = "";
		if ( $#{$appInstancesRef} > 0 ) {
			$prefix = "appInstance" . $appInstance->instanceNum . "-";
			$subDir = "/appInstance" . $appInstance->instanceNum;
		}

		$appInstance->getStatsSummary( \%csv, $prefix, $newBaseDestinationPath . $subDir );

	}

	return \%csv;
}

sub getNextRunInfo {
	my ($self) = @_;

	my $returnString    = "";
	my $appInstancesRef = $self->appInstancesRef;
	if ( $#{$appInstancesRef} > 0 ) {
		$returnString .= "\n";
	}

	foreach my $appInstance (@$appInstancesRef) {
		my $prefix = "";
		if ( $#{$appInstancesRef} > 0 ) {
			$prefix = "\tAppInstance " . $appInstance->instanceNum;
		}
		$returnString .= $prefix . ", users = " . $appInstance->users . "\n";
	}

	return $returnString;
}

sub getMinUsers {
	my ($self) = @_;
	my $minUsers = 9999999999;
	my $appInstancesRef = $self->appInstancesRef;

	foreach my $appInstance (@$appInstancesRef) {
		my $users = $appInstance->users;
		if ($users < $minUsers) {
			$minUsers = $users;
		}
	}
	
	return $minUsers;
}

sub setNumActiveUsers {
	my ( $self, $appInstanceName, $numUsers ) = @_;

	return $self->primaryDriver->setNumActiveUsers($appInstanceName, $numUsers);

}


sub getNumActiveUsers {
	my ($self) = @_;

	return $self->primaryDriver->getNumActiveUsers();

}


sub writeUsersTxt {
	my ($self, $fileOut) = @_;
	my $console_logger = get_logger("Console");
	my $appInstancesRef = $self->appInstancesRef;

	my $workloadNum = $self->instanceNum;
	
	foreach my $appInstance (@$appInstancesRef) {
		my $instanceNum = $appInstance->instanceNum;
		my $loadPathType = $appInstance->getParamValue('loadPathType');
		if ($loadPathType eq 'fixed') {
			my $users = $appInstance->users;
			if ($users) {
				my $outString      = "Workload $workloadNum, App Instance $instanceNum: $users Users";
				$console_logger->info($outString);
				print $fileOut "$outString\n";
			}
		} elsif ($loadPathType eq 'findMax') {
				my $outString      = "Workload $workloadNum, App Instance $instanceNum: FindMax";
				$console_logger->info($outString);
				print $fileOut "$outString\n";			
		}
	}
}


sub checkUsersTxt {
	my ($self, $inline) = @_;	
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Workload::Workload");
	my $appInstancesRef = $self->appInstancesRef;
	my $isCorrect = 1;

	$inline =~ /Workload\s(\d+),\sApp\sInstance\s(\d+):\s(\d+)\sUsers/;
	
	my $workloadNum = $self->instanceNum;
	if ($workloadNum != $1)	{
		$console_logger->info("Workload number $1 from the prepareOnly phase doesn't match workload number $workloadNum");
		return 0;
	}
	
	if (($#$appInstancesRef + 1) < $2) {
		$console_logger->info("The configuration from the prepareOnly phase specifies an appInstance $2 for workload number $workloadNum which doesn't exist in the current configuration.");
		return 0;		
	}
	my $appInstance = $appInstancesRef->[$2 - 1];
	my $instanceNum = $appInstance->instanceNum;
	
	if ($instanceNum != $2)	{
		$console_logger->info("checkUsersTxt: Workload number $workloadNum. Instance number $instanceNum doesn't match input $2");
		return 0;
	}
	
	if ($3 != $appInstance->getUsers()) {
	    $console_logger->info("The number of users (". $appInstance->getUsers() . ") specified for workload $workloadNum, appInstance $instanceNum doesn't match number ($3) from the prepareOnly phase");
		return 0;		
	}
	
	return 1;
}

__PACKAGE__->meta->make_immutable;

1;

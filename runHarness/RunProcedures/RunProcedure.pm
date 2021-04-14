# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RunProcedure;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Tie::IxHash;
#use Term::Screen;
use Log::Log4perl qw(get_logger :levels);
use Utils qw(createDebugLogger callMethodOnObjectsParallel callMethodOnObjectsParallel1 callMethodsOnObjectParallel
  callMethodsOnObjectParallel1 callMethodOnObjectsParallel2 callMethodOnObjectsParallel3
  callBooleanMethodOnObjectsParallel callBooleanMethodOnObjectsParallel1 callBooleanMethodOnObjectsParallel2 callBooleanMethodOnObjectsParallel3
  callMethodOnObjectsParamListParallel1 callMethodOnObjects1 callBooleanMethodOnObjects2);
use Instance;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'Instance';

has 'virtualInfrastructure' => (
	is  => 'rw',
	isa => 'VirtualInfrastructure',
);

has 'hostsRef' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

has 'clustersRef' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

has 'workloadsRef' => (
	is      => 'rw',
	default => sub { [] },
	isa     => 'ArrayRef',
);

has 'origParamHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

has 'description' => (
	is  => 'rw',
	isa => 'Str',
);

has 'seqnum' => (
	is  => 'rw',
	isa => 'Str',
);

has 'tmpDir' => (
	is  => 'rw',
	isa => 'Str',
);

override 'initialize' => sub {
	my ($self) = @_;

	my $logLevel = $self->getParamValue('logLevel');
	if ( ( $logLevel < 0 ) || ( $logLevel > 4 ) ) {
		die "The logLevel must be between 0 and 4";
	}

	super();

};

sub setWorkloads {
	my ( $self, $workloadsRef ) = @_;
	$self->workloadsRef($workloadsRef);
}

sub setHosts {
	my ( $self, $hostsRef ) = @_;
	$self->hostsRef($hostsRef);
}

sub addHost {
	my ( $self, $host ) = @_;
	my $hostsRef = $self->hostsRef;
	push @$hostsRef, $host;
}

sub setClusters {
	my ( $self, $clustersRef ) = @_;
	$self->clustersRef($clustersRef);
}

sub addCluster {
	my ( $self, $cluster ) = @_;
	my $clustersRef = $self->clustersRef;
	push @$clustersRef, $cluster;
}

sub removeHost {
	my ( $self, $host ) = @_;
	my $hostsRef = $self->hostsRef;

	my @tmpList = grep { !$host->equals($_) } @$hostsRef;
	$hostsRef = \@tmpList;

}

sub setVirtualInfrastructure {
	my ( $self, $vi ) = @_;
	$self->virtualInfrastructure($vi);
}

sub getRunProcedureImpl {
	my ($self) = @_;
	my $paramHashRef = $self->paramHashRef;

	return $paramHashRef->{'runProcedure'};
}

sub killOldWorkloadDrivers {
	my ($self, $setupLogDir) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug(": Stopping old workload drivers.");

	callMethodOnObjectsParallel1( 'killOldWorkloadDrivers', $self->workloadsRef, $setupLogDir );
}

sub initializeWorkloads {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug("initializeWorkloads.  seqnum = $seqnum, tmpDir = $tmpDir");

	# Clear the old data from the workloadDrivers
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
	  $workload->clearResults();
	}
		
	my $success = callBooleanMethodOnObjectsParallel2( 'initializeRun', $workloadsRef, $seqnum, $tmpDir );
	if ( !$success ) {
		$debug_logger->debug("initializeWorkloads initialize failed. ");
		return 0;
	}
	$debug_logger->debug("initializeWorkloads initialize suceeded. ");

	return $success;
}

sub runWorkloads {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug("runWorkloads.  seqnum = $seqnum, tmpDir = $tmpDir");

	my $usingFindMaxLoadPathType = 0;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		my $appInstancesRef = $workload->appInstancesRef;
		foreach my $appInstance (@$appInstancesRef) {
			my $loadPathType = $appInstance->getParamValue('loadPathType');
			if (($loadPathType eq "findmax") || ($loadPathType eq "syncedfindmax")) {
				$usingFindMaxLoadPathType = 1;
				last;
			}
		}
	}

	my $pid = 0;
	if ($usingFindMaxLoadPathType) {
		$self->startStatsCollection($tmpDir);
	} else {
		$pid = $self->followRunProgress($tmpDir, $usingFindMaxLoadPathType);
		$debug_logger->debug("runWorkloads.  followRunprogress has pid $pid");
	}

	my $success = callBooleanMethodOnObjectsParallel2( 'startRun', $self->workloadsRef, $seqnum, $tmpDir );
	if ( !$success && !$usingFindMaxLoadPathType ) {
		$debug_logger->debug("runWorkloads initialize failed.  killing pid $pid");
		kill 9, $pid;
		return 0;
	}
	$debug_logger->debug("runWorkloads run suceeded.");

	if ($usingFindMaxLoadPathType) {
		$self->stopStatsCollection();
	}

	return $success;
}

sub stopWorkloads {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug("stopWorkloads.  seqnum = $seqnum, tmpDir = $tmpDir");

	my $success = callBooleanMethodOnObjectsParallel2( 'stopRun', $self->workloadsRef, $seqnum, $tmpDir );
	if ( !$success ) {
		return 0;
	}
	$debug_logger->debug("stopWorkloads suceeded.");

	return $success;
}

sub shutdownDrivers {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug("shutdownDrivers.  seqnum = $seqnum, tmpDir = $tmpDir");

	my $success = callBooleanMethodOnObjectsParallel2( 'shutdownDrivers', $self->workloadsRef, $seqnum, $tmpDir );
	if ( !$success ) {
		return 0;
	}
	$debug_logger->debug("shutdownDrivers suceeded.");

	return $success;
}

####################
#
# This method spawns a thread that manages activities that must take place
# at certain points during a run.  It starts statistics collection at the
# beginning of steady-steady and stop the collection at the end of steady-state.
#
sub followRunProgress {
	my ($self, $tmpDir)         = @_;
	my $console_logger = get_logger("Console");
	my $rampUp         = $self->getParamValue('rampUp');
	my $warmUp         = $self->getParamValue('warmUp');
	my $steadyState = $self->getParamValue('qosPeriodSec');

	my $pid = fork();
	if ( !defined $pid ) {
		$console_logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {

		sleep 60;
		my $retryCount = 0;

		# wait until the primary workload drivers are all up
		while (( !callBooleanMethodOnObjectsParallel( 'isDriverStarted', $self->workloadsRef ) )
			&& ( $retryCount < 20 ) )
		{
			sleep 30;
			$retryCount++;
		}

		if ( $retryCount >= 20 ) {
			exit;
		}

		sleep($rampUp);
		sleep($warmUp);
		$self->startStatsCollection($tmpDir);
		sleep($steadyState);
		$self->stopStatsCollection();
		exit;
	}

	return $pid;
}

# We have found the maximum if any appInstance has hit a maximum
sub foundMax {
	my ($self) = @_;
	my $foundMax = 1;

	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$foundMax &= $workload->foundMax();
	}

	return $foundMax;
}

sub printFindMaxResult {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->printFindMaxResult();
	}
}

sub adjustUsersForFindMax {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->adjustUsersForFindMax();
	}
}

sub resetFindMax {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->resetFindMax();
	}
}

sub getFindMaxInfoString {
	my ($self)       = @_;
	my $returnString = "";
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$returnString .= $workload->getFindMaxInfoString();
	}
	return $returnString;
}

sub clearReloadDb {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->clearReloadDb();
	}
}

sub cleanData {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'cleanData', $self->workloadsRef, $cleanupLogDir );
}

sub prepareDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("prepareDataServices with logDir $setupLogDir");
	
	# If all of the dataManagers are running on Kubernetes clusters, then
	# we can do the prepare in parallel
	my $allK8s = 1;
	foreach my $workloadRef (@{$self->workloadsRef}) {
		my $appInstancesRef = $workloadRef->appInstancesRef;
		foreach my $appInstanceRef (@{$appInstancesRef}) {
			my $dataManager = $appInstanceRef->dataManager;
			if ((ref $dataManager->host) ne 'KubernetesCluster') {
				$allK8s = 0;
			}
		}
	}
	my $allIsStarted;
	if ($allK8s) {
		$allIsStarted = callBooleanMethodOnObjectsParallel2( 'prepareDataServices', $self->workloadsRef, $setupLogDir, 1 );
	} else {
		$allIsStarted = callBooleanMethodOnObjects2( 'prepareDataServices', $self->workloadsRef, $setupLogDir, 0 );
	}
	return $allIsStarted;
}

sub prepareData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("prepareData with logDir $setupLogDir");
	return callBooleanMethodOnObjectsParallel2( 'prepareData', $self->workloadsRef, $setupLogDir, 1 );
}

sub sanityCheckServices {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'sanityCheckServices', $self->workloadsRef, $cleanupLogDir );
}

sub setPortNumbers {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->setPortNumbers();
	}
}

sub setExternalPortNumbers {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->setExternalPortNumbers();
	}
}

sub isUp {
	my ( $self, $setupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'isUp', $self->workloadsRef, $setupLogDir );
}

sub isPassed {
	my ( $self, $tmpDir ) = @_;
	my $passed = 1;
	foreach my $workload ( @{ $self->workloadsRef } ) {
		$passed &= $workload->isPassed($tmpDir);
	}
	return $passed;
}

sub isWorkloadPassed {
	my ( $self, $tmpDir ) = @_;
	my %workloadPassed;
	foreach my $workload ( @{ $self->workloadsRef } ) {
		$workloadPassed{$workload->instanceNum} = $workload->isPassed($tmpDir);
	}
	return \%workloadPassed;
}

sub setLoadPathType {
	my ( $self, $loadPathType ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	
	$logger->debug("setLoadPathType for all workloads to $loadPathType");
	
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->setLoadPathType($loadPathType);
	}
}

sub startServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	
	$logger->debug("startServices for serviceTier $serviceTier with logDir $setupLogDir");
	
	# If all of the dataManagers are running on Kubernetes clusters, then
	# we can do the start in parallel
	my $allK8s = 1;
	foreach my $workloadRef (@{$self->workloadsRef}) {
		my $appInstancesRef = $workloadRef->appInstancesRef;
		foreach my $appInstanceRef (@{$appInstancesRef}) {
			my $dataManager = $appInstanceRef->dataManager;
			if ((ref $dataManager->host) ne 'KubernetesCluster') {
				$allK8s = 0;
			}
		}
	}
	my $allIsStarted = 1;
	if ($allK8s) {
		$allIsStarted = callBooleanMethodOnObjectsParallel3( 'startServices', $self->workloadsRef, $serviceTier, $setupLogDir, 1 );
	} else {
		my $workloadsRef = $self->workloadsRef;
		foreach my $workload (@$workloadsRef) {
			$allIsStarted = $workload->startServices($serviceTier, $setupLogDir, 0);
			if (!$allIsStarted) {
				last;
			}
		}
	}
	return $allIsStarted;
}

sub stopServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("stopServices for serviceTier $serviceTier with logDir $setupLogDir");
	
	callMethodOnObjectsParallel2( 'stopServices', $self->workloadsRef, $serviceTier, $setupLogDir );
}

sub stopServicesInClusters {
	my ( $self ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("stopServicesInClusters");

	callMethodOnObjectsParallel( 'kubernetesDeleteAllForCluster', $self->clustersRef );
}

sub stopDataManager {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("stopDataManager with logDir $setupLogDir");
	
	callMethodOnObjectsParallel1( 'stopDataManager', $self->workloadsRef, $setupLogDir );
}

sub removeServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("removeServices removing $serviceTier services with log dir $setupLogDir");
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->removeServices($serviceTier, $setupLogDir);
	}
}

sub cleanupAfterFailure {
	my ( $self, $errorMessage, $seqnum, $tmpDir ) = @_;
	my $console_logger = get_logger("Console");

	if ( !$self->getParamValue('stopOnFailure') ) {
		$console_logger->error("$errorMessage\n");
		exit(-1);
	}

	my $cleanupLogDir = $tmpDir . "/cleanupLogs";
	if ( !( -e $cleanupLogDir ) ) {
		`mkdir -p $cleanupLogDir`;
	}

	## get the logs
	$self->getLogFiles($tmpDir);

	## get the config files
	$self->getConfigFiles($tmpDir);

	## stop the services
	$self->stopDataManager($tmpDir);
		
	my @tiers = qw(frontend backend data infrastructure);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $tmpDir );

	# clean up old logs and stats
	$self->cleanup($cleanupLogDir);

	$console_logger->error("$errorMessage\n");
	exit(-1);
}

sub startStatsCollection {
	my ($self, $tmpDir)            = @_;
	my $console_logger    = get_logger("Console");
	my $intervalLengthSec = $self->getParamValue('statsInterval');
	my $steadyStateLength = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $numIntervals = floor( $steadyStateLength / ( $intervalLengthSec * 1.0 ) );
	my $logLevel     = $self->getParamValue('logLevel');
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");

	$logger->debug( "startStatsCollection.  logLevel = " . $logLevel );

	my $startStatsScript = $self->getParamValue('startStatsScript');
	my $seqnum = $self->seqnum;
	if ($startStatsScript) {
		$console_logger->info("Starting external script for startStats: \`$startStatsScript $steadyStateLength $seqnum\`\n");
		my $pid = fork();
		if ( $pid == 0 ) {
			my $cmdOut = `$startStatsScript $steadyStateLength`;
			exit;
		}
	}

	if ( $logLevel >= 2 ) {
		$console_logger->info("Starting performance statistics collection on hosts.\n");

		# Start collection on hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$host->startStatsCollection( $intervalLengthSec, $numIntervals );
		}

		# Start collection on clusters.
		my $clustersRef = $self->clustersRef;
		foreach my $cluster (@$clustersRef) {
			$cluster->startStatsCollection( $intervalLengthSec, $numIntervals, $tmpDir );
		}
	}

	if ( $logLevel >= 4 ) {
		$console_logger->info("Starting performance statistics collection on virtual-infrastructure hosts.\n");
		my $usingFindMaxLoadPathType = 0;
		my $workloadsRef = $self->workloadsRef;
		foreach my $workload (@$workloadsRef) {
			my $appInstancesRef = $workload->appInstancesRef;
			foreach my $appInstance (@$appInstancesRef) {
				my $loadPathType = $appInstance->getParamValue('loadPathType');
				if (($loadPathType eq "findmax") || ($loadPathType eq "syncedfindmax")) {
					$usingFindMaxLoadPathType = 1;
					last;
				}
			}
		}

		# Start starts collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		if ($usingFindMaxLoadPathType) {
			$virtualInfrastructure->startStatsCollection( $intervalLengthSec, 0 );
		} else {
			$virtualInfrastructure->startStatsCollection( $intervalLengthSec, $numIntervals );			
		}
	}

}

sub stopStatsCollection {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $console_logger = get_logger("Console");
	my $logLevel       = $self->getParamValue('logLevel');
	$logger->debug( "stopStatsCollection.  logLevel = " . $logLevel );

	my $stopStatsScript = $self->getParamValue('stopStatsScript');
	my $seqnum = $self->seqnum;
	if ($stopStatsScript) {
		$console_logger->info("Starting external script for stopStats: \`$stopStatsScript $seqnum\`\n");
		my $pid = fork();
		if ( $pid == 0 ) {
			my $cmdOut = `$stopStatsScript`;
			exit;
		}
	}

	if ( $logLevel >= 2 ) {
		$console_logger->info("Stopping performance statistics collection on hosts.\n");

		# stops collection on hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$host->stopStatsCollection();
		}

		# stop collection on clusters.
		my $clustersRef = $self->clustersRef;
		foreach my $cluster (@$clustersRef) {
			$cluster->stopStatsCollection();
		}
	}

	if ( $logLevel >= 4 ) {

		# Start stops collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		$virtualInfrastructure->stopStatsCollection();
	}

}

sub getStatsFiles {
	my ($self, $tmpDir)       = @_;
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $fullFilePath = $self->getParamValue('fullFilePath');

	my $baseDestinationPath = $tmpDir . "/statistics";
	my $destinationPath;
	
	my $logLevel = $self->getParamValue('logLevel');
	if ( $logLevel >= 2 ) {

		# get stats files from hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$destinationPath = $baseDestinationPath . "/hosts/" . $host->name;
			if ( !( -e $destinationPath ) ) {
				`mkdir -p $destinationPath`;
			}

			$host->getStatsFiles($destinationPath);
		}
	}

	if ( $logLevel >= 4 ) {

		# Start stops collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		my $name                  = $virtualInfrastructure->name;
		$destinationPath = $baseDestinationPath . "/" . $name;
		if ( !( -e $destinationPath ) ) {
			`mkdir -p $destinationPath`;
		}
		$virtualInfrastructure->getStatsFiles($destinationPath);
	}

	my $usePrefix = 0;
	if ( ( $#{ $self->workloadsRef } > 0 ) || ($fullFilePath) ) {
		$usePrefix = 1;
	}
	callMethodOnObjectsParallel2( 'getStatsFiles', $self->workloadsRef, $baseDestinationPath, $usePrefix );

}

sub cleanup {
	my ($self, $cleanupLogDir) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");

	return callBooleanMethodOnObjectsParallel1( 'cleanupAppInstances', $self->workloadsRef, $cleanupLogDir );
	$self->cleanStatsFiles();
	$self->cleanLogFiles();

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $pid;
	my @pids;

	$logger->debug("CleanStatsFiles\n");
	my $logLevel = $self->getParamValue('logLevel');
	if ( $logLevel >= 2 ) {

		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$pid = fork();
			if ( !defined $pid ) {
				$logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$host->cleanStatsFiles();
				exit;
			}
			else {
				push @pids, $pid;
			}
		}

	}

	if ( $logLevel >= 4 ) {

		# Clean stats files on virtual infrastructure
		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			my $virtualInfrastructure = $self->virtualInfrastructure;
			$virtualInfrastructure->cleanStatsFiles();
			exit;
		}
		else {
			push @pids, $pid;
		}
	}

	# Clean stats files from workload driver.  Stats files for services are cleaned in service stop
	$pid = fork();
	if ( !defined $pid ) {
		$logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		callMethodOnObjectsParallel( 'cleanStatsFiles', $self->workloadsRef );
		exit;
	}
	else {
		push @pids, $pid;
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $pid;
	my @pids;
	$logger->debug(": CleanLogFiles\n");

	my $hostsRef = $self->hostsRef;
	foreach my $host (@$hostsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$host->cleanLogFiles();
			exit;
		}
		else {
			push @pids, $pid;
		}
	}

	# clean log files on virtual infrastructure
	$pid = fork();
	if ( !defined $pid ) {
		$logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		my $virtualInfrastructure = $self->virtualInfrastructure;
		$virtualInfrastructure->cleanLogFiles();
		exit;
	}
	else {
		push @pids, $pid;
	}

	# Clean logs from workload driver.  Service logs are cleaned in service stop
	$pid = fork();
	if ( !defined $pid ) {
		$logger->error("Couldn't fork a process: $!");
		exit(-1);
	}
	elsif ( $pid == 0 ) {
		callMethodOnObjectsParallel( 'cleanLogFiles', $self->workloadsRef );
		exit;
	}
	else {
		push @pids, $pid;
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub getLogFiles {
	my ($self, $tmpDir) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $pid;
	my @pids;
	my $fullFilePath = $self->getParamValue('fullFilePath');

	my $baseDestinationPath =  "$tmpDir/logs";
	my $destinationPath;

	my $distDir         = $self->getParamValue('distDir');
	`cp $distDir/build-commit-sha.txt $tmpDir/. 2>&1`;

	if ( $self->getParamValue('logLevel') >= 1 ) {

		# get logs from hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {

			$pid = fork();
			if ( !defined $pid ) {
				$logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$destinationPath = $baseDestinationPath . "/hosts/" . $host->name;
				if ( !( -e $destinationPath ) ) {
					`mkdir -p $destinationPath`;
				}

				$host->getLogFiles($destinationPath);
				exit;
			}
			else {
				push @pids, $pid;
			}
		}

		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			my $virtualInfrastructure = $self->virtualInfrastructure;
			my $name                  = $virtualInfrastructure->name;
			$destinationPath = $baseDestinationPath . "/" . $name;
			if ( !( -e $destinationPath ) ) {
				`mkdir -p $destinationPath`;
			}
			$virtualInfrastructure->getLogFiles($destinationPath);
			exit;
		}
		else {
			push @pids, $pid;
		}

		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			my $usePrefix = 0;
			if ( ( $#{ $self->workloadsRef } > 0 ) || ($fullFilePath) ) {
				$usePrefix = 1;
			}

			callMethodOnObjectsParallel2( 'getLogFiles', $self->workloadsRef, $baseDestinationPath, $usePrefix );
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

sub getConfigFiles {
	my ($self, $tmpDir)       = @_;
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $fullFilePath = $self->getParamValue('fullFilePath');
	my $pid;
	my @pids;

	my $baseDestinationPath = $tmpDir . "/configuration";
	my $destinationPath;
    
    $logger->debug("getConfigFiles: logLevel = " . $self->getParamValue('logLevel'));
	if ( $self->getParamValue('logLevel') >= 1 ) {

        # get config files from hosts.
        my $hostsRef = $self->hostsRef;
        $logger->debug("getConfigFiles: There are " . ($#$hostsRef + 1) .  " hosts");
        foreach my $host (@$hostsRef) {
            $pid = fork();
            if ( !defined $pid ) {
                $logger->error("Couldn't fork a process: $!");
                exit(-1);
            }
            elsif ( $pid == 0 ) {
                $destinationPath = $baseDestinationPath . "/hosts/" . $host->name;
                if ( !( -e $destinationPath ) ) {
                    `mkdir -p $destinationPath`;
                }

                $host->getConfigFiles($destinationPath);
                exit;
            }
            else {
                push @pids, $pid;
            }
        }

        # get config files from hosts.
        my $clustersRef = $self->clustersRef;
        $logger->debug("getConfigFiles: There are " . ($#$clustersRef + 1) .  "clusters");
        foreach my $cluster (@$clustersRef) {
            $pid = fork();
            if ( !defined $pid ) {
                $logger->error("Couldn't fork a process: $!");
                exit(-1);
            }
            elsif ( $pid == 0 ) {
                $destinationPath = $baseDestinationPath . "/clusters/" . $cluster->name;
                if ( !( -e $destinationPath ) ) {
                    `mkdir -p $destinationPath`;
                }

                $cluster->getConfigFiles($destinationPath);
                exit;
            }
            else {
                push @pids, $pid;
            }
        }

		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			my $virtualInfrastructure = $self->virtualInfrastructure;
			my $name                  = $virtualInfrastructure->name;
			$destinationPath = $baseDestinationPath . "/" . $name;
			if ( !( -e $destinationPath ) ) {
				`mkdir -p $destinationPath`;
			}
			$virtualInfrastructure->getConfigFiles($destinationPath);
			exit;
		}
		else {
			push @pids, $pid;
		}

		$pid = fork();
		if ( !defined $pid ) {
			$logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			my $usePrefix = 0;
			if ( ( $#{ $self->workloadsRef } > 0 ) || ($fullFilePath) ) {
				$usePrefix = 1;
			}

			callMethodOnObjectsParallel2( 'getConfigFiles', $self->workloadsRef, $baseDestinationPath, $usePrefix );
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

sub printCsv {
	my ( $self, $csvHashRef ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	## print the csv headers to the results file
	open( CSVFILE, ">>" . $self->resultsFileDir . "/" . $self->resultsFileName )
	  or die "Couldn't open file >>" . $self->resultsFileDir . "/" . $self->resultsFileName . " :$!\n";
	foreach my $key ( keys %$csvHashRef ) {
		print CSVFILE "$key,";
	}
	print CSVFILE "\n";
	foreach my $key ( keys %$csvHashRef ) {
		print CSVFILE $csvHashRef->{$key} . ",";
	}
	print CSVFILE "\n";
	close CSVFILE;

	## put a copy of the csv results in the tmp dir
	open( CSVFILE, ">" . $self->tmpDir . "/" . $self->resultsFileName )
	  or die "Couldn't open file >>" . $self->tmpDir . "/" . $self->resultsFileName . " :$!\n";
	foreach my $key ( keys %$csvHashRef ) {
		print CSVFILE "$key,";
	}
	print CSVFILE "\n";
	foreach my $key ( keys %$csvHashRef ) {
		print CSVFILE $csvHashRef->{$key} . ",";
	}
	print CSVFILE "\n";
	close CSVFILE;

}

sub getResultMetrics {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	my $WvUsers = 0;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		my $metricsRef = $workload->getResultMetrics();
		$WvUsers += $metricsRef->{"WvUsers"};
	}
	$csv{"WvUsers"}         = $WvUsers;
	
	return \%csv;
}

sub getWorkloadResultMetrics {
	my ( $self ) = @_;
	my %csv;
	
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		my $metricsRef = $workload->getResultMetrics();
		$csv{$workload->instanceNum} = {"WvUsers" => $metricsRef->{"WvUsers"}};
	}
	
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $logger              = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $workloadsRef        = $self->workloadsRef;
	my $logLevel            = $self->getParamValue('logLevel');
	my $fullFilePath        = $self->getParamValue('fullFilePath');
	my $baseDestinationPath = $tmpDir . "/statistics";
	my $destinationPath;
	tie( my %csv, 'Tie::IxHash' );

	# Need to strip commas out of the description field
	my $description = $self->getParamValue('description');
	$description =~ s/,/ /g;
	my $runStrategy = $self->getParamValue("runStrategy");
	%csv = (
		"seqnum"      => $seqnum,
		"description" => $description,
		"timestamp"   => scalar localtime,
		"runStrategy"   => $runStrategy,
	);

	# Get the csv data about the workloads
	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->instanceNum . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadStatsSummary( $tmpDir );
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->instanceNum . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadSummary( $tmpDir );
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->instanceNum . "-";
		}
		my $tmpCsvRef = $workload->getAppInstanceStatsSummary();
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->instanceNum . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadAppStatsSummary($tmpDir);
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	if ( $logLevel >= 2 ) {

		$destinationPath = $baseDestinationPath . "/hosts";

		# Get the host stats by workload and service-type
		foreach my $workload (@$workloadsRef) {
			my $prefix = "";
			if ( $#{$workloadsRef} > 0 ) {
				$prefix = "W" . $workload->instanceNum . "-";
			}
			my $tmpCsvRef = $workload->getHostStatsSummary( $destinationPath, $prefix );
			my @keys = keys %$tmpCsvRef;
			foreach my $key (@keys) {
				$csv{ $prefix . $key } = $tmpCsvRef->{$key};
			}
		}
	}

	if ( $logLevel >= 3 ) {

		# Get the host stats by workload and service-type
		foreach my $workload (@$workloadsRef) {
			my $prefix = "";
			if ( $#{$workloadsRef} > 0 ) {
				$prefix = "W" . $workload->instanceNum . "-";
			}

			my $usePrefix = 0;
			if ( ( $#{ $self->workloadsRef } > 0 ) || ($fullFilePath) ) {
				$usePrefix = 1;
			}

			my $tmpCsvRef = $workload->getStatsSummary( $baseDestinationPath, $usePrefix, $tmpDir );
			my @keys = keys %$tmpCsvRef;
			foreach my $key (@keys) {
				$csv{ $prefix . $key } = $tmpCsvRef->{$key};
			}
		}

	}

	if ( $logLevel >= 4 ) {

		# Start stops collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		my $name                  = $virtualInfrastructure->name;
		$destinationPath = $baseDestinationPath . "/" . $name;
		my $tmpCsvRef = $virtualInfrastructure->getStatsSummary($destinationPath);
		@csv{ keys %$tmpCsvRef } = values %$tmpCsvRef;
	}

	return \%csv;
}

sub run {
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	die "Only concrete classes of RunProcedure implement run()";
}

sub getNextRunInfo {
	my ($self) = @_;

	my $returnString = "";
	my $workloadsRef = $self->workloadsRef;
	if ( $#{$workloadsRef} > 0 ) {
		$returnString .= ":\n";
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix =
			    "Workload "
			  . $workload->instanceNum
			  . ", Implementation: "
			  . $workload->getParamValue("workloadImpl");
		}
		$returnString .= $prefix . $workload->getNextRunInfo();
	}

	return $returnString;
}

sub writeUsersTxt {
	my ($self, $tmpDir) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	open( my $fileOut, ">$tmpDir/users.txt" ) or die "Error opening $tmpDir/users.txt:$!";

	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->writeUsersTxt($fileOut);
	}
	close $fileOut;
}

sub checkUsersTxt {
	my ($self, $tmpDir)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");

	open( my $filein, "$tmpDir/users.txt" ) or do {
		$console_logger->info("The runOnly runProcedure must be run after a prepareOnly runProcedure.");
		return 0;
	};

	my $passAll      = 1;
	my $workloadsRef = $self->workloadsRef;
	while ( my $inline = <$filein> ) {
		$inline =~ /Workload\s(\d+),\sApp\sInstance\s(\d+):\s(\d+)\sUsers/;
		if ( ( $#$workloadsRef + 1 ) < $1 ) {
			$console_logger->info(
"The configuration from the prepareOnly phase specifies a workload $1 which isn't in the current configuration"
			);
			return 0;
		}

		my $workload = $workloadsRef->[ $1 - 1 ];
		$passAll &= $workload->checkUsersTxt($inline);
	}
	return $passAll;
}

####################
#
# This runs when Weathervane is in interactive mode to allow the user to change the
# number of active users for each appInstance
#
sub interactiveMode {
	my ($self)         = @_;
#	my $console_logger = get_logger("Console");
#	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");
#	my $rampUp         = $self->getParamValue('rampUp');
#   my $steadyState = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
#	my $rampDown       = $self->getParamValue('rampDown');
#	my $totalDuration  = $rampUp + $steadyState + $rampDown;
#	my $endTime        = time() + $totalDuration;
#
#	my $pid = fork();
#	if ( !defined $pid ) {
#		$console_logger->error("Couldn't fork a process: $!");
#		exit(-1);
#	}
#	elsif ( $pid == 0 ) {
#		my $scr = new Term::Screen;
#		$scr->clrscr();
#		
#		# have one process to keep updating the number of active users,
#		# and another to get input
#		$pid = fork();
#		if ( !defined $pid ) {
#			$console_logger->error("Couldn't fork a process: $!");
#			exit(-1);
#		}
#		elsif ( $pid == 0 ) {
#
#			my $workloadsRef = $self->workloadsRef;
#
#			while ( time() < $endTime ) {
#				my $i = 0;
#
#				# Get current number of users for each workload
#				$i = 0;
#				foreach my $workloadRef (@$workloadsRef) {
#					my $workloadNum                     = $workloadRef->instanceNum;
#					my $appInstanceToActiveUsersHashRef = $workloadRef->getNumActiveUsers();
#
#					foreach my $appInstance ( keys %$appInstanceToActiveUsersHashRef ) {
#						$scr->at( $i, 0 );
#						$scr->clreol();
#						$scr->puts( "$i) Workload $workloadNum, $appInstance: "
#							  . $appInstanceToActiveUsersHashRef->{$appInstance}
#							  . " active users" );
#						$i++;
#					}
#				}
#				sleep(5);
#			}
#
#			exit;
#		}
#		else {
#			# Figure out the total number of appInstances
#			my $numAppInstances = 0;
#			my %workloadNumHash;
#			my %appInstanceNumHash;
#			my $workloadsRef = $self->workloadsRef;
#			foreach my $workloadRef (@$workloadsRef) {
#				my $appInstancesRef = $workloadRef->appInstancesRef;
#
#				my $workloadNum = $workloadRef->instanceNum;
#				foreach my $appInstance (@$appInstancesRef) {
#					$workloadNumHash{$numAppInstances}    = $workloadNum;
#					$appInstanceNumHash{$numAppInstances} = $appInstance->instanceNum;
#					$numAppInstances++;
#				}
#			}
#
#			my $lineNum = $numAppInstances + 1;
#			while ( time() < $endTime ) {
#				$scr->at( $lineNum, 0 );
#				$scr->clreol();
#				$scr->puts("To change the number of actives users for an appInstance, select the row number:");
#
#				my $selection = <STDIN>;
#				chomp($selection);
#				if ( !exists $workloadNumHash{$selection} ) {
#					die "No workloadNum for $selection\n";
#				}
#				my $workloadNum = $workloadNumHash{$selection};
#				if ( !exists $appInstanceNumHash{$selection} ) {
#					die "No appInstance for $selection\n";
#				}
#				my $appInstanceName = "appInstance" . $appInstanceNumHash{$selection};
#				my $workloadRef     = $workloadsRef->[$workloadNum];
#
#				$scr->at( $lineNum + 1, 0 );
#				$scr->clreol();
#				$scr->puts("Select the new number of active users for Workload $workloadNum, $appInstanceName:");
#
#				my $numUsers = <STDIN>;
#				chomp($numUsers);
#
#				$workloadRef->setNumActiveUsers( $appInstanceName, $numUsers );
#				$scr->at( $lineNum + 1, 0 );
#				$scr->clreol();
#
#			}
#			exit;
#		}
#	}
#	return $pid;
}

sub toString {
	my ($self) = @_;

	return $self->name();
}

__PACKAGE__->meta->make_immutable;

1;

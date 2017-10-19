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
  callBooleanMethodOnObjectsParallel callBooleanMethodOnObjectsParallel1 callBooleanMethodOnObjectsParallel2 callBooleanMethodOnObjectsParallel3);
use Instance;
use Utils qw(getIpAddresses getIpAddress);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'Instance';

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

has 'virtualInfrastructure' => (
	is  => 'rw',
	isa => 'VirtualInfrastructure',
);

has 'hostsRef' => (
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
	isa => 'Int',
);

has 'runLog' => ( is => 'rw', );

override 'initialize' => sub {
	my ($self) = @_;
	my $weathervaneHome = $self->getParamValue('weathervaneHome');

	# if the tmpDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $tmpDir = $self->getParamValue('tmpDir');
	if ( !( $tmpDir =~ /^\// ) ) {
		$tmpDir = $weathervaneHome . "/" . $tmpDir;
	}
	$self->setParamValue( 'tmpDir', $tmpDir );

	# if the outputDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $outputDir = $self->getParamValue('outputDir');
	if ( !( $outputDir =~ /^\// ) ) {
		$outputDir = $weathervaneHome . "/" . $outputDir;
	}
	$self->setParamValue( 'outputDir', $outputDir );

	# if the distDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $distDir         = $self->getParamValue('distDir');
	if ( !( $distDir =~ /^\// ) ) {
		$distDir = $weathervaneHome . "/" . $distDir;
	}
	$self->setParamValue( 'distDir', $distDir );

	# if the sequenceNumberFile doesn't start with a / then it
	# is relative to weathervaneHome
	my $sequenceNumberFile = $self->getParamValue('sequenceNumberFile');
	if ( !( $sequenceNumberFile =~ /^\// ) ) {
		$sequenceNumberFile = $weathervaneHome . "/" . $sequenceNumberFile;
	}
	$self->setParamValue( 'sequenceNumberFile', $sequenceNumberFile );

	# make sure the directories exist
	if ( !( -e $tmpDir ) ) {
		`mkdir $tmpDir`;
	}

	if ( !( -e $outputDir ) ) {
		`mkdir -p $outputDir`;
	}

	my $logLevel = $self->getParamValue('logLevel');
	if ( ( $logLevel < 0 ) || ( $logLevel > 4 ) ) {
		die "The logLevel must be between 0 and 4";
	}

	if ( ( $self->getParamValue('runStrategy') eq "targetUtilization" ) && ( $self->getParamValue('logLevel') < 3 ) ) {
		die "The logLevel must be >= 3 in order to run the targetUtilization run strategy";
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

# Tell the hosts to go get their CPU and memory configuration
sub getCpuMemConfig {
	my ($self)       = @_;
	my $hostsRef     = $self->hostsRef;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");

	foreach my $host (@$hostsRef) {
		$host->getCpuMemConfig();
	}

}

sub killOldWorkloadDrivers {
	my ($self) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug(": Stopping old workload drivers.");

	callMethodOnObjectsParallel( 'killOldWorkloadDrivers', $self->workloadsRef );
}

sub initializeWorkloads {
	my ( $self, $seqnum, $tmpDir ) = @_;
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$debug_logger->debug("initializeWorkloads.  seqnum = $seqnum, tmpDir = $tmpDir");

	my $success = callBooleanMethodOnObjectsParallel2( 'initializeRun', $self->workloadsRef, $seqnum, $tmpDir );
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

	my $pid = $self->followRunProgress();
	$debug_logger->debug("runWorkloads.  followRunprogress has pid $pid");

	my $success = callBooleanMethodOnObjectsParallel2( 'startRun', $self->workloadsRef, $seqnum, $tmpDir );
	if ( !$success ) {
		$debug_logger->debug("runWorkloads initialize failed.  killing pid $pid");
		kill 9, $pid;
		return 0;
	}
	$debug_logger->debug("runWorkloads run suceeded.");

	return $success;
}

####################
#
# This method spawns a thread that manages activities that must take place
# at certain points during a run.  It starts statistics collection at the
# beginning of steady-steady and stop the collection at the end of steady-state.
#
sub followRunProgress {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $rampUp         = $self->getParamValue('rampUp');
	my $steadyState    = $self->getParamValue('steadyState');

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
		$self->startStatsCollection();
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

sub hitTargetUt {
	my ($self)   = @_;
	my $passAll  = $self->getParamValue('targetUtilizationPassAll');
	my $foundMax = 0;
	if ($passAll) {
		$foundMax = 1;
	}

	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		my $wFoundMax = $workload->hitTargetUt();
		if ($passAll) {
			$foundMax &= $wFoundMax;
		}
		else {
			if ($wFoundMax) {
				$foundMax = 1;
			}
		}
	}

	return $foundMax;
}

sub adjustUsersForFindMax {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->adjustUsersForFindMax();
	}
}

sub adjustUsersForTargetUt {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->adjustUsersForTargetUt();
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

sub prepareData {
	my ( $self, $setupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'prepareData', $self->workloadsRef, $setupLogDir );
}

sub configureAndStartInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->configureAndStartInfrastructureServices($setupLogDir);
	}
}

sub sanityCheckServices {
	my ( $self, $cleanupLogDir ) = @_;
	return callBooleanMethodOnObjectsParallel1( 'sanityCheckServices', $self->workloadsRef, $cleanupLogDir );
}

sub configureAndStartFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->configureAndStartFrontendServices($setupLogDir);
	}
}

sub configureAndStartBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->configureAndStartBackendServices($setupLogDir);
	}
}

sub configureAndStartDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->configureAndStartDataServices($setupLogDir);
	}
}

sub startInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->startInfrastructureServices($setupLogDir);
	}
}

sub startFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->startFrontendServices($setupLogDir);
	}
}

sub startBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->startBackendServices($setupLogDir);
	}
}

sub startDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->startDataServices($setupLogDir);
	}
}

sub pretouchData {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	return callMethodOnObjectsParallel1( 'pretouchData', $self->workloadsRef, $setupLogDir );
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

sub unRegisterPortNumbers {
	my ($self) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->unRegisterPortNumbers();
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

sub clearResults {
	my ( $self, $tmpDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->clearResults();
	}
}

sub stopInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'stopInfrastructureServices', $self->workloadsRef, $setupLogDir );
}

sub stopFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'stopFrontendServices', $self->workloadsRef, $setupLogDir );
}

sub stopBackendServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'stopBackendServices', $self->workloadsRef, $setupLogDir );
}

sub stopDataServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'stopDataServices', $self->workloadsRef, $setupLogDir );
}

sub removeInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("removing infrastructure services with log dir $setupLogDir");
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->removeInfrastructureServices($setupLogDir);
	}
}

sub removeFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	$logger->debug("removing frontend services with log dir $setupLogDir");
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->removeFrontendServices($setupLogDir);
	}
}

sub removeBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->removeBackendServices($setupLogDir);
	}
}

sub removeDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->removeDataServices($setupLogDir);
	}
}

sub createInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'createInfrastructureServices', $self->workloadsRef, $setupLogDir );
}

sub createFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'createFrontendServices', $self->workloadsRef, $setupLogDir );
}

sub createBackendServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'createBackendServices', $self->workloadsRef, $setupLogDir );
}

sub createDataServices {
	my ( $self, $setupLogDir ) = @_;
	callMethodOnObjectsParallel1( 'createDataServices', $self->workloadsRef, $setupLogDir );
}

sub configureInfrastructureServices {
	my ($self) = @_;
	callMethodOnObjectsParallel( 'configureInfrastructureServices', $self->workloadsRef );
}

sub configureFrontendServices {
	my ($self) = @_;
	callMethodOnObjectsParallel( 'configureFrontendServices', $self->workloadsRef );
}

sub configureBackendServices {
	my ($self) = @_;
	callMethodOnObjectsParallel( 'configureBackendServices', $self->workloadsRef );
}

sub configureDataServices {
	my ($self) = @_;
	callMethodOnObjectsParallel( 'configureDataServices', $self->workloadsRef );
}

sub cleanupAfterFailure {
	my ( $self, $errorMessage, $seqnum, $tmpDir, $outputDir ) = @_;
	my $console_logger = get_logger("Console");

	if ( !$self->getParamValue('stopOnFailure') ) {
		$console_logger->error("$errorMessage\n");
		exit(-1);
	}

	my $cleanupLogDir = $tmpDir . "/cleanupLogs";
	if ( !( -e $cleanupLogDir ) ) {
		`mkdir -p $cleanupLogDir`;
	}

	## stop the services
	$self->stopInfrastructureServices($cleanupLogDir);
	$self->stopFrontendServices($cleanupLogDir);
	$self->stopBackendServices($cleanupLogDir);
	$self->stopDataServices($cleanupLogDir);

	## get the logs
	$self->getLogFiles();

	## get the config files
	$self->getConfigFiles();

	# clean up old logs and stats
	$self->cleanup();

	# Remove the services if they are dockerized
	$self->removeInfrastructureServices($cleanupLogDir);
	$self->removeFrontendServices($cleanupLogDir);
	$self->removeBackendServices($cleanupLogDir);
	$self->removeDataServices($cleanupLogDir);

	my $resultsDir = "$outputDir/$seqnum";
	`mkdir -p $resultsDir`;
	`mv $tmpDir/* $resultsDir/.`;

	$console_logger->error("$errorMessage\n");
	exit(-1);
}

sub startStatsCollection {
	my ($self)            = @_;
	my $console_logger    = get_logger("Console");
	my $intervalLengthSec = $self->getParamValue('statsInterval');
	my $steadyStateLength = $self->getParamValue('steadyState');
	my $numIntervals = floor( $steadyStateLength / ( $intervalLengthSec * 1.0 ) );
	my $logLevel     = $self->getParamValue('logLevel');
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");

	$logger->debug( "startStatsCollection.  logLevel = " . $logLevel );

	my $startStatsScript = $self->getParamValue('startStatsScript');
	if ($startStatsScript) {
		$console_logger->info("Starting external script for startStats: \`$startStatsScript $steadyStateLength\`\n");
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
	}

	if ( $logLevel >= 4 ) {
		$console_logger->info("Starting performance statistics collection on virtual-infrastructure hosts.\n");

		# Start starts collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		$virtualInfrastructure->startStatsCollection( $intervalLengthSec, $numIntervals );
	}

}

sub stopStatsCollection {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $console_logger = get_logger("Console");
	my $logLevel       = $self->getParamValue('logLevel');
	$logger->debug( "stopStatsCollection.  logLevel = " . $logLevel );

	my $stopStatsScript = $self->getParamValue('stopStatsScript');
	if ($stopStatsScript) {
		$console_logger->info("Starting external script for stopStats: \`$stopStatsScript\`\n");
		my $pid = fork();
		if ( $pid == 0 ) {
			my $cmdOut = `$stopStatsScript`;
			exit;
		}
	}

	if ( $logLevel >= 2 ) {

		# stops collection on hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$host->stopStatsCollection();
		}
	}

	if ( $logLevel >= 4 ) {

		# Start stops collection on virtual infrastructure
		my $virtualInfrastructure = $self->virtualInfrastructure;
		$virtualInfrastructure->stopStatsCollection();
	}

}

sub getStatsFiles {
	my ($self)       = @_;
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $fullFilePath = $self->getParamValue('fullFilePath');

	my $baseDestinationPath = $self->getParamValue('tmpDir') . "/statistics";
	my $destinationPath;
	
	my $logLevel = $self->getParamValue('logLevel');
	if ( $logLevel >= 2 ) {

		# get stats files from hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$destinationPath = $baseDestinationPath . "/hosts/" . $host->hostName;
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

		# Start stops collection on virtual infrastructure
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

sub getLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $pid;
	my @pids;
	my $fullFilePath = $self->getParamValue('fullFilePath');

	my $tmpDir = $self->getParamValue('tmpDir');
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
				$destinationPath = $baseDestinationPath . "/hosts/" . $host->hostName;
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

sub getConfigFiles {
	my ($self)       = @_;
	my $logger       = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $fullFilePath = $self->getParamValue('fullFilePath');
	my $pid;
	my @pids;

	my $baseDestinationPath = $self->getParamValue('tmpDir') . "/configuration";
	my $destinationPath;

	if ( $self->getParamValue('logLevel') >= 1 ) {

		# get config files from hosts.
		my $hostsRef = $self->hostsRef;
		foreach my $host (@$hostsRef) {
			$pid = fork();
			if ( !defined $pid ) {
				$logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$destinationPath = $baseDestinationPath . "/hosts/" . $host->hostName;
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

sub getStatsSummary {
	my ( $self, $seqnum ) = @_;
	my $logger              = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $workloadsRef        = $self->workloadsRef;
	my $logLevel            = $self->getParamValue('logLevel');
	my $fullFilePath        = $self->getParamValue('fullFilePath');
	my $baseDestinationPath = $self->getParamValue('tmpDir') . "/statistics";
	my $destinationPath;
	tie( my %csv, 'Tie::IxHash' );

	# Need to strip commas out of the description field
	my $description = $self->getParamValue('description');
	$description =~ s/,/ /g;

	%csv = (
		"seqnum"      => $seqnum,
		"description" => $description,
		"timestamp"   => scalar localtime,
	);

	# Get the csv data about the workloads
	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadStatsSummary( $self->getParamValue('tmpDir') );
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadSummary( $self->getParamValue('tmpDir') );
		my @keys      = keys %$tmpCsvRef;
		foreach my $key (@keys) {
			$csv{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}

	foreach my $workload (@$workloadsRef) {
		my $prefix = "";
		if ( $#{$workloadsRef} > 0 ) {
			$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
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
			$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
		}
		my $tmpCsvRef = $workload->getWorkloadAppStatsSummary();
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
				$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
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
				$prefix = "W" . $workload->getParamValue("workloadNum") . "-";
			}

			my $usePrefix = 0;
			if ( ( $#{ $self->workloadsRef } > 0 ) || ($fullFilePath) ) {
				$usePrefix = 1;
			}

			my $tmpCsvRef = $workload->getStatsSummary( $baseDestinationPath, $usePrefix );
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

sub doPowerControl {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $console_logger = get_logger("Console");

	my $hostnamePrefix = $self->getParamValue('hostnamePrefix');
	$console_logger->info("Checking the power state of the virtual machines\n");

	my $powerOnVms     = $self->getParamValue('powerOnVms');
	my $powerOffVms    = $self->getParamValue('powerOffVms');
	my $powerOffAllVms = $self->getParamValue('powerOffAllVms');

	#
	my $virtualInfrastructure     = $self->virtualInfrastructure;
	my $vmNameToPowerstateHashRef = $virtualInfrastructure->getVMPowerState();
	my @vmNames                   = keys %$vmNameToPowerstateHashRef;

	# First get the right number of VMs powered on
	# This variable is set to 1 if any VMs are powered on or off
	# Use this to control a 5 minute wait.
	my $tookPoweronAction  = 0;
	my $tookPoweroffAction = 0;

	# Power on hosts.  All other VMs on the VI hosts will be powered off.
	my @onVmNames;
	my $hostsRef = $self->hostsRef;
	foreach my $host (@$hostsRef) {
		if ( !$host->supportsPowerControl ) {
			$logger->debug( "Host " . $host->hostName . " does not support power control." );
			next;
		}

		$logger->debug( "Making sure that host " . $host->hostName . " is powered on" );

		# Figure out the actual vmName for the host from all of the possible
		# vmNames that might exist if there were multiple services assigned to
		# This host.
		my $vmName;
		if ( !$host->has_vmName() ) {
			my $possibleVmNamesRef = $host->possibleVmNamesRef;
			$logger->debug( "The possible VM names for  " . $host->hostName . " are @$possibleVmNamesRef" );
			foreach my $possibleVmName (@$possibleVmNamesRef) {
				if (   ( exists $vmNameToPowerstateHashRef->{$possibleVmName} )
					&& ( defined $vmNameToPowerstateHashRef->{$possibleVmName} ) )
				{

					# This is the vmName that the vi knows about
					$vmName = $possibleVmName;
					$logger->debug( "The actual VM name for  " . $host->hostName . " is $vmName." );
					$host->setVmName($vmName);
					last;
				}
			}

			if ( !$vmName ) {

				# None of the VMs was known to the vi.
				# Log the error and give up
				$console_logger->error(
					"The run harness determined that the list of possible VM names for host ",
					$host->hostName,
					" is @$possibleVmNamesRef,\n",
					" but none of those VM names are known to the virtual infrastructure."
				);
				exit(-1);
			}
		}
		else {
			$logger->debug( "The preknown VM name for  " . $host->hostName . " is $vmName." );
			$vmName = $host->vmName;
		}
		push( @onVmNames, $vmName );
	}

	if ( $powerOffVms || $powerOffAllVms ) {
		foreach my $vmName (@vmNames) {

			# If this should be on, skip it, otherwise turn it off
			if ( grep { $_ eq $vmName } @onVmNames ) {
				next;
			}
			elsif ( $powerOffAllVms || ( $vmName =~ /^$hostnamePrefix/ ) ) {
				my $powerState = $vmNameToPowerstateHashRef->{$vmName};
				if ( $powerState == 1 ) {
					$console_logger->info("Powering off $vmName\n");
					$virtualInfrastructure->powerOffVM($vmName);
					$tookPoweroffAction++;

				}
			}

		}
	}

	sleep 15;

	if ($powerOnVms) {
		for my $vmName (@onVmNames) {
			my $powerState = $vmNameToPowerstateHashRef->{$vmName};
			if ( $powerState == 0 ) {
				$console_logger->info("Powering on $vmName\n");
				$virtualInfrastructure->powerOnVM($vmName);
				$tookPoweronAction++;
			}
		}
	}

	if ($tookPoweronAction) {
		$console_logger->info(": Sleeping for 3 minutes to allow all VMs to start\n");
		sleep 180;
	}
}

sub cleanup {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");

	$self->cleanStatsFiles();
	$self->cleanLogFiles();

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
			  . $workload->getParamValue("workloadNum")
			  . ", Implementation: "
			  . $workload->getParamValue("workloadImpl");
		}
		$returnString .= $prefix . $workload->getNextRunInfo();
	}

	return $returnString;
}

# Sync time to the time on the host which is running the script
sub syncTime {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $console_logger = get_logger("Console");

	my $hostname = `hostname`;
	chomp($hostname);
	my $ipAddrsRef = getIpAddresses($hostname);

	# Make sure that ntpd is running on this host
	my $out = `service ntpd status 2>&1`;
	if ( !( $out =~ /Active:\sactive/ ) && !( $out =~ /is running/ ) ) {

		# try to start ntpd
		$logger->debug("ntpd is not running on $hostname, starting");
		$out = `service ntpd start 2>&1`;
		$out = `service ntpd status 2>&1`;
		if ( !( $out =~ /Active:\sactive/ ) && !( $out =~ /is running/ ) ) {
			$console_logger->debug("Could not start ntpd on $hostname, exiting.");
			exit(-1);
		}
	}

	# Create an ntp.conf that uses this host as the server
	open( FILEIN,  "/etc/ntp.conf" )  or die "Error opening/etc/ntp.conf:$!";
	open( FILEOUT, ">/tmp/ntp.conf" ) or die "Error opening /tmp/ntp.conf:$!";
	print FILEOUT "server $hostname iburst\n";
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /^\s*server\s/ ) {
			next;
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;

	foreach my $host ( @{ $self->hostsRef } ) {
		if ( $host->ipAddr ~~ @$ipAddrsRef ) {

			# Don't sync this host to itself
			$logger->debug( "Skipping syncing ", $host->hostName, " to itself." );
			next;
		}

		$host->restartNtp();

	}

}

sub checkVersions {
	my ($self)          = @_;
	my $logger          = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $console_logger  = get_logger("Console");
	my $weathervaneHome = $self->getParamValue('weathervaneHome');

	# Get this host's version number
	my $localVersion = `cat $weathervaneHome/version.txt 2>&1`;
	$logger->debug("For checkVersions.  localVersion is $localVersion");

	my $allSame = 1;
	foreach my $host ( @{ $self->hostsRef } ) {

		if (!$host->isNonDocker()) {
			next;
		}

		# Get the host's version number
		my $hostname         = $host->hostName;
		my $sshConnectString = $host->sshConnectString;
		my $version          = `$sshConnectString \"cat $weathervaneHome/version.txt\" 2>&1`;
		if ( $version =~ /No route/ ) {
			next;
		}
		$logger->debug("For checkVersions.  Version on $hostname is $version");

		# If different, update the weathervane directory on that host
		if ( $localVersion ne $version ) {
			$allSame = 0;
			$console_logger->info(
				"Warning: Version of Weathervane on host $hostname does not match that on local host.");
			$console_logger->info("Remote version is $version.  Local version is $localVersion.");
		}

	}

	return $allSame;
}

sub writeUsersTxt {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::RunProcedures::RunProcedure");
	my $tmpDir = $self->getParamValue('tmpDir');
	open( my $fileOut, ">$tmpDir/users.txt" ) or die "Error opening $tmpDir/users.txt:$!";

	my $workloadsRef = $self->workloadsRef;
	foreach my $workload (@$workloadsRef) {
		$workload->writeUsersTxt($fileOut);
	}
	close $fileOut;
}

sub checkUsersTxt {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::RunProcedures::RunProcedure");

	my $tmpDir = $self->getParamValue('tmpDir');
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
#	my $steadyState    = $self->getParamValue('steadyState');
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
#					my $workloadNum                     = $workloadRef->getParamValue('workloadNum');
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
#				my $workloadNum = $workloadRef->getParamValue('workloadNum');
#				foreach my $appInstance (@$appInstancesRef) {
#					$workloadNumHash{$numAppInstances}    = $workloadNum;
#					$appInstanceNumHash{$numAppInstances} = $appInstance->getParamValue("appInstanceNum");
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

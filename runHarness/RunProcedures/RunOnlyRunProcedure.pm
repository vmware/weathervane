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
package RunOnlyRunProcedure;

use Moose;
use MooseX::Storage;
use WeathervaneTypes;
use Parameters qw(getParamValue);
use POSIX;
use JSON;
use Log::Log4perl qw(get_logger);
use Utils qw(callMethodOnObjectsParallel callBooleanMethodOnObjectsParallel callMethodsOnObjectParallel);

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunProcedure';

has '+name' => ( default => 'Run-Only', );

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;

	super();
};

override 'run' => sub {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $debug_logger = get_logger("Weathervane::RunProcedures::RunOnlyRunProcedure");

	my $outputDir = $self->getParamValue('outputDir');
	my $tmpDir    = $self->getParamValue('tmpDir');

	# Add appender to the console log to put a copy in the tmpLog directory
	my $layout   = Log::Log4perl::Layout::PatternLayout->new("%d: %m%n");
	my $appender = Log::Log4perl::Appender->new(
		"Log::Dispatch::File",
		name     => "tmpdirConsoleFile",
		filename => "$tmpDir/console.log",
		mode     => "append",
	);
	$appender->layout($layout);
	$console_logger->add_appender($appender);

	my $sequenceNumberFile = $self->getParamValue('sequenceNumberFile');
	my $seqnum;
	if ( -e "$sequenceNumberFile" ) {
		open SEQFILE, "<$sequenceNumberFile";
		$seqnum = <SEQFILE>;
		close SEQFILE;
		$seqnum--;
	}
	else {
		if ( -e "$outputDir/0" ) {
			print
"Sequence number file is missing, but run 0 already exists in $outputDir\n";
			exit -1;
		}
		$seqnum = 0;
		open SEQFILE, ">$sequenceNumberFile";
		my $nextSeqNum = 1;
		print SEQFILE $nextSeqNum;
		close SEQFILE;
	}
	$self->seqnum($seqnum);

	# Make sure that no previous Benchmark processes are still running
	$debug_logger->debug("killOldWorkloadDrivers");
	$self->killOldWorkloadDrivers();

	# Now configure docker pinning if requested on any host
	$debug_logger->debug("configureDockerHostCpuPinning");
	$self->configureDockerHostCpuPinning();

	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();

	# configure the workload driver
	my $ok = callBooleanMethodOnObjectsParallel( 'configureWorkloadDriver',
		$self->workloadsRef );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Couldn't configure the workload driver properly.  Exiting.",
			$seqnum, $tmpDir, $outputDir );
		my $runResult = RunResult->new(
			'runNum'     => $seqnum,
			'isPassable' => 0,
		);

		return $runResult;
	}
	
	# Check that the users are the same as the number from the prepareOnly phase
	if (!$self->checkUsersTxt()) {
		exit;	
	}
	
	$console_logger->info("Starting run number $seqnum");

	# initialize the workload drivers
	$ok = $self->initializeWorkloads( $seqnum, $tmpDir );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Workload driver did not initialze properly.  Exiting.",
			$seqnum, $tmpDir, $outputDir );
		my $runResult = RunResult->new(
			'runNum'     => $seqnum,
			'isPassable' => 0,
		);

		return $runResult;

	}

	$ok = $self->runWorkloads( $seqnum, $tmpDir );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Workload driver did not start properly.  Exiting.",
			$seqnum, $tmpDir, $outputDir );
		my $runResult = RunResult->new(
			'runNum'     => $seqnum,
			'isPassable' => 0,
		);

		return $runResult;

	}

	## get stats that require services to be up

	# directory for logs related to start/stop/etc
	my $cleanupLogDir = $tmpDir . "/cleanupLogs";
	if ( !( -e $cleanupLogDir ) ) {
		`mkdir -p $cleanupLogDir`;
	}

	$console_logger->info(
"Stopping all services and collecting log and statistics files (if requested)."
	);

	## get the config files
	$self->getConfigFiles();

	## get the stats logs
	$self->getStatsFiles();

	my $sanityPassed = $self->sanityCheckServices($cleanupLogDir);
	if ($sanityPassed) {
		$console_logger->info("All Sanity Checks Passed");
	}
	else {
		$console_logger->info("Sanity Checks Failed");
	}

	if ( $self->getParamValue('stopServices') ) {
		## stop the services
		$self->stopFrontendServices($cleanupLogDir);
		$self->stopBackendServices($cleanupLogDir);

		# cleanup the databases
		$self->cleanData($cleanupLogDir);

		$self->stopDataServices($cleanupLogDir);
		$self->stopInfrastructureServices($cleanupLogDir);
		$self->unRegisterPortNumbers();

		## get the logs
		$self->getLogFiles();

		# Remove the services if they are dockerized
		$self->removeFrontendServices($cleanupLogDir);
		$self->removeBackendServices($cleanupLogDir);
		$self->removeDataServices($cleanupLogDir);
		$self->removeInfrastructureServices($cleanupLogDir);
		# clean up old logs and stats
		$self->cleanup();
	}
	else {
		## get the logs
		$self->getLogFiles();
	}

	# Put a file in the output/seqnum directory with the run name
	open RUNNAMEFILE, ">$tmpDir/description.txt"
	  or die "Can't open $tmpDir/description.txt: $!";
	print RUNNAMEFILE $self->getParamValue('description') . "\n";
	close RUNNAMEFILE;

	# record all of the parameter values used in a file
	# Save the original value of users, but include the right value for this run
	`mkdir -p $tmpDir/configuration/workloadDriver`;
	my $json = JSON->new;
	$json = $json->pretty(1);
	my $configText = $json->encode( $self->origParamHashRef );
	open CONFIGVALUESFILE, ">$tmpDir/configuration/weathervane.config.asRun"
	  or die
	  "Can't open $tmpDir/configuration/workloadDriver/weathervane.config.asRun: $!";
	print CONFIGVALUESFILE $configText;
	close CONFIGVALUESFILE;

	## for each service and the workload driver, parse stats
	# and gather up the headers and values for the results csv
	my $csvHashRef = $self->getStatsSummary($seqnum);

	my $resultsDir = "$outputDir/$seqnum";
	`mkdir -p $resultsDir`;
	`mv $tmpDir/* $resultsDir/.`;

	# Todo: Add parsing of logs for errors
	# my $isRunError = $self->parseLogs()
	my $isRunError = 0;

	my $isPassed = $self->isPassed($tmpDir) && $sanityPassed;

	my $runResult = RunResult->new(
		'runNum'                => $seqnum,
		'isPassable'            => 1,
		'isPassed'              => $isPassed,
		'runNum'                => $seqnum,
		'resultsDir'            => $resultsDir,
		'resultsSummaryHashRef' => $csvHashRef,

		#		'metricsHashRef'        => $self->workloadDriver->getResultMetrics(),
		'isRunError' => $isRunError,
	);

	return $runResult;

};

__PACKAGE__->meta->make_immutable;

1;

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
package FullRunProcedure;

use Moose;
use MooseX::Storage;
use RunProcedures::PrepareOnlyRunProcedure;
use WeathervaneTypes;
use Parameters qw(getParamValue);
use POSIX;
use JSON;
use Log::Log4perl qw(get_logger);
use Utils qw(callMethodOnObjectsParamListParallel1 callMethodOnObjectsParallel callBooleanMethodOnObjectsParallel callBooleanMethodOnObjectsParallel1 callMethodsOnObjectParallel);

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'PrepareOnlyRunProcedure';

has '+name' => ( default => 'Full-Run', );

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;

	super();
};

override 'run' => sub {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $debug_logger = get_logger("Weathervane::RunProcedures::FullRunProcedure");

	super();

	my $tmpDir = $self->tmpDir;
	my $seqnum = $self->seqnum;

	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();

	# configure the workload driver
	my $ok = callBooleanMethodOnObjectsParallel1( 'configureWorkloadDriver',
		$self->workloadsRef, $tmpDir );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Couldn't configure the workload driver properly.  Exiting.",
			$seqnum, $tmpDir );
		my $runResult = RunResult->new(
			'runNum'     => $seqnum,
			'isPassable' => 0,
		);

		return $runResult;
	}

	$console_logger->info("Starting run number $seqnum");

	# initialize the workload drivers
	$ok = $self->initializeWorkloads( $seqnum, $tmpDir );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Workload driver did not initialze properly.  Exiting.",
			$seqnum, $tmpDir );
		my $runResult = RunResult->new(
			'runNum'     => $seqnum,
			'isPassable' => 0,
		);

		return $runResult;

	}
	
	my $interactive = $self->getParamValue('interactive');
	if ($interactive) {
		$self->interactiveMode();
	}
	
	## start the workload driver and wait until it is done
	$ok = $self->runWorkloads( $seqnum, $tmpDir );
	if ( !$ok ) {
		$self->cleanupAfterFailure(
			"Workload driver did not start properly.  Exiting.",
			$seqnum, $tmpDir );
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
	$self->getConfigFiles($tmpDir);

	## get the stats files
	$self->getStatsFiles($tmpDir);

	## get the logs
	$self->getLogFiles($tmpDir);

	my $sanityPassed = 1;

	if ( $self->getParamValue('stopServices') ) {

		## stop the services
		$self->stopDataManager($cleanupLogDir);
		
		my @tiers = qw(frontend backend data infrastructure);
		callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $cleanupLogDir );

 		$sanityPassed = $self->sanityCheckServices($cleanupLogDir);
		if ($sanityPassed) {
			$console_logger->info("All Sanity Checks Passed");
		}
		else {
			$console_logger->info("Sanity Checks Failed");
		}

		# clean up old logs and stats
		$self->cleanup($cleanupLogDir);
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
	my $csvHashRef = $self->getStatsSummary($seqnum, $tmpDir);

	# Todo: Add parsing of logs for errors
	# my $isRunError = $self->parseLogs()
	my $isRunError = 0;

	my $isPassed = $self->isPassed($tmpDir) && $sanityPassed;
	
	# Stop the workload drivers
	$self->stopWorkloads( $seqnum, $tmpDir );

	my $runResult = RunResult->new(
		'runNum'                => $seqnum,
		'isPassable'            => 1,
		'isPassed'              => $isPassed,
		'runNum'                => $seqnum,
		'resultsSummaryHashRef' => $csvHashRef,

		#		'metricsHashRef'        => $self->workloadDriver->getResultMetrics(),
		'isRunError' => $isRunError,
	);

	return $runResult;

};

__PACKAGE__->meta->make_immutable;

1;

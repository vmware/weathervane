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
package PrepareOnlyRunProcedure;

use Moose;
use MooseX::Storage;
use RunProcedures::RunProcedure;
use WeathervaneTypes;
use RunResults::RunResult;
use JSON;
use Log::Log4perl qw(get_logger);
use Utils qw(callMethodOnObjectsParallel callMethodsOnObjectParallel callMethodsOnObjectParallel1 callMethodOnObjectsParallel1 callMethodOnObjectsParallel2);

use Parameters qw(getParamValue setParamValue);

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunProcedure';

has '+name' => ( default => 'Prepare-Only', );

has 'loadDb' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'reloadDb' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'backup' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'rebackup' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'isPowerControl' => (
	is  => 'rw',
	isa => 'Bool',
);

has 'isUpRetries' => (
	is  => 'rw',
	isa => 'Int',
);

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;

	super();
};

sub run {
	my ( $self ) = @_;
	my $runLog             = $self->runLog;
	my $sequenceNumberFile = $self->getParamValue('sequenceNumberFile');
	my $outputDir          = $self->getParamValue('outputDir');
	my $tmpDir             = $self->getParamValue('tmpDir');
	my $weathervaneHome    = $self->getParamValue('weathervaneHome');
	my $console_logger     = get_logger("Console");
	my $debug_logger       = get_logger("Weathervane::RunProcedures::PrepareOnlyRunProcedure");
	my @pids;
	my $pid;

	# Get the sequence number of the next run
	my $seqnum;
	if ( -e "$sequenceNumberFile" ) {
		open SEQFILE, "<$sequenceNumberFile";
		$seqnum = <SEQFILE>;
		close SEQFILE;
		if ( -e "$outputDir/$seqnum" ) {
			print "Next run number is $seqnum, but directory for run $seqnum already exists in $outputDir\n";
			exit -1;
		}
		open SEQFILE, ">$sequenceNumberFile";
		my $nextSeqNum = $seqnum + 1;
		print SEQFILE $nextSeqNum;
		close SEQFILE;
	}
	else {
		if ( -e "$outputDir/0" ) {
			print "Sequence number file is missing, but run 0 already exists in $outputDir\n";
			exit -1;
		}
		$seqnum = 0;
		open SEQFILE, ">$sequenceNumberFile";
		my $nextSeqNum = 1;
		print SEQFILE $nextSeqNum;
		close SEQFILE;
	}
	$self->seqnum($seqnum);
	
	# clean out the tmp directory
	`rm -r $tmpDir/* 2>&1`;

	# directory for logs related to start/stop/etc
	my $setupLogDir = $tmpDir . "/setupLogs";
	if ( !( -e $setupLogDir ) ) {
		`mkdir -p $setupLogDir`;
	}

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

	## power control.
	if ( $self->getParamValue('powerOnVms') || $self->getParamValue('powerOffVms') ) {
		$debug_logger->debug("doPowerControl");
		$self->doPowerControl();

		# Only do powercontrol the first run
		$self->setParamValue( 'powerOnVms',  0 );
		$self->setParamValue( 'powerOffVms', 0 );
	}
	
	$console_logger->info("Stopping running services and cleaning up old log and stats files.\n");

	# Make sure that no previous Benchmark processes are still running
	$debug_logger->debug("killOldWorkloadDrivers");
	$self->killOldWorkloadDrivers();

	$debug_logger->debug("stop services");
	my @methods = qw(stopInfrastructureServices stopFrontendServices stopBackendServices stopDataServices);
	callMethodsOnObjectParallel1( \@methods, $self, $setupLogDir );
	$debug_logger->debug("Unregister port numbers");
	$self->unRegisterPortNumbers();
	
	$debug_logger->debug("cleanup");
	$self->cleanup();

	# Get rid of old results from previous run
	$debug_logger->debug("clear results");
	$self->clearResults();

	# Remove the services if they are dockerized
	$debug_logger->debug("Remove services");
	@methods = qw(removeFrontendServices removeBackendServices removeDataServices removeInfrastructureServices);
	callMethodsOnObjectParallel1( \@methods, $self, $setupLogDir );

	# redeploy artifacts if selected
	if ( $self->getParamValue('redeploy') ) {
		$console_logger->info("Redeploying artifacts for application and workload-driver nodes");
		callMethodOnObjectsParallel2( 'redeploy', $self->workloadsRef, $setupLogDir, $self->hostsRef );
		$self->setParamValue( 'redeploy', 0 );
	}
	
	# Make sure that all hosts are running the same version of Weathervane
	my $allSame = $self->checkVersions();
	if (!$allSame) {
		$console_logger->info("Mismatching Weathervane versions detected.");		
		$console_logger->info("To synchronize the version of Weathervane on all hosts to match the local host, use the --redeploy flag.");
		exit;		
	}
	
	# Copy the version file into the output directory
	`cp $weathervaneHome/version.txt $tmpDir/version.txt`;
	
	# Make sure time is synced on all hosts
	if ( $self->getParamValue('restartNtp') ) {
		$debug_logger->debug("Sync time");
		$self->syncTime();
	}	
	
	# Prepare the data for this run and start the data services
	$console_logger->info("Preparing data for use in current run.\n");
	my $dataPrepared = $self->prepareData($setupLogDir);
	if ( !$dataPrepared ) {
		$self->cleanupAfterFailure( "Could not properly load or prepare data for run $seqnum.  Exiting.", $seqnum, $tmpDir, $outputDir );
	}

	$self->clearReloadDb();

	## start all of the backend services.  Data services should be up.
	$console_logger->info("Starting data services");
	$self->configureAndStartDataServices( $setupLogDir );
	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();
	sleep 30;

	$console_logger->info("Pre-warming data services.\n");
	$self->pretouchData($setupLogDir);

	$console_logger->info("Starting backend services");
	$self->configureAndStartBackendServices( $setupLogDir );
	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();

	$console_logger->info("Starting frontend services");
	$self->configureAndStartFrontendServices( $setupLogDir );
	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();

	$console_logger->info("Starting infrastructure services");
	$self->configureAndStartInfrastructureServices( $setupLogDir );
	# Make sure that the services know their external port numbers
	$self->setExternalPortNumbers();

	# Make sure that all of the services are up
	$debug_logger->debug("Check isUp");
	my $allUp = $self->isUp($setupLogDir);
	if ( !$allUp ) {
		$self->cleanupAfterFailure( "Couldn't start all application services for run $seqnum. Exiting.", $seqnum, $tmpDir, $outputDir );
	}

	# Write users.txt
	$self->writeUsersTxt();
	
	my $runResult = RunResult->new(
		'runNum'     => $seqnum,
		'isPassable' => 0,
	);

	return $runResult;

}

__PACKAGE__->meta->make_immutable;

1;

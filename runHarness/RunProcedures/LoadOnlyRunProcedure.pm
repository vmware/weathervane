# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package LoadOnlyRunProcedure;

use Moose;
use MooseX::Storage;
use RunProcedures::RunProcedure;
use WeathervaneTypes;
use RunResults::RunResult;
use JSON;
use Log::Log4perl qw(get_logger);
use Utils qw(callMethodOnObjectsParamListParallel1 callMethodOnObjectsParallel2 callMethodOnObjectsParallel callMethodsOnObjectParallel callMethodsOnObjectParallel1 callMethodOnObjectsParallel1);

use Parameters qw(getParamValue setParamValue);

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunProcedure';

has '+name' => ( default => 'Load-Only', );

has 'reloadDb' => (
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
	my $majorSequenceNumberFile = $self->getParamValue('sequenceNumberFile');
	my $tmpDir             = $self->getParamValue('tmpDir');
	my $console_logger     = get_logger("Console");
	my $debug_logger       = get_logger("Weathervane::RunProcedures::PrepareOnlyRunProcedure");
	my @pids;
	my $pid;

	# Get the major sequence number
	my $majorSeqNum;
	if ( -e "$majorSequenceNumberFile" ) {
		open SEQFILE, "<$majorSequenceNumberFile";
		$majorSeqNum = <SEQFILE>;
		close SEQFILE;
		$majorSeqNum--; #already incremented in weathervane.pl
	} else {
		print "Major sequence number file is missing.\n";
		exit -1;
	}
	# Get the minor sequence number of the next run
	my $minorSequenceNumberFile = "$tmpDir/minorsequence.num";
	my $minorSeqNum;
	if ( -e "$minorSequenceNumberFile" ) {
		open SEQFILE, "<$minorSequenceNumberFile";
		$minorSeqNum = <SEQFILE>;
		close SEQFILE;
		open SEQFILE, ">$minorSequenceNumberFile";
		my $nextSeqNum = $minorSeqNum + 1;
		print SEQFILE $nextSeqNum;
		close SEQFILE;
	}
	else {
		$minorSeqNum = 0;
		open SEQFILE, ">$minorSequenceNumberFile";
		my $nextSeqNum = 1;
		print SEQFILE $nextSeqNum;
		close SEQFILE;
	}
	my $seqnum = $majorSeqNum . "-" . $minorSeqNum;
	$self->seqnum($seqnum);

	# Now send all output to new subdir 	
	$tmpDir = "$tmpDir/$minorSeqNum";
	if ( !( -e $tmpDir ) ) {
		`mkdir $tmpDir`;
	}
	
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
	
	$console_logger->info("Stopping running services and cleaning up old log and stats files.\n");

	# Make sure that no previous Benchmark processes are still running
	$debug_logger->debug("killOldWorkloadDrivers");
	$self->killOldWorkloadDrivers($setupLogDir);

	$debug_logger->debug("stop services");
	$self->stopDataManager($setupLogDir);		
	$self->stopServicesInClusters();
	my @tiers = qw(frontend backend data infrastructure);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $setupLogDir );
	
	$debug_logger->debug("cleanup logs and stats files on hosts, virtual infrastructures, and workload drivers");
	$self->cleanup($setupLogDir);

	# redeploy artifacts if selected
	if ( $self->getParamValue('redeploy') ) {
		$console_logger->info("Redeploying artifacts for application and workload-driver nodes");
		callMethodOnObjectsParallel2( 'redeploy', $self->workloadsRef, $setupLogDir, $self->hostsRef );
		$self->setParamValue( 'redeploy', 0 );
	}

	# Prepare the data for this run and start the data services
	# Start the data services for all AppInstances.  This happens serially so
	# that we don't have to spawn processes and lose port number info.
	$self->prepareDataServices($setupLogDir);	
	# Prepare the data for this run.  This happens in parallel on all appInstances
	$console_logger->info("Preparing data for use in current run.\n");
	my $dataPrepared = $self->prepareData($setupLogDir);
	if ( !$dataPrepared ) {
		$self->cleanupAfterFailure( "Could not properly load or prepare data for run $seqnum.  Exiting.", $seqnum, $tmpDir );
	}

	$self->clearReloadDb();

	my $runResult = RunResult->new(
		'runNum'     => $seqnum,
		'isPassable' => 0,
	);

	return $runResult;

}

__PACKAGE__->meta->make_immutable;

1;

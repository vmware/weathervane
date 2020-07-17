# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package MixedRunManager;

use Moose;
use MooseX::Storage;
use RunManagers::RunManager;
use WeathervaneTypes;
use RunResults::RunResult;
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunManager';

has '+name' => ( default => 'Mixed Run Strategy', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ( $self ) = @_;

	super();
};

override 'setRunProcedure' => sub {
	my ( $self, $runProcedureRef ) = @_;

	my $runProcedureType = $runProcedureRef->getRunProcedureImpl();

	my @runProcedures = @WeathervaneTypes::runProcedures;
	if ( !( $runProcedureType ~~ @runProcedures ) ) {
		die "MixedRunManager::initialize: $runProcedureType is not a valid run procedure.  Must be one of @runProcedures";
	}


	super();
};

override 'start' => sub {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $debug_logger = get_logger("Weathervane::RunManager::MixedRunManager");
	
	# For a mixed runStrategy, there are a few restrictions:
	#   - There can only be one workload
	#   - If any appInstance uses findmax or syncedfindmax loadpathtype, then 
	#     passing only depends on the findmax instances.  Therefore none of the
	#     fixed appInstances will be passable.
	my $workloadsRef = $self->runProcedure->workloadsRef;
	if ((scalar @$workloadsRef) != 1) {
		$console_logger->error("When running with the mixed runStrategy, there can only be one workload.");
		exit 1;	
	}
	
	my $hasFindMax = 0;
	my $appInstancesRef = $workloadsRef->[0]->appInstancesRef;
	foreach my $appInstance (@$appInstancesRef) {
		my $loadPathType = $appInstance->getParamValue('loadPathType');	
		if (($loadPathType eq "findmax") || ($loadPathType eq "syncedfindmax")) {
			$hasFindMax = 1;
		}
	}
	foreach my $appInstance (@$appInstancesRef) {
		my $loadPathType = $appInstance->getParamValue('loadPathType');	
		if ($hasFindMax && ($loadPathType ne "findmax") && ($loadPathType ne "syncedfindmax")) {
			$appInstance->isPassable(0);;
		}
	}
	
	$console_logger->info($self->name . " starting run.");

	my $runResult = $self->runProcedure->run();

	my $runProcedureType = $self->runProcedure->getRunProcedureImpl();
	if ( $runProcedureType eq 'prepareOnly' ) {
		$console_logger->info("Application configured and running. ");
	}
	elsif ( $runProcedureType eq 'stop' ) {
		$console_logger->info("Run stopped");
	}
	else {
		$self->printCsv( $runResult->resultsSummaryHashRef, 1 );
		$console_logger->info($runResult->toString());
	}
	Log::Log4perl->eradicate_appender("tmpdirConsoleFile");

};

__PACKAGE__->meta->make_immutable;

1;

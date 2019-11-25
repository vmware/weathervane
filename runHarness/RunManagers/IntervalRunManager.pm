# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package IntervalRunManager;

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

has '+name' => ( default => 'Interval Run Strategy', );

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
		die "SingleFixedRunManager::initialize: $runProcedureType is not a valid run procedure.  Must be one of @runProcedures";
	}


	super();
};

override 'start' => sub {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $debug_logger = get_logger("Weathervane::RunManager::SingleFixedRunManager");

	$self->runProcedure->setLoadPathType("interval");

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

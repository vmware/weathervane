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
package FindMaxMultiAIRunManager;

use Moose;
use MooseX::Storage;
use RunManagers::RunManager;
use RunResults::RunResult;
use WeathervaneTypes;
use POSIX;
use Log::Log4perl qw(get_logger);
use Parameters qw(getParamValue setParamValue);
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunManager';

has '+name' => ( default => 'Find-Max RunManager', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ( $self ) = @_;

	# Check whether the runprocedure is valid for this run manager.
	# The actual creation happens in the superclass
	my $runProcedureType = $self->getParamValue( "runProcedure" );

	my @runProcedures = @WeathervaneTypes::runProcedures;
	if ( !( $runProcedureType ~~ @runProcedures ) ) {
		die "FindMaxFixedRunManager::initialize: $runProcedureType is not a valid run procedure.  Must be one of @runProcedures";
	}

	if ( $runProcedureType eq 'prepareOnly' ) {
		die "$runProcedureType is not a valid run procedure for the FindMax run manager";
	}

	super();
};

override 'start' => sub {
	my ($self) = @_;
	my $console_logger     = get_logger("Console");
	my $logger       = get_logger("Weathervane::RunManagers::FindMaxFixedRunManager");

	$self->runProcedure->setLoadPathType("findmax");

	# Do the run/maximum-finding $repeatsAtMax+1 times.
	# For maximum finding, on repeats the runs will start at the previous maximum.
	for ( my $i = 0 ; $i <= $self->getParamValue('repeatsAtMax') ; $i++ ) {
		my $foundMax    = 0;
		my $minFail     = 9999999;
		my $maxPass     = 0;
		my $printHeader = 1;

		if ($i > 0) {
			$self->runProcedure->resetFindMax();
			$console_logger->info("Repeating at maximum with:\n" . $self->runProcedure->getFindMaxInfoString());
		}

		while ( !($foundMax) ) {

			# now do the run
			my $nextRunInfo = $self->runProcedure->getNextRunInfo();
			$console_logger->info($self->name . " starting run" . $nextRunInfo);

			my $runResult = $self->runProcedure->run( );
			$console_logger->info($runResult->toString());
			$self->printCsv( $runResult->resultsSummaryHashRef, $printHeader );
			$printHeader = 0;

			if ( $runResult->isRunError ) {

				# Was some error in this run.
				$console_logger->error("Was an error in the run.  Check the logs and try again");
				exit(-1);
			}
			
			$foundMax = $self->runProcedure->foundMax();
			if (!$foundMax) {
				$self->runProcedure->adjustUsersForFindMax();
			}

			Log::Log4perl->eradicate_appender("tmpdirConsoleFile");
			
		}
	}

};

__PACKAGE__->meta->make_immutable;

1;

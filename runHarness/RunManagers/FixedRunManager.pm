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
package FixedRunManager;

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

has '+name' => ( default => 'Fixed Run Strategy', );

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
	# Fixed run strategy uses fixed load-paths only
	$self->setLoadPathType("fixed");

	$console_logger->info($self->name . " starting run.");

	my $runResult = $self->runProcedure->run();

	my $runProcedureType = $self->runProcedure->getRunProcedureImpl();
	if ( $runProcedureType eq 'prepareOnly' ) {
		$console_logger->info("Application configured and running.  Connect with a browser to http://www.weathervane");
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

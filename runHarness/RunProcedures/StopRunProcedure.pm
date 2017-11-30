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
package StopRunProcedure;

use Moose;
use MooseX::Storage;
use WeathervaneTypes;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);
use Utils qw(callMethodOnObjectsParamListParallel1 callMethodsOnObjectParallel callMethodsOnObjectParallel1);

use strict;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'RunProcedure';

has '+name' => ( default => 'Stop', );

override 'initialize' => sub {
	my ( $self, $paramHashRef ) = @_;

	super();
};

override 'run' => sub {
	my ( $self, $users, $workloadDriver ) = @_;
	my $console_logger = get_logger("Console");
	my $debug_logger   = get_logger("Weathervane::RunProcedures::StopRunProcedure");
	my $tmpDir         = $self->getParamValue('tmpDir');

	# Kill any instances of the run script
	$console_logger->info("Stopping run-script processes");
	open my $ps, "ps x | grep weathervane.pl | grep -v grep |"
	  or die "Can't open pipe to ps output : $!";
	while ( my $inline = <$ps> ) {
		if ( ( $inline =~ /^\s*(\d+)\s/ ) && ( $1 != $$ ) ) {
			my $out = `kill $1`;
		}
	}
	close $ps;

	$console_logger->info("Stopping running workload-drivers");
	$self->killOldWorkloadDrivers();

	## stop the services
	my @tiers = qw(frontend backend data infrastructure);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $tmpDir );

	$debug_logger->debug("Unregister port numbers");
	$self->unRegisterPortNumbers();

	# clean up old logs and stats
	$self->cleanup();
	
	# clean out the tmp directory
	`rm -r $tmpDir/* 2>&1`;

	my $runResult = RunResult->new(
		'runNum'     => '-1',
		'isPassable' => 0,
	);

	return $runResult;

};

__PACKAGE__->meta->make_immutable;

1;

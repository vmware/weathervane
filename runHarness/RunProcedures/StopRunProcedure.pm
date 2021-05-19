# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
	$self->killOldWorkloadDrivers("/tmp");

	## stop the services
	$self->stopDataManager($tmpDir);
	$self->stopServicesInClusters();
	my @tiers = qw(frontend);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $tmpDir );
	@tiers = qw(backend);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $tmpDir );
	@tiers = qw(data infrastructure);
	callMethodOnObjectsParamListParallel1( "stopServices", [$self], \@tiers, $tmpDir );

	# clean up old logs and stats
	$self->cleanup($tmpDir);
	
	my $runResult = RunResult->new(
		'runNum'     => '-1',
		'isPassable' => 0,
	);

	return $runResult;

};

__PACKAGE__->meta->make_immutable;

1;

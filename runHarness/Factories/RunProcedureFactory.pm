# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RunProcedureFactory;

use Moose;
use MooseX::Storage;
use RunProcedures::FullRunProcedure;
use RunProcedures::StopRunProcedure;
use RunProcedures::PrepareOnlyRunProcedure;
use RunProcedures::LoadOnlyRunProcedure;
use RunProcedures::RunOnlyRunProcedure;
use Parameters qw(getParamValue);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getRunProcedure {
	my (
		$self, $paramHashRef
	) = @_;

	my $runProcedureType = $paramHashRef->{'runProcedure'};

	my $runProcedure;
	if ( $runProcedureType eq "full" ) {
		$runProcedure = FullRunProcedure->new( 'paramHashRef' => $paramHashRef );
	}
	elsif ( $runProcedureType eq "prepareOnly" ) {
		$runProcedure = PrepareOnlyRunProcedure->new( 'paramHashRef' => $paramHashRef );
	}
	elsif ( $runProcedureType eq "loadOnly" ) {
		$runProcedure = LoadOnlyRunProcedure->new( 'paramHashRef' => $paramHashRef );
	}
	elsif ( $runProcedureType eq "runOnly" ) {
		$runProcedure = RunOnlyRunProcedure->new( 'paramHashRef' => $paramHashRef );
	}
	elsif ( $runProcedureType eq "stop" ) {
		$runProcedure = StopRunProcedure->new( 'paramHashRef' => $paramHashRef );
	}
	else {
		die "No matching run manager for run-procedure type $runProcedureType available to RunProcedureFactory";
	}

	$runProcedure->initialize();

	return $runProcedure;
}

__PACKAGE__->meta->make_immutable;

1;

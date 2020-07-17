# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RunManagerFactory;

use Moose;
use MooseX::Storage;
use RunManagers::FixedRunManager;
use RunManagers::IntervalRunManager;
use RunManagers::FindMaxSingleRunRunManager;
use RunManagers::FindMaxMultiRunRunManager;
use RunManagers::FindMaxSingleRunWithScalingRunManager;
use RunManagers::FindMaxMultiAIRunManager;
use RunManagers::MixedRunManager;
use Parameters qw(getParamValue);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getRunManager {
	my ( $self, $paramsHashRef ) = @_;

	my $runManager;
	my $runStrategy = $paramsHashRef->{'runStrategy'};
	if (($runStrategy eq 'fixed' ) || ($runStrategy eq 'single' )) {
		$runManager =
		  FixedRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'interval' ) {
		$runManager =
		  IntervalRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif (($runStrategy eq 'findMaxSingleRun') || ($runStrategy eq 'findMaxSingleRunSync')) {
		$runManager =
		  FindMaxSingleRunRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'findMaxSingleRunWithScaling' ) {
		$runManager =
		  FindMaxSingleRunWithScalingRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'findMaxMultiAI' ) {
		$runManager =
		  FindMaxMultiAIRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif (( $runStrategy eq 'findMaxMultiRun' ) || ($runStrategy eq 'findMax' )) {
		$runManager =
		  FindMaxMultiRunRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ($runStrategy eq 'mixed' ) {
		$runManager =
		  MixedRunManager->new( 'paramHashRef' => $paramsHashRef );
	}
	else {
		die
"No matching run manager for run strategy $runStrategy available to RunManagerFactory";
	}

	$runManager->initialize();

	return $runManager;
}

__PACKAGE__->meta->make_immutable;
1;

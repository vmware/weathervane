# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package RunStrategyFactory;

use Moose;
use MooseX::Storage;
use RunStrategies::FixedRunStrategy;
use RunStrategies::IntervalRunStrategy;
use RunStrategies::FindMaxSingleRunRunStrategy;
use RunStrategies::FindMaxMultiRunRunStrategy;
use RunStrategies::FindMaxSingleRunWithScalingRunStrategy;
use RunStrategies::FindMaxMultiAIRunStrategy;
use Parameters qw(getParamValue);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getRunStrategy {
	my ( $self, $paramsHashRef ) = @_;

	my $RunStrategy;
	my $runStrategy = $paramsHashRef->{'runStrategy'};
	if (($runStrategy eq 'fixed' ) || ($runStrategy eq 'single' )) {
		$RunStrategy =
		  FixedRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'interval' ) {
		$RunStrategy =
		  IntervalRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif (($runStrategy eq 'findMaxSingleRun') 
		|| ($runStrategy eq 'findMax' )
		|| ($runStrategy eq 'findMaxSingleRunSync')) {
		$RunStrategy =
		  FindMaxSingleRunRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'findMaxSingleRunWithScaling' ) {
		$RunStrategy =
		  FindMaxSingleRunWithScalingRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'findMaxMultiAI' ) {
		$RunStrategy =
		  FindMaxMultiAIRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	elsif ( $runStrategy eq 'findMaxMultiRun' ) {
		$RunStrategy =
		  FindMaxMultiRunRunStrategy->new( 'paramHashRef' => $paramsHashRef );
	}
	else {
		die
"No matching run manager for run strategy $runStrategy available to RunStrategyFactory";
	}

	$RunStrategy->initialize();

	return $RunStrategy;
}

__PACKAGE__->meta->make_immutable;
1;

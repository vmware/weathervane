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
package RunManagerFactory;

use Moose;
use MooseX::Storage;
use RunManagers::FixedRunManager;
use RunManagers::IntervalRunManager;
use RunManagers::FindMaxSingleRunRunManager;
use RunManagers::FindMaxMultiRunRunManager;
use RunManagers::FindMaxSingleRunWithScalingRunManager;
use RunManagers::FindMaxMultiAIRunManager;
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
	elsif ( $runStrategy eq 'findMaxSingleRun' ) {
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
	else {
		die
"No matching run manager for run strategy $runStrategy available to RunManagerFactory";
	}

	$runManager->initialize();

	return $runManager;
}

__PACKAGE__->meta->make_immutable;
1;

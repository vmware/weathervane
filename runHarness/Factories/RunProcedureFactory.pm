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

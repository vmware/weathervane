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
package DataManagerFactory;

use Moose;
use MooseX::Storage;
use DataManagers::AuctionDataManager;
use DataManagers::AuctionKubernetesDataManager;
use Parameters qw(getParamValue);
use WeathervaneTypes;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getDataManager {
	my ( $self, $paramHashRef, $appInstance ) = @_;
	my $workloadType = $paramHashRef->{"workloadImpl"};

	if ( !( $workloadType ~~ @WeathervaneTypes::workloadImpls ) ) {
		die "No matching dataManager for workload type $workloadType";

	}

	my $dataManager;
	if ( $workloadType eq "auction" ) {
		if ($paramHashRef->{'clusterName'}) {
			if ($paramHashRef->{'clusterType'} eq 'kubernetes') {
				$dataManager = AuctionKubernetesDataManager->new( 'paramHashRef' => $paramHashRef,
				'appInstance' => $appInstance );
			} 
		} else {
			$dataManager = AuctionDataManager->new( 'paramHashRef' => $paramHashRef,
			'appInstance' => $appInstance );
		}
	}
	else {
		die "No matching workloadDriver for workload type $workloadType";
	}

	$dataManager->initialize($paramHashRef);

	return $dataManager;
}

__PACKAGE__->meta->make_immutable;

1;

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
package HostFactory;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use Moose::Util qw( apply_all_roles );
use Hosts::LinuxGuest;
use Hosts::DockerRole;
use Hosts::VICHost;
use Hosts::ESXiHost;
use Hosts::VirtualCenterHost;
use Parameters qw(getParamValue);
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

sub getHost {
	my ( $self, $paramsHashRef ) = @_;
	my $logger = get_logger("Weathervane::Factories::HostFactory");
	my $host;	
	my $isVIC = $paramsHashRef->{'vicHost'};	
	my $hostname = $paramsHashRef->{'hostName'};
	
	if ($isVIC) {
		$logger->debug("Creating a VIC Host with hostname $hostname");
		$host = VICHost->new(
			'paramHashRef' => $paramsHashRef,);
	} else {
		$logger->debug("Creating a Linux Host with hostname $hostname");
		$host = LinuxGuest->new(
			'paramHashRef' => $paramsHashRef,);
	}
	$host->initialize();

	apply_all_roles($host, 'DockerRole');		

	return $host;
}

sub getVIHost{
	my ( $self, $paramHashRef) = @_;
	my $host;
	my $viType = $paramHashRef->{'virtualInfrastructureType'};

	if ( $viType eq "vsphere" ) {
		$host = ESXiHost->new(
			'paramHashRef' => $paramHashRef,

		);
	}
	else {
		die "No matching virtualInfrastructure type available to hostFactory";
	}

	$host->initialize();

	return $host;
}

sub getVIMgmtHost {
	my ( $self, $paramHashRef) = @_;
	my $host;
	my $viType = $paramHashRef->{'virtualInfrastructureType'};
	if ( $viType eq "vsphere" ) {
		$host = VirtualCenterHost->new(
			'paramHashRef' => $paramHashRef,
		);
	}
	else {
		die "No matching virtualInfrastructure type available to hostFactory";
	}

	$host->initialize();

	return $host;
}
__PACKAGE__->meta->make_immutable;

1;

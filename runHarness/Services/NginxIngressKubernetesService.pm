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
package NginxIngressKubernetesService;

use Moose;
use MooseX::Storage;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'NginxIngress', );

has '+version' => ( default => '', );

has '+description' => ( default => 'Nginx Ingress', );


override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxIngressKubernetesService");
	$logger->debug("Configure Nginx Ingress");
	print $dblog "Configure Nginx Ingress\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	open( FILEIN,  "$configDir/kubernetes/ingressControllerNginx.yaml" ) or die "$configDir/kubernetes/ingressControllerNginx.yaml: $!\n";
	open( FILEOUT, ">/tmp/ingressControllerNginx-$namespace.yaml" )             or die "Can't open file /tmp/ingressControllerNginx-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /(\s+)namespace:)/ ) {
			print FILEOUT "${1}namespace: $namespace\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;
	
		

}

override 'isUp' => sub {
	my ($self, $fileout) = @_;
	
	my $cluster = $self->host;
	return $cluster->kubernetesGetIngressIp("type=appInstance", $self->namespace)
};

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::NginxIngressKubernetesService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/ingressControllerNginx-$namespace.yaml $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

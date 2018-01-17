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
package NginxKubernetesService;

use Moose;
use MooseX::Storage;

use Services::KubernetesService;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'Nginx', );

has '+version' => ( default => '1.7.xx', );

has '+description' => ( default => 'Nginx Web Server', );


override 'initialize' => sub {
	my ( $self ) = @_;
	super();
};

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::NginxService");
	$logger->debug("Configure Nginx kubernetes");
	print $dblog "Configure Nginx Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $workerConnections = ceil( $self->getParamValue('frontendConnectionMultiplier') * $users / ( $self->appInstance->getNumActiveOfServiceType('webServer') * 1.0 ) );
	if ( $workerConnections < 100 ) {
		$workerConnections = 100;
	}
	if ( $self->getParamValue('nginxWorkerConnections') ) {
		$workerConnections = $self->getParamValue('nginxWorkerConnections');
	}
	my $perServerConnections = floor( 50000.0 / $self->appInstance->getNumActiveOfServiceType('appServer') );

	open( FILEIN,  "$configDir/kubernetes/nginx.yaml" ) or die "$configDir/kubernetes/nginx.yaml: $!\n";
	open( FILEOUT, ">/tmp/nginx-$namespace.yaml" )             or die "Can't open file /tmp/nginx-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /WORKERCONNECTIONS:/ ) {
			print FILEOUT "  WORKERCONNECTIONS: \"$workerConnections\"\n";
		}
		elsif ( $inline =~ /PERSERVERCONNECTIONS:/ ) {
			print FILEOUT "  PERSERVERCONNECTIONS: \"$perServerConnections\"\n";
		}
		elsif ( $inline =~ /KEEPALIVETIMEOUT:/ ) {
			print FILEOUT "  KEEPALIVETIMEOUT: \"" . $self->getParamValue('nginxKeepaliveTimeout') . "\"\n";
		}
		elsif ( $inline =~ /MAXKEEPALIVEREQUESTS:/ ) {
			print FILEOUT "  MAXKEEPALIVEREQUESTS: \"" . $self->getParamValue('nginxMaxKeepaliveRequests') . "\"\n";
		}
		elsif ( $inline =~ /IMAGESTORETYPE:/ ) {
			print FILEOUT "  IMAGESTORETYPE: \"" . $self->getParamValue('imageStoreType') . "\"\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	
	close FILEIN;
	close FILEOUT;
	
		

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;


}


sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::NginxDockerService");
	$logger->debug("cleanLogFiles");

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"nginxKeepaliveTimeout"}     = $self->getParamValue('nginxKeepaliveTimeout');
	$csv{"nginxMaxKeepaliveRequests"} = $self->getParamValue('nginxMaxKeepaliveRequests');
	$csv{"nginxWorkerConnections"}    = $self->getParamValue('nginxWorkerConnections');
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

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
package AuctionAppInstance;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use POSIX;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);
use AppInstance::AuctionAppInstance;
use Clusters::Cluster;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'AuctionAppInstance';

has 'namespace' => (
	is  => 'ro',
	isa => 'Str',
);

has 'host' => (
	is  => 'rw',
	isa => 'Cluster',
);

override 'initialize' => sub {
	my ($self) = @_;
	
	$self->namespace("auctionw" . $self->getParamValue('workloadNum') . "i" . $self->getParamValue('appInstanceNum'));
	
	
	super();

};

sub setHost {
	my ($self, $host) = @_;
	
	$self->host($host);

	my $namespace = $self->namespace;
	
	# Create the namespace and the namespace-wide resources
	open( FILEIN,  "$configDir/kubernetes/namespace.yaml" ) or die "$configDir/kubernetes/namespace.yaml: $!\n";
	open( FILEOUT, ">/tmp/namespace-$namespace.yaml" )             or die "Can't open file /tmp/namespace-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {
		if ( $inline =~ /\s\sname:/ ) {
			print FILEOUT "  name: $namespace\n";
		}
		else {
			print FILEOUT $inline;
		}
	}
	close FILEIN;
	close FILEOUT;
	$host->kubernetesApply("/tmp/namespace-$namespace.yaml", $self->namespace);
		
}

override 'redeploy' => sub {
	my ( $self, $logfile ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	$logger->debug(
		"redeploy for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",         $self->getParamValue('appInstanceNum')
	);

	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $distDir         = $self->getParamValue('distDir');

	# Refresh the docker images on all of the servers
	$logger->debug("Redeploy by docker pull for services that are running on docker.");
	my $workloadImpl    = $self->getParamValue('workloadImpl');
	my $serviceTypesRef = $WeathervaneTypes::dockerServiceTypes{$workloadImpl};
	$logger->debug(
		"For redeploy by docker pull for services that are running on docker the serviceTypes are @$serviceTypesRef.");

	foreach my $serviceType (@$serviceTypesRef) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		$logger->debug("Calling pullDockerImage for $serviceType services ");
		foreach my $service (@$servicesRef) {
			my $host = $service->host;
			my $hostname = $host->hostName;
			my $sshConnectString = $host->sshConnectString;	
			if ($host->isNonDocker()) {			
				my $ls          = `$sshConnectString \"ls\" 2>&1`;
				if ( $ls =~ /No route/ ) {
					# This host is not up so can't redeploy
					$logger->debug("Don't redeploy to $hostname as it is not up.");
					next;
				}
			}
			$logger->debug( "Calling pullDockerImage for service ", $service->meta->name );
			$service->pullDockerImage($logfile);
		}
	}
	
	# Figure out if mongodb is using docker, and if so pull docker images
	# to app servers and data manager
	my $nosqlServicesRef = $self->getAllServicesByType('nosqlServer');
	my $nosqlServer      = $nosqlServicesRef->[0];
	if ( $nosqlServer->getParamValue('useDocker') ) {
		my $appServicesRef = $self->getAllServicesByType('appServer');
		foreach my $appServer (@$appServicesRef) {
			my $host = $appServer->host;
			my $hostname = $host->hostName;
			my $sshConnectString = $host->sshConnectString;
			if ($host->isNonDocker()) {			
				my $ls          = `$sshConnectString \"ls\" 2>&1`;
				if ( $ls =~ /No route/ ) {
					# This host is not up so can't redeploy
					$logger->debug("Don't redeploy to $hostname as it is not up.");
					next;
				}
			}
			$appServer->host->dockerPull( $logfile, $nosqlServer->getImpl() );
		}
		$self->dataManager->host->dockerPull( $logfile, $nosqlServer->getImpl() );
	}

	# Pull the datamanager image
	$self->dataManager->host->dockerPull( $logfile, "auctiondatamanager");
	
	# Redeploy the dataManager files
	my $localHostname = `hostname`; 
	my $localIpsRef = Utils::getIpAddresses($localHostname);
	my $hostname         = $self->dataManager->host->hostName;
	my $ip = Utils::getIpAddress($hostname);		
	if (!($ip ~~ @$localIpsRef)) {	
		my $sshConnectString = $self->dataManager->host->sshConnectString;
		my $scpConnectString = $self->dataManager->host->scpConnectString;
		my $scpHostString    = $self->dataManager->host->scpHostString;

		my $cmdString = "$sshConnectString rm -r $distDir/* 2>&1";
		$logger->debug("Redeploy: $cmdString");
		print $logfile "$cmdString\n";
		my $out = `$cmdString`;
		print $logfile $out;

		$cmdString = "$scpConnectString -r $distDir/* root\@$scpHostString:$distDir/.";
		$logger->debug("Redeploy: $cmdString");
		print $logfile "$cmdString\n";
		$out = `$cmdString`;
		print $logfile $out;
	}
	
	my $appServicesRef = $self->getAllServicesByType('appServer');
	foreach my $server (@$appServicesRef) {
		if ( $server->useDocker() ) {
			next;
		}
		my $host = $server->host;
		my $hostname = $host->hostName;
		my $sshConnectString = $host->sshConnectString;
		if ($host->isNonDocker()) {			
			my $ls          = `$sshConnectString \"ls\" 2>&1`;
			if ( $ls =~ /No route/ ) {
				# This host is not up so can't redeploy
				$logger->debug("Don't redeploy to $hostname as it is not up.");
				next;
			}
		}
		
		my $scpConnectString = $server->host->scpConnectString;
		my $scpHostString    = $server->host->scpHostString;
		my $appServerImpl    = $server->getParamValue('appServerImpl');
		my $warDestination;
		if ( $appServerImpl eq 'tomcat' ) {
			$warDestination = $self->getParamValue('tomcatCatalinaBase') . "/webapps";

			print $logfile "$sshConnectString \"rm -rf $warDestination/auction* 2>&1\"\n";
			my $out = `$sshConnectString \"rm -rf $warDestination/auction* 2>&1\"`;
			$logger->debug("$sshConnectString \"rm -rf $warDestination/auction* 2>&1\"  out = $out");
			print $logfile $out;

			print $logfile "$scpConnectString $distDir/auction.war root\@$scpHostString:$warDestination/.\n";
			$out = `$scpConnectString $distDir/auction.war root\@$scpHostString:$warDestination/.`;
			$logger->debug("$scpConnectString $distDir/auction.war root\@$scpHostString:$warDestination/.  out = $out");
			print $logfile $out;

			print $logfile "$scpConnectString $distDir/auctionWeb.war root\@$scpHostString:$warDestination/.\n";
			$out = `$scpConnectString $distDir/auctionWeb.war root\@$scpHostString:$warDestination/.`;
			$logger->debug("$scpConnectString $distDir/auctionWeb.war root\@$scpHostString:$warDestination/.  out = $out");
			print $logfile $out;

		}
		else {
			die "AuctionAppInstance::redeploy: Only tomcat is supported as app servers.\n";
		}
	}

	my $webServicesRef = $self->getAllServicesByType('webServer');
	foreach my $server (@$webServicesRef) {
		if ( $server->useDocker() ) {
			next;
		}
		my $host = $server->host;
		my $hostname = $host->hostName;
		my $sshConnectString = $host->sshConnectString;
		if ($host->isNonDocker()) {			
			my $ls          = `$sshConnectString \"ls\" 2>&1`;
			if ( $ls =~ /No route/ ) {
				# This host is not up so can't redeploy
				$logger->debug("Don't redeploy to $hostname as it is not up.");
				next;
			}
		}
		
		my $scpConnectString = $server->host->scpConnectString;
		my $scpHostString    = $server->host->scpHostString;
		my $webServerImpl    = $server->getParamValue('webServerImpl');
		my $webContentRoot;
		if ( $webServerImpl eq 'httpd' ) {
			$webContentRoot = $self->getParamValue('httpdDocumentRoot');
		}
		elsif ( $webServerImpl eq 'nginx' ) {
			$webContentRoot = $self->getParamValue('nginxDocumentRoot');
		}
		else {
			die "AuctionAppInstance::redeploy: Only httpd and nginx are supported .as web servers\n";
		}

		print $logfile "$sshConnectString \"rm -rf $webContentRoot/* 2>&1\"\n";
		my $out = `$sshConnectString \"rm -rf $webContentRoot/* 2>&1\"`;
		$logger->debug("$sshConnectString \"rm -rf $webContentRoot/* 2>&1\"  out = $out");
		print $logfile $out;
		
		print $logfile "$scpConnectString $distDir/auctionWeb.tgz root\@$scpHostString:$webContentRoot/.\n";
		$out = `$scpConnectString $distDir/auctionWeb.tgz root\@$scpHostString:$webContentRoot/.`;
		$logger->debug("$scpConnectString $distDir/auctionWeb.tgz root\@$scpHostString:$webContentRoot/.  out = $out");
		print $logfile $out;
		
		print $logfile "$sshConnectString \"cd $webContentRoot; tar zxf auctionWeb.tgz\"\n";
		$out = `$sshConnectString \"cd $webContentRoot; tar zxf auctionWeb.tgz\"`;
		$logger->debug("$sshConnectString \"cd $webContentRoot; tar zxf auctionWeb.tgz\"  out = $out");
		print $logfile $out;
		
		print $logfile "$sshConnectString \"rm -f $webContentRoot/auctionWeb.tgz 2>&1\"\n";
		$out = `$sshConnectString \"rm -f $webContentRoot/auctionWeb.tgz 2>&1\"`;
		$logger->debug("$sshConnectString \"rm -f $webContentRoot/auctionWeb.tgz 2>&1\"  out = $out");
		print $logfile $out;

	}

	# redeploy the configuration service
	my $configManagersRef = $self->getAllServicesByType('configurationManager');
	foreach my $server (@$configManagersRef) {
		if ( $server->useDocker() ) {
			next;
		}
		my $host = $server->host;
		my $hostname = $host->hostName;
		my $sshConnectString = $host->sshConnectString;
		if ($host->isNonDocker()) {			
			my $ls          = `$sshConnectString \"ls\" 2>&1`;
			if ( $ls =~ /No route/ ) {
				# This host is not up so can't redeploy
				$logger->debug("Don't redeploy to $hostname as it is not up.");
				next;
			}
		}
		my $scpConnectString = $server->host->scpConnectString;
		my $scpHostString    = $server->host->scpHostString;

		print $logfile
"$scpConnectString $distDir/auctionConfigManager.jar root\@$scpHostString:$distDir/auctionConfigManager.jar\n";
		my $out =
		  `$scpConnectString $distDir/auctionConfigManager.jar root\@$scpHostString:$distDir/auctionConfigManager.jar`;
		$logger->debug("$scpConnectString $distDir/auctionConfigManager.jar root\@$scpHostString:$distDir/auctionConfigManager.jar  out = $out");
		print $logfile $out;

	}
};

__PACKAGE__->meta->make_immutable;

1;

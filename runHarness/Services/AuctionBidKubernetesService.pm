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
package AuctionBidKubernetesService;

use Moose;
use MooseX::Storage;

use POSIX;
use Services::KubernetesService;
use Parameters qw(getParamValue);
use StatsParsers::ParseGC qw( parseGCLog );
use Log::Log4perl qw(get_logger);

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'AuctionBidService', );

has '+version' => ( default => '8', );

has '+description' => ( default => 'The Apache Tomcat Servlet Container', );

has 'mongosDocker' => (
	is      => 'rw',
	isa     => 'Str',
	default => "",
);

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("Configure AuctionBidService kubernetes");
	print $dblog "Configure AuctionBidService Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $serviceParamsHashRef =
	  $self->appInstance->getServiceConfigParameters( $self, $self->getParamValue('serviceType') );

	my $threads            = $self->getParamValue('auctionBidServerThreads');
	my $connections        = $self->getParamValue('auctionBidServerJdbcConnections');
	my $tomcatCatalinaBase = $self->getParamValue('tomcatCatalinaBase');
	my $maxIdle = ceil($self->getParamValue('auctionBidServerJdbcConnections') / 2);
	my $nodeNum = $self->getParamValue('instanceNum');
	my $maxConnections =
	  ceil( $self->getParamValue('frontendConnectionMultiplier') *
		  $users /
		  ( $self->appInstance->getNumActiveOfServiceType('auctionBidServer') * 1.0 ) );
	if ( $maxConnections < 100 ) {
		$maxConnections = 100;
	}

	my $completeJVMOpts .= $self->getParamValue('auctionBidServerJvmOpts');
	$completeJVMOpts .= " " . $serviceParamsHashRef->{"jvmOpts"};
	if ( $self->getParamValue('appServerEnableJprofiler') ) {
		$completeJVMOpts .=
		  " -agentpath:/opt/jprofiler8/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m";
	}

	if ( $self->getParamValue('logLevel') >= 3 ) {
		$completeJVMOpts .= " -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:$tomcatCatalinaBase/logs/gc.log ";
	}
	$completeJVMOpts .= " -DnodeNumber=$nodeNum ";
	
	my $numAuctionBidServers = $self->appInstance->getNumActiveOfServiceType('auctionBidServer');

	open( FILEIN,  "$configDir/kubernetes/auctionbidservice.yaml" ) or die "$configDir/kubernetes/auctionbidservice.yaml: $!\n";
	open( FILEOUT, ">/tmp/auctionbidservice-$namespace.yaml" )             or die "Can't open file /tmp/auctionbidservice-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /TOMCAT_JVMOPTS:/ ) {
			print FILEOUT "  TOMCAT_JVMOPTS: \"$completeJVMOpts\"\n";
		}
		elsif ( $inline =~ /TOMCAT_THREADS:/ ) {
			print FILEOUT "  TOMCAT_THREADS: \"$threads\"\n";
		}
		elsif ( $inline =~ /TOMCAT_JDBC_CONNECTIONS:/ ) {
			print FILEOUT "  TOMCAT_JDBC_CONNECTIONS: \"$connections\"\n";
		}
		elsif ( $inline =~ /TOMCAT_JDBC_MAXIDLE:/ ) {
			print FILEOUT "  TOMCAT_JDBC_MAXIDLE: \"$maxIdle\"\n";
		}
		elsif ( $inline =~ /TOMCAT_CONNECTIONS:/ ) {
			print FILEOUT "  TOMCAT_CONNECTIONS: \"$maxConnections\"\n";
		}
		elsif ( $inline =~ /replicas:/ ) {
			print FILEOUT "  replicas: $numAuctionBidServers\n";
		}
		elsif ( $inline =~ /\s\s\s\s\s\s\s\s\s\s\s\scpu:/ ) {
			print FILEOUT "            cpu: " . $self->getParamValue('auctionBidServerCpus') . "\n";
		}
		elsif ( $inline =~ /\s\s\s\s\s\s\s\s\s\s\s\smemory:/ ) {
			print FILEOUT "            memory: " . $self->getParamValue('auctionBidServerMem') . "\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			print FILEOUT "${1}$version\n";
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
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("isUp AuctionBidService kubernetes");
	my $cluster = $self->host;
	my $response = $cluster->kubernetesExecOne ($self->getImpl(), "curl -s http://localhost:8080/auction/healthCheck", $self->namespace );
	$logger->debug("isUp AuctionBidService kubernetes response = $response");
	if ( $response =~ /alive/ ) {
			return 1;
	}

	return 0;
};

override 'stopStatsCollection' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("stopStatsCollection");
};

override 'startStatsCollection' => sub {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->hostName;
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("startStatsCollection hostname = $hostname");

};

override 'getStatsFiles' => sub {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("getStatsFiles");

};

sub cleanLogFiles {
	my ( $self, $destinationPath ) = @_;
	my $logger = get_logger("Weathervane::Services::AuctionBidKubernetesService");
	$logger->debug("cleanLogFiles");
}

sub parseLogFiles {
	my ($self) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;
	my $namespace = $self->namespace;
	`mkdir -p $destinationPath`;

	`cp /tmp/tomcat-$namespace.yaml $destinationPath/. 2>&1`;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"auctionBidServiceThreads"}     = $self->getParamValue('auctionBidServerThreads');
	$csv{"auctionBidServiceConnections"} = $self->getParamValue('auctionBidServerJdbcConnections');
	$csv{"auctionBidServiceJvmOpts"}     = $self->getParamValue('auctionBidServerJvmOpts');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

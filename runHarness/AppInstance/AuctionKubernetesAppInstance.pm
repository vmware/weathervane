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
package AuctionKubernetesAppInstance;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use POSIX;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);
use AppInstance::AuctionAppInstance;
use ComputeResources::Cluster;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'AuctionAppInstance';

has 'namespace' => (
	is  => 'rw',
	isa => 'Str',
);

has 'host' => (
	is  => 'rw',
	isa => 'Cluster',
);

has 'imagePullPolicy' => (
	is      => 'rw',
	isa     => 'Str',
	default => "IfNotPresent",
);

override 'initialize' => sub {
	my ($self) = @_;
	
	$self->namespace("auctionw" . $self->getParamValue('workloadNum') . "i" . $self->getParamValue('appInstanceNum'));

	if ($self->getParamValue('redeploy')) {
	    $self->imagePullPolicy('Always');
	}
	
	super();

};

sub setHost {
	
	my ($self, $host) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	
	$self->host($host);
		
}

override 'getDeployedConfiguration' => sub {
	my ( $self, $destinationPath) = @_;
	
	# Get a host from the first appServer (since there will always be an appServer)
	my $appServersRef = $self->getActiveServicesByType("appServer");
	my $anAppServer = $appServersRef->[0];	
	my $cluster = $anAppServer->host;
	
	# Get the pod configuration and save it to a file
	open( FILEOUT, ">$destinationPath/" . $self->namespace . "-GetPods.txt" ) or die "Can't open file $destinationPath/" . $self->namespace . "-GetPods.txt: $!\n";	
	my $out = $cluster->kubernetesGetPods($self->namespace);
	my @out = split /\n/, $out;
	for my $line (@out) {
		print FILEOUT "$line\n";
	}
	close FILEOUT;
};

override 'startServices' => sub {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	my $users  = $self->dataManager->getParamValue('maxUsers');
	my $impl         = $self->getParamValue('workloadImpl');

	my $appInstanceName = $self->getParamValue('appInstanceName');
	my $logName         = "$setupLogDir/start-$serviceTier-$appInstanceName.log";
	my $logFile;
	open( $logFile, " > $logName " ) or die " Error opening $logName: $!";

	my $namespace = $self->namespace;
	my $cluster = $self->host;
	# Create the namespace and the namespace-wide resources
	my $configDir        = $self->getParamValue('configDir');
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
	$cluster->kubernetesApply("/tmp/namespace-$namespace.yaml", $self->namespace);
	
	$logger->debug(
		"startServices for serviceTier $serviceTier, workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl", 
		" users = $users",
		" setupLogDir = $setupLogDir"
	);

	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypes = $serviceTiersHashRef->{$serviceTier};
	$logger->debug("startServices for serviceTier $serviceTier, serviceTypes = @$serviceTypes");
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		if ($#{$servicesRef} >= 0) {
			# Use the first instance of the service for starting the 
			# service instances
			my $serviceRef = $servicesRef->[0];
			$serviceRef->start($serviceType, $users, $setupLogDir);
		} else {
			next;
		}		
	}
		
	# Don't return until all services are ready
	$self->isRunningAndUpDataServices($serviceTier, $logFile);
	
	close $logFile;
	
};

override 'cleanup' => sub {
	my ( $self, $cleanupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	
	my $cluster = $self->host;
	$cluster->kubernetesDeleteAllWithLabel("type=appInstance", $self->namespace);
	$cluster->kubernetesDeleteAllWithLabelAndResourceType("type=appInstance", "ingress", $self->namespace);
	
};

override 'getWwwIpAddrsRef' => sub {
	my ($self) = @_;
	my $cluster = $self->host;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	
	my $wwwIpAddrsRef = [];
	
	# Get the IP addresses of the nginx-ingress in this appInstance's namespace
	my $ipAddrsRef = $cluster->kubernetesGetNodeIPs();
	if ($#{$ipAddrsRef} < 0) {
		$logger->error("There are no IP addresses for the Kubernetes nodes");
		exit 1;
	}
	
	# Get the nodePort numbers for the ingress-controller-nginx service
	my $httpPort = $cluster->kubernetesGetNodePortForPortNumber("app=auction,type=webServer", 80, $self->namespace);
	my $httpsPort = $cluster->kubernetesGetNodePortForPortNumber("app=auction,type=webServer", 443, $self->namespace);
	
	foreach my $ipAddr (@$ipAddrsRef) {
		push @$wwwIpAddrsRef, [$ipAddr, $httpPort, $httpsPort];							
	}
	return $wwwIpAddrsRef;
};

override 'getServiceConfigParameters' => sub {
	my ( $self, $service, $serviceType ) = @_;
	my %serviceParameters = ();

	my $users = $self->getParamValue('maxUsers');

	if ( ($serviceType eq "appServer") || ($serviceType eq 'auctionBidServer') ) {

		# For the app Servers, Auction needs to provide JVM options
		my $jvmOpts = "";

		# This variable is a holder for all spring profiles that are active
		my $springProfilesActive = $self->getSpringProfilesActive();
		$jvmOpts .= " -Dspring.profiles.active=$springProfilesActive ";

		# Determine the sizes for the various application caches
		# if the number of auctions wasn't explicitly set, determine based on
		# the usersPerAuctionScaleFactor
		my $auctions = $self->getParamValue('auctions');
		if ( !$auctions ) {
			$auctions = ceil( $users / $self->getParamValue('usersPerAuctionScaleFactor') );
		}
		my $numAppServers                  = $self->getNumActiveOfServiceType('appServer');
		my $numWebServers                  = $self->getNumActiveOfServiceType('webServer');
		my $authTokenCacheSize             = 2 * $users;
		my $activeAuctionCacheSize         = 2 * $auctions;
		my $itemsForAuctionCacheSize       = 2 * $auctions;
		my $itemCacheSize                  = 20 * $auctions;
		my $auctionRepresentationCacheSize = 2 * $auctions;
		my $imageInfoCacheSize             = 100 * $auctions;

		my $itemThumbnailImageCacheSize =
		  $self->getParamValue('appServerThumbnailImageCacheSizeMultiplier') * $auctions;
		my $itemPreviewImageCacheSize = $self->getParamValue('appServerPreviewImageCacheSizeMultiplier') * $auctions;
		my $itemFullImageCacheSize    = $self->getParamValue('appServerFullImageCacheSizeMultiplier') * $auctions;
		$jvmOpts .= " -DAUTHTOKENCACHESIZE=$authTokenCacheSize -DACTIVEAUCTIONCACHESIZE=$activeAuctionCacheSize ";
		$jvmOpts .= " -DAUCTIONREPRESENTATIONCACHESIZE=$auctionRepresentationCacheSize ";
		$jvmOpts .= " -DIMAGEINFOCACHESIZE=$imageInfoCacheSize -DITEMSFORAUCTIONCACHESIZE=$itemsForAuctionCacheSize ";
		$jvmOpts .= " -DITEMCACHESIZE=$itemCacheSize ";

		my $appServerCacheImpl = $self->getParamValue('appServerCacheImpl');
		if ( $appServerCacheImpl eq 'ignite' ) {

			$jvmOpts .= " -DAUTHTOKENCACHEMODE=" . $self->getParamValue('igniteAuthTokenCacheMode') . " ";
	
			my $copyOnRead = "false";
			if ( $self->getParamValue('igniteCopyOnRead') ) {
				$copyOnRead = "true";
			}
			$jvmOpts .= " -DIGNITECOPYONREAD=$copyOnRead ";

			my $appServersRef = $self->getActiveServicesByType('appServer');
			my $app1Hostname  = $appServersRef->[0]->getIpAddr();
			$jvmOpts .= " -DIGNITEAPP1HOSTNAME=$app1Hostname ";
		}
		my $zookeeperConnectionString = "zookeeper-0.zookeeper:2181,zookeeper-1.zookeeper:2181,zookeeper-2.zookeeper:2181";
		$jvmOpts .= " -DZOOKEEPERCONNECTIONSTRING=$zookeeperConnectionString ";

		if ( $numWebServers > 1 ) {

			# Don't need to cache images in app server if there is a web
			# server since the web server caches.
			$itemThumbnailImageCacheSize = $auctions;
			$itemPreviewImageCacheSize   = 1;
			$itemFullImageCacheSize      = 1;
		}
		else {
			if ( $itemPreviewImageCacheSize == 0 ) {
				$itemPreviewImageCacheSize = 1;
			}

			if ( $itemFullImageCacheSize == 0 ) {
				$itemFullImageCacheSize = 1;
			}
		}
		$jvmOpts .= " -DITEMTHUMBNAILIMAGECACHESIZE=$itemThumbnailImageCacheSize ";
		$jvmOpts .= " -DITEMPREVIEWIMAGECACHESIZE=$itemPreviewImageCacheSize ";
		$jvmOpts .= " -DITEMFULLIMAGECACHESIZE=$itemFullImageCacheSize ";
		
		my $numCpus;
		if ( $service->getParamValue('dockerCpus')) {
			$numCpus = $service->getParamValue('dockerCpus');
		}
		else {
			$numCpus = 2;
		}

		my $highBidQueueConcurrency = $service->getParamValue('highBidQueueConcurrency');
		if (!$highBidQueueConcurrency) {
			$highBidQueueConcurrency = $numCpus;
		}
		$jvmOpts .= " -DHIGHBIDQUEUECONCURRENCY=$highBidQueueConcurrency ";

		if ( $service->getParamValue('randomizeImages') ) {
			$jvmOpts .= " -DRANDOMIZEIMAGES=true ";
		}
		else {
			$jvmOpts .= " -DRANDOMIZEIMAGES=false ";
		}
		
		my $newBidQueueConcurrency = $service->getParamValue('newBidQueueConcurrency');
		if (!$newBidQueueConcurrency) {
			$newBidQueueConcurrency = $numCpus;
		}		
		$jvmOpts .= " -DNEWBIDQUEUECONCURRENCY=$newBidQueueConcurrency ";

		# Turn on imageWriters in the application
		if ( $service->getParamValue('useImageWriterThreads') ) {
			if ( $service->getParamValue('imageWriterThreads') ) {
	
				# value was set, overriding the default
				$jvmOpts .= " -DIMAGEWRITERTHREADS=" . $service->getParamValue('imageWriterThreads') . " ";
			}
			else {

				my $iwThreads = floor( $numCpus / 2.0 );
				if ( $iwThreads < 1 ) {
					$iwThreads = 1;
				}
				$jvmOpts .= " -DIMAGEWRITERTHREADS=" . $iwThreads . " ";

			}

			$jvmOpts .= " -DUSEIMAGEWRITERTHREADS=true ";
		}
		else {
			$jvmOpts .= " -DUSEIMAGEWRITERTHREADS=false ";
		}
			
		$jvmOpts .= " -DNUMAUCTIONEERTHREADS=" . $service->getParamValue('numAuctioneerThreads') . " ";
			
		
		$jvmOpts .= " -DNUMCLIENTUPDATETHREADS=" . $service->getParamValue('numClientUpdateThreads') . " ";

		$jvmOpts .= " -DRABBITMQ_HOST=rabbitmq -DRABBITMQ_PORT=5672 ";

		$jvmOpts .= " -DMONGODB_HOST=mongodb -DMONGODB_PORT=27017 ";

		$jvmOpts .= " -DDBHOSTNAME=postgresql -DDBPORT=5432 ";

		if ( !( $jvmOpts =~ /CompileThreshold/ ) ) {
			$jvmOpts .= " -XX:CompileThreshold=2000 ";
		}

		$serviceParameters{"jvmOpts"} = $jvmOpts;
	}

	return \%serviceParameters;
};

override 'redeploy' => sub {
	my ( $self, $logfile ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	$logger->debug(
		"redeploy for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",         $self->getParamValue('appInstanceNum')
	);

	$self->imagePullPolicy("Always");
};

override 'getHostStatsSummary' => sub {
	my ( $self, $csvRef, $statsLogPath, $filePrefix, $prefix ) = @_;
	
};

override 'startStatsCollection' => sub {
	my ( $self ) = @_;
	# start kubectl top
	my $servicesRef = $self->getActiveServicesByType('appServer');
	my $service = $servicesRef->[0];
	my $tmpDir           = $self->getParamValue('tmpDir');
	my $destinationDir = "$tmpDir/statistics/kubernetes";
	`mkdir -p $destinationDir`;
	$service->host->kubernetesTopPodAllNamespaces(15, $destinationDir);
	$service->host->kubernetesTopNode(15, $destinationDir);

};

override 'stopStatsCollection' => sub {
	my ( $self ) = @_;
	# stop kubectl top
	my $servicesRef = $self->getActiveServicesByType('appServer');
	my $service = $servicesRef->[0];
	$service->host->stopKubectlTop(1);

};

override 'getStatsFiles' => sub {
	my ( $self ) = @_;

};

override 'cleanStatsFiles' => sub {
	my ( $self ) = @_;

};

override 'getLogFiles' => sub {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionKubernetesAppInstance");
	$logger->debug(
		"getLogFiles for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",            $self->getParamValue('appInstanceNum')
	);

	my $pid;
	my @pids;

	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/appInstance" . $self->getParamValue("instanceNum");
	}

	#  collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		if ($#{$servicesRef} >= 0) {
			my $service = $servicesRef->[0];
			my $name = $service->host->clusterName;
			my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $name;
			if ( !( -e $destinationPath ) ) {
				`mkdir -p $destinationPath`;
			}
			$service->getLogFiles($destinationPath);
		}
	}	
};

__PACKAGE__->meta->make_immutable;

1;

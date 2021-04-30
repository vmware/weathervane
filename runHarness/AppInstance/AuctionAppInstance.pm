# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AuctionAppInstance;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use POSIX;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);
use AppInstance::AppInstance;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'AppInstance';

has 'nextRabbitMQFirst' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

# The Auction appInstance needs to track various info for its services

## rabbitmqClusterHosts is used to keep track of
# the hosts on which RabbitMQ is already running
# when configuring a cluster.  If empty, then
# the cluster hasn't been created yet.
has 'rabbitmqClusterHosts' => (
	is        => 'rw',
	isa       => 'ArrayRef[Host]',
	clearer   => 'clear_rabbitmqClusterHosts',
	predicate => 'has_rabbitmqClusterHosts',
);

## numRabbitmqProcessed is used to keep track of how many
# RabbitMQ instances have already been
# started/stopped/etc.
has 'numRabbitmqProcessed' => (
	is        => 'rw',
	isa       => 'Num',
	clearer   => 'clear_numRabbitmqProcessed',
	predicate => 'has_numRabbitmqProcessed',
);

override 'initialize' => sub {
	my ($self) = @_;
		
	super();

};

override 'getEdgeService' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	$logger->debug(
		"getEdgeService for workload ", $self->workload->instanceNum,
		", appInstance ",               $self->instanceNum
	);

	my $numWebServers = $self->getTotalNumOfServiceType('webServer');
	my $numAppServers = $self->getTotalNumOfServiceType('appServer');
	$logger->debug(
		"getEdgeService: numWebServers = $numWebServers, numAppServers = $numAppServers");

	# Used to keep track of which server is acting as the edge (client-facing) service
	my $edgeServer;
	if ( $numWebServers == 0 ) {
		# small configuration. App server is the edge service
		$edgeServer = "appServer";
	}
	else {
		# medium configuration. Web server is the edge service
		$edgeServer = "webServer";
	}

	$logger->debug(
		"getEdgeService for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", returning ", $edgeServer
	);

	return $edgeServer;
};

override 'checkConfig' => sub {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	my $workloadNum = $self->workload->instanceNum;
	my $appInstanceNum = $self->instanceNum;
	$logger->debug("checkConfig for workload ", $workloadNum, " appInstance ", $appInstanceNum);

	my $edgeService              = $self->getParamValue('edgeService');
	my $numCoordinationServers   = $self->getTotalNumOfServiceType('coordinationServer');
	my $numWebServers            = $self->getTotalNumOfServiceType('webServer');
	my $numAppServers            = $self->getTotalNumOfServiceType('appServer');
	my $numMsgServers            = $self->getTotalNumOfServiceType('msgServer');
	my $numDbServers             = $self->getTotalNumOfServiceType('dbServer');
	my $numNosqlServers          = $self->getTotalNumOfServiceType('nosqlServer');

	my $minimumUsers = $self->getParamValue('minimumUsers');
	if ( $self->getParamValue('users') < $minimumUsers ) {
		$console_logger->error( "Workload $workloadNum, AppInstance $appInstanceNum: The Auction benchmark cannot be run with fewer than " . $minimumUsers . " users\n" );
		return 0;
	}
	my $validWorkloadProfilesRef = $WeathervaneTypes::workloadProfiles{"auction"};
    if (!(grep { $self->getParamValue('workloadProfile') eq $_ } @$validWorkloadProfilesRef)) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The Workload-Profile for the Auction workload must be one of: @$validWorkloadProfilesRef");
		return 0;
	}

    my $validAppInstanceSizes = $WeathervaneTypes::appInstanceSizes{"auction"};
    if (!(grep { $self->getParamValue('configurationSize') eq $_ } @$validAppInstanceSizes)) {
        $console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The AppInstance size for the Auction workload must be one of: @$validAppInstanceSizes");
        return 0;
    }

    my $validAppIngressMethods = $WeathervaneTypes::appIngressMethods{"auction"};
    if (!(grep { $self->getParamValue('appIngressMethod') eq $_ } @$validAppIngressMethods)) {
        $console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The appIngressMethod parameter for the Auction workload must be one of: @$validAppIngressMethods");
        return 0;
    }

    if (!(grep { $self->getParamValue('imageStoreType') eq $_ } @WeathervaneTypes::imageStoreTypes)) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The imageStore must be one of: @WeathervaneTypes::imageStoreTypes");
		return 0;
	}

	if ( ( $numCoordinationServers != 1 ) && ( $numCoordinationServers != 3 ) ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The number of Coordination Servers must be 1 or 3");
		return 0;
	}

	if ( $numNosqlServers < 1 ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The number of NoSQL servers must be 1 or greater");
		return 0;
	}

	if ( $numDbServers != 1 ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The number of DB servers must be 1, not $numDbServers");
		return 0;
	}

	if ( $numMsgServers < 1 ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The number of Message servers must be 1 or greater.");
		return 0;
	}

	if ( $numAppServers < 1 ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The number of application servers must be 1 or greater");
		return 0;
	}
	
	# Validate the the CPU and Mem sizings are in valid Kubernetes format
	my $workloadImpl    = $self->getParamValue('workloadImpl');
	my $serviceTypesRef = $WeathervaneTypes::dockerServiceTypes{$workloadImpl};
	foreach my $serviceType (@$serviceTypesRef) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			# A K8S CPU limit should be either a real number (e.g. 1.5), which
			# is legal docker notation, or an integer followed an "m" to indicate a millicpu
			my $cpus = $service->getParamValue($serviceType . "Cpus");
			if (!(($cpus =~ /^\d*\.?\d+$/) || ($cpus =~ /^\d+m$/))) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: $cpus is not a valid value for ${serviceType}Cpus.");
				$console_logger->error("CPU limit specifications must use Kubernetes notation.  See " . 
							"https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/");
				return 0;			
			} elsif ($cpus =~ /^(\d+)m$/) {
				# Convert all CPU specifications to numbers
				$cpus = ($1 * 1.0) / 1000.0;
				$service->setParamValue($serviceType . "Cpus", $cpus);
			}

			# K8s Memory limits are an integer followed by an optional suffix.
			# The legal suffixes in K8s are:
			#  * E, P, T, G, M, K (powers of 10)
			#  * Ei, Pi, Ti, Gi, Mi, Ki (powers of 2)
			my $mem = $service->getParamValue($serviceType . "Mem");
			if (!($mem =~ /^\d+(E|P|T|G|M|K|Ei|Pi|Ti|Gi|Mi|Ki)?$/)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: $mem is not a valid value for ${serviceType}Mem.");
				$console_logger->error("Memory limit specifications must use Kubernetes notation.  See " . 
							"https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/");
				return 0;			
			}
			
			# if the limitsExpansionPct parameter is specified, make sure that it is a positive integer
			my $expansionPct = $service->getParamValue('limitsExpansionPct');
			if ($expansionPct && (!($expansionPct =~ /^-?\d+\z/ ) || ($expansionPct < 0))) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: $expansionPct is not a valid value for limitsExpansionPct");
				$console_logger->error("limitsExpansionPct must be a non-negative integer\n");
				return 0;							
			}
		}
	}

	my $nosqlServersRef = $self->getAllServicesByType("nosqlServer");
	# If running on Docker hosts, only one cassandra node is supported
	my $firstNosqlServer =  $nosqlServersRef->[0];
	if (((ref $firstNosqlServer) eq "DockerHost") && ($numNosqlServers > 1)) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: When running on Docker hosts, only one Cassandra node can be used per appInstance.");
		return 0;
	}
	
	# If Cassandra is running on Docker, make sure that each node is running on a different host
	my @cassandraHosts;
	foreach my $nosqlServer (@$nosqlServersRef) {
		my $host = $nosqlServer->host;
		if ((ref $host) ne "DockerHost") {
			next;
		}
		my $hostname = $host->name;
        if (grep { $hostname eq $_ } @cassandraHosts) {
			$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: When using more than one nosqlServer (Cassandra) nodes, each must run on a different Docker host.");
			return 0;
		} else {
			push @cassandraHosts, $hostname;
		}
	}

	# Make sure that if useNamedVolumes is true for the nosql and db server, then the volume exists
	# This is only for services running on DockerHosts
	foreach my $nosqlServer (@$nosqlServersRef) {
		my $host = $nosqlServer->host;
		if ((ref $host) ne "DockerHost") {
			next;
		}
		if ($nosqlServer->getParamValue('cassandraUseNamedVolumes') || $host->getParamValue('vicHost')) {
			# use named volumes.  Error if does not exist
			my $volumeName = $nosqlServer->getParamValue('cassandraDataVolume');
			if (!$host->dockerVolumeExists($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName does not exist on Docker host " . $host->name);
				return 0;
			}
			if (!$host->dockerVolumeReserve($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName on Docker host " . $host->name . " is already being used by another service.");
				return 0;
			}
		}
	}
	my $dbServersRef = $self->getAllServicesByType("dbServer");
	foreach my $dbServer (@$dbServersRef) {
		my $host = $dbServer->host;
		if ((ref $host) ne "DockerHost") {
			next;
		}
		if ($dbServer->getParamValue('postgresqlUseNamedVolumes') || $host->getParamValue('vicHost')) {
			# use named volumes.  Error if does not exist
			my $volumeName = $dbServer->getParamValue('postgresqlVolume');
			if (!$host->dockerVolumeExists($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName does not exist on Docker host " . $host->name);
				return 0;
			}
			if (!$host->dockerVolumeReserve($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName on Docker host " . $host->name . " is already being used by another service.");
				return 0;
			}
		}
	}
	my $webServersRef = $self->getAllServicesByType("webServer");
	foreach my $webServer (@$webServersRef) {
		my $host = $webServer->host;
		if ((ref $host) ne "DockerHost") {
			next;
		}
		if ($webServer->getParamValue('nginxUseNamedVolumes') || $host->getParamValue('vicHost')) {
			# use named volumes.  Error if does not exist
			my $volumeName = $webServer->getParamValue('nginxCacheVolume');
			if (!$host->dockerVolumeExists($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName does not exist on Docker host " . $host->name);
				return 0;
			}
			if (!$host->dockerVolumeReserve($volumeName)) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The named volume $volumeName on Docker host " . $host->name . " is already being used by another service.");
				return 0;
			}
		}
	}
	
	if ($self->getParamValue("serviceTypeAffinity") && 
		($self->getParamValue("podInstanceAffinity") || $self->getParamValue("serviceTypeAntiAffinity"))) {
				$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The serviceTypeAffinity parameter cannot be true when podInstanceAffinity or serviceTypeAntiAffinity is also true.");
				return 0;
	}	
	
	return 1;
};

override 'redeploy' => sub {
	my ( $self, $logfile ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	$logger->debug(
		"redeploy for workload ", $self->workload->instanceNum,
		", appInstance ",         $self->instanceNum
	);

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
			$logger->debug( "Calling pullDockerImage for service ", $service->meta->name );
			$service->pullDockerImage($logfile);
		}
	}
	
	# Pull the datamanager image
	$self->dataManager->host->dockerPull( $logfile, "auctiondatamanager");
	
};

sub getSpringProfilesActive {
	my ($self) = @_;
	my $springProfilesActive;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");

	my $dbsRef = $self->getAllServicesByType('dbServer');
	my $db     = $dbsRef->[0]->getImpl();

	$springProfilesActive = "postgresql";
	$springProfilesActive .= ",ehcache";

	my $imageStore = $self->getParamValue('imageStoreType');
	if ( $imageStore eq "cassandra" ) {
		$springProfilesActive .= ",imagesInCassandra";
	}
	elsif ( $imageStore eq "memory" ) {
		$springProfilesActive .= ",imagesInMemory";
	}

	my $numMsgServers = $self->getTotalNumOfServiceType('msgServer');
	if ( $numMsgServers > 1 ) {
		$springProfilesActive .= ",clusteredRabbit";
	}
	elsif ( $numMsgServers == 1 ) {
		$springProfilesActive .= ",singleRabbit";
	}
	else {
		die "numMsgServers must be >= 1";
	}

	my $performanceMonitor = $self->getParamValue('appServerPerformanceMonitor');
	if ($performanceMonitor) {
		$springProfilesActive .= ",performanceMonitor";
	}

	my $numBidServers = $self->getTotalNumOfServiceType('auctionBidServer');
	if ($numBidServers > 0) {
		$springProfilesActive .= ",bidService";
	} else {
		$springProfilesActive .= ",noBidService";
	}

	$logger->debug(
		"getSpringProfilesActive finished for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		". Returning: ",
		$springProfilesActive
	);

	return $springProfilesActive;
}

sub getServiceConfigParameters {
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
		my $numAppServers                  = $self->getTotalNumOfServiceType('appServer');
		my $numWebServers                  = $self->getTotalNumOfServiceType('webServer');
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
		if ($self->getParamValue('prewarmAppServers')) {
			$jvmOpts .= " -DPREWARM=true ";
		} else {
			$jvmOpts .= " -DPREWARM=false ";	
		}

		my $zookeeperConnectionString = "";
		my $coordinationServersRef    = $self->getAllServicesByType('coordinationServer');
		foreach my $coordinationServer (@$coordinationServersRef) {
			my $zkHost = $service->getHostnameForUsedService($coordinationServer);
			my $zkPort = $service->getPortNumberForUsedService( $coordinationServer, "client" );
			$zookeeperConnectionString .= $zkHost . ":" . $zkPort . ",";
		}
		chop $zookeeperConnectionString;
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

		if ( $service->getParamValue('randomizeImages') ) {
			$jvmOpts .= " -DRANDOMIZEIMAGES=true ";
		}
		else {
			$jvmOpts .= " -DRANDOMIZEIMAGES=false ";
		}

		my $numCpus = $service->getParamValue("${serviceType}Cpus");
		my $highBidQueueConcurrency = $service->getParamValue('highBidQueueConcurrency');
		if (!$highBidQueueConcurrency) {
			$highBidQueueConcurrency = $numCpus;
		}
		my $newBidQueueConcurrency = $service->getParamValue('newBidQueueConcurrency');
		if (!$newBidQueueConcurrency) {
			$newBidQueueConcurrency = $numCpus;
		}		
		$jvmOpts .= " -DHIGHBIDQUEUECONCURRENCY=$highBidQueueConcurrency ";
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

		$jvmOpts .= " -DNUMCLIENTUPDATETHREADS=" . $service->getParamValue('numClientUpdateThreads') . " ";
		$jvmOpts .= " -DNUMAUCTIONEERTHREADS=" . $service->getParamValue('numAuctioneerThreads') . " ";


		my $clusteredRabbit = '';
		my $numMsgServers   = $self->getTotalNumOfServiceType('msgServer');
		if ( $numMsgServers > 1 ) {
			$clusteredRabbit = 1;
		}

		my $msgServicesRef = $self->getAllServicesByType("msgServer");
		if ($clusteredRabbit) {

			# start the list of rabbit hosts in rotating order
			$jvmOpts .= " -DRABBITMQ_HOSTS=";
			for ( my $i = $self->nextRabbitMQFirst ; $i <= $#{$msgServicesRef} ; $i++ ) {
				my $msgService   = $msgServicesRef->[$i];
				my $msgHostname  = $service->getHostnameForUsedService($msgService);
				my $rabbitMQPort = $service->getPortNumberForUsedService( $msgService, $msgService->getImpl() );
				$jvmOpts .= "$msgHostname:$rabbitMQPort,";
			}
			for ( my $i = 0 ; $i < $self->nextRabbitMQFirst ; $i++ ) {
				my $msgService   = $msgServicesRef->[$i];
				my $msgHostname  = $service->getHostnameForUsedService($msgService);
				my $rabbitMQPort = $service->getPortNumberForUsedService( $msgService, $msgService->getImpl() );
				$jvmOpts .= "$msgHostname:$rabbitMQPort,";
			}

			#remove the last (extra) comma
			chop $jvmOpts;

			$jvmOpts .= " ";

			$self->nextRabbitMQFirst( $self->nextRabbitMQFirst + 1 );
			if ( $self->nextRabbitMQFirst > $#{$msgServicesRef} ) {
				$self->nextRabbitMQFirst(0);
			}
		}
		else {
			my $msgService   = $msgServicesRef->[0];
			my $msgHostname  = $service->getHostnameForUsedService($msgService);
			my $rabbitMQPort = $service->getPortNumberForUsedService( $msgService, $msgService->getImpl() );
			$jvmOpts .= " -DRABBITMQ_HOST=$msgHostname -DRABBITMQ_PORT=$rabbitMQPort ";
		}

		my $cassandraContactpoints = "";
		my $nosqlServicesRef = $service->appInstance->getAllServicesByType("nosqlServer");
		my $cassandraPort = $service->getPortNumberForUsedService($nosqlServicesRef->[0], $nosqlServicesRef->[0]->getImpl());
		foreach my $nosqlServer (@$nosqlServicesRef) {
			$cassandraContactpoints .= $service->getHostnameForUsedService($nosqlServer) . ",";
		}
		$cassandraContactpoints =~ s/,$//;		
		$jvmOpts .= " -DCASSANDRA_CONTACTPOINTS=$cassandraContactpoints -DCASSANDRA_PORT=$cassandraPort ";

		my $dbServicesRef = $self->getAllServicesByType("dbServer");
		my $dbService     = $dbServicesRef->[0];
		my $dbHostname    = $service->getHostnameForUsedService($dbService);
		my $dbPort        = $service->getPortNumberForUsedService( $dbService, $dbService->getImpl() );
		$jvmOpts .= " -DDBHOSTNAME=$dbHostname -DDBPORT=$dbPort ";

		if ( !( $jvmOpts =~ /CompileThreshold/ ) ) {
			$jvmOpts .= " -XX:CompileThreshold=2000 ";
		}

		$serviceParameters{"jvmOpts"} = $jvmOpts;
	}

	return \%serviceParameters;
}

__PACKAGE__->meta->make_immutable;

1;

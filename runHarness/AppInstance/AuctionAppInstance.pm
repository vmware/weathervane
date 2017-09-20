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

override 'initialize' => sub {
	my ($self) = @_;
	super();

};

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

## numShardsProcessed is used to keep track of how many
# mongodbService instances have already been
# started/stopped/etc.  This is needed when deciding
# who should start the config servers and mongos
# instances
has 'numShardsProcessed' => (
	is        => 'rw',
	isa       => 'Num',
	clearer   => 'clear_numShardsProcessed',
	predicate => 'has_numShardsProcessed',
);

# This holds the string describing the hostname;port
# pairs for the config servers that is used when
# starting the mongos instances.
has 'configDbString' => (
	is        => 'rw',
	isa       => 'Str',
	clearer   => 'clear_configDbString',
	predicate => 'has_configDbString',
);

has 'numNosqlShards' => (
	is        => 'rw',
	isa       => 'Num',
	clearer   => 'clear_numNosqlShards',
	predicate => 'has_numNosqlShards',
);

has 'numNosqlReplicas' => (
	is        => 'rw',
	isa       => 'Num',
	clearer   => 'clear_numNosqlReplicas',
	predicate => 'has_numNosqlReplicas',
);

# AppInstance variables for keepalived
has 'wwwIpAddrs' => (
	is        => 'rw',
	isa       => 'ArrayRef[Str]',
	predicate => 'has_wwwIpAddrs',
);

override 'getEdgeService' => sub {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	$logger->debug(
		"getEdgeService for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",               $self->getParamValue('appInstanceNum')
	);

	my $numLbServers  = $self->getNumActiveOfServiceType('lbServer');
	my $numWebServers = $self->getNumActiveOfServiceType('webServer');
	my $numAppServers = $self->getNumActiveOfServiceType('appServer');
	$logger->debug(
		"getEdgeService: numLbServers = $numLbServers, numWebServers = $numWebServers, numAppServers = $numAppServers");

	# Used to keep track of which server is acting as the edge (client-facing) service
	my $edgeServer;

	if ( $numLbServers == 0 ) {
		if ( $numWebServers == 0 ) {

			# small configuration. App server is the edge service
			$edgeServer = "appServer";
		}
		else {

			# medium configuration. Web server is the edge service
			$edgeServer = "webServer";
		}
	}
	else {

		# large configuration. load-balancer is the edge service
		$edgeServer = "lbServer";
	}

	$logger->debug(
		"getEdgeService for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", returning ", $edgeServer
	);

	return $edgeServer;

};

override 'checkConfig' => sub {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AuctionAppInstance");
	my $workloadNum = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	$logger->debug("checkConfig for workload ", $workloadNum, " appInstance ", $appInstanceNum);

	# First make sure that any configPaths specified didn't ask for more services
	# than the user specified
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		if ( $self->getMaxNumOfServiceType($serviceType) < $self->getTotalNumOfServiceType($serviceType) ) {
			$console_logger->error(
				    "For service $serviceType the config path specifies more servers than were configured by num"
				  . $serviceType . "s or "
				  . $serviceType
				  . "s.\nMust specify at least "
				  . $self->getMaxNumOfServiceType($serviceType) . " "
				  . $serviceType
				  . "s for the configPath to be viable.\n." );
			return 0;
		}
	}

	my $edgeService              = $self->getParamValue('edgeService');
	my $numLbServers             = $self->getNumActiveOfServiceType('lbServer');
	my $numCoordinationServers   = $self->getNumActiveOfServiceType('coordinationServer');
	my $numWebServers            = $self->getNumActiveOfServiceType('webServer');
	my $numAppServers            = $self->getNumActiveOfServiceType('appServer');
	my $numMsgServers            = $self->getNumActiveOfServiceType('msgServer');
	my $numDbServers             = $self->getNumActiveOfServiceType('dbServer');
	my $numFileServers           = $self->getNumActiveOfServiceType('fileServer');
	my $numConfigurationManagers = $self->getNumActiveOfServiceType('configurationManager');
	my $numElasticityServers     = $self->getNumActiveOfServiceType('elasticityService');
	my $numNosqlServers          = $self->getNumActiveOfServiceType('nosqlServer');

	if ( $numElasticityServers > 1 ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The workload can be run with at most one elasticityServer.");
		return 0;
	}
	my $configPath = $self->getConfigPath();
	if (($#$configPath >= 0 ) && ($numElasticityServers < 1)) {
		$console_logger->error( "Workload $workloadNum, AppInstance $appInstanceNum: When running an appInstance with a configPath, the deployment must include an elasticity service.\n" );
		return 0;
	}

	my $minimumUsers = $self->getParamValue('minimumUsers');
	if ( $self->getParamValue('users') < $minimumUsers ) {
		$console_logger->error( "Workload $workloadNum, AppInstance $appInstanceNum: The Auction benchmark cannot be run with fewer than " . $minimumUsers . " users\n" );
		return 0;
	}

	my $validWorkloadProfilesRef = $WeathervaneTypes::workloadProfiles->{"auction"};
	if ( $self->getParamValue('workloadProfile') ~~ @$validWorkloadProfilesRef ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The Workload-Profile for Auction must be one of: @$validWorkloadProfilesRef");
		return 0;
	}

	my $imageStoreType = $self->getParamValue('imageStoreType');
	if ( !( $imageStoreType ~~ @WeathervaneTypes::imageStoreTypes ) ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The imageStore must be one of: @WeathervaneTypes::imageStoreTypes");
		return 0;
	}

	if ( ( $imageStoreType eq "filesystem" ) || ( $imageStoreType eq "filesystemApp" ) ) {
		if ( $numFileServers <= 0 ) {
			$console_logger->error(
"Workload $workloadNum, AppInstance $appInstanceNum: When the imageStoreType is filesystem or filesystemApp, then number of fileServers must be 1 or more, got $numFileServers"
			);
			return 0;
		}
	}
	else {
		if ( $numFileServers > 0 ) {
			$console_logger->error(
				"Workload $workloadNum, AppInstance $appInstanceNum: When the imageStoreType is not filesystem or filesystemApp, then number of fileServers must be 0");
			return 0;
		}
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

	if ( $numConfigurationManagers == 0 ) {
		if ( $self->getParamValue('prewarmAppServers') ) {
			$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: Can't pre-warm appServers when there is no Configuration Manager");
			return 0;
		}
	}

	my $appServerCacheImpl = $self->getParamValue('appServerCacheImpl');
	if ( ( $appServerCacheImpl ne 'ehcache' ) && ( $appServerCacheImpl ne 'ignite' ) ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The parameter appServerCacheImpl must be either ehcache or ignite");
		return 0;
	}

	my $igniteAuthTokenCacheMode = $self->getParamValue('igniteAuthTokenCacheMode');
	if ( ( $igniteAuthTokenCacheMode ne 'LOCAL' ) && ( $igniteAuthTokenCacheMode ne 'REPLICATED' ) ) {
		$console_logger->error("Workload $workloadNum, AppInstance $appInstanceNum: The parameter igniteAuthTokenCacheMode must be either LOCAL or REPLICATED");
		return 0;
	}

	return 1;
};

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

sub getSpringProfilesActive {
	my ($self) = @_;
	my $springProfilesActive;
	my $logger = get_logger("Weathervane::AppInstance::AuctionAppInstance");

	my $dbsRef = $self->getActiveServicesByType('dbServer');
	my $db     = $dbsRef->[0]->getImpl();

	if ( $db eq "mysql" ) {
		$springProfilesActive = "mysql";
	}
	else {
		$springProfilesActive = "postgresql";
	}

	my $appServerCacheImpl = $self->getParamValue('appServerCacheImpl');
	if ( $appServerCacheImpl eq "ehcache" ) {
		$springProfilesActive .= ",ehcache";
	}
	else {
		$springProfilesActive .= ",ignite";
	}

	my $imageStore = $self->getParamValue('imageStoreType');
	if ( ( $imageStore eq "filesystem" ) || ( $imageStore eq "filesystemApp" ) ) {
		$springProfilesActive .= ",imagesInFilesystem";
	}
	elsif ( $imageStore eq "mongodb" ) {
		$springProfilesActive .= ",imagesInMongo";
	}
	elsif ( $imageStore eq "memory" ) {
		$springProfilesActive .= ",imagesInMemory";
	}

	if ( $self->getParamValue('nosqlSharded') ) {
		$springProfilesActive .= ",shardedMongo";
	}
	elsif ( $self->getParamValue('nosqlReplicated') ) {
		$springProfilesActive .= ",replicatedMongo";
	}
	else {
		$springProfilesActive .= ",singleMongo";
	}

	my $numMsgServers = $self->getNumActiveOfServiceType('msgServer');
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
	$logger->debug(
		"getSpringProfilesActive finished for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		". Returning: ",
		$springProfilesActive
	);

	return $springProfilesActive;
}

sub getServiceConfigParameters {
	my ( $self, $service, $serviceType ) = @_;
	my %serviceParameters = ();

	my $users = $self->users;

	if ( $serviceType eq "appServer" ) {

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

		$jvmOpts .= " -DAUTHTOKENCACHEMODE=" . $self->getParamValue('igniteAuthTokenCacheMode') . " ";

		my $copyOnRead = "false";
		if ( $self->getParamValue('igniteCopyOnRead') ) {
			$copyOnRead = "true";
		}
		$jvmOpts .= " -DIGNITECOPYONREAD=$copyOnRead ";

		my $appServersRef = $self->getActiveServicesByType('appServer');
		my $app1Hostname  = $appServersRef->[0]->getIpAddr();
		$jvmOpts .= " -DIGNITEAPP1HOSTNAME=$app1Hostname ";

		my $zookeeperConnectionString = "";
		my $coordinationServersRef    = $self->getActiveServicesByType('coordinationServer');
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

		my $numCpus;
		if ( $service->useDocker() && $service->getParamValue('dockerCpus')) {
			$numCpus = $service->getParamValue('dockerCpus');
		}
		else {
			$numCpus = $service->host->cpus;
		}
		
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
		my $numMsgServers   = $self->getNumActiveOfServiceType('msgServer');
		if ( $numMsgServers > 1 ) {
			$clusteredRabbit = 1;
		}

		my $msgServicesRef = $self->getActiveServicesByType("msgServer");
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

		my $nosqlHostname;
		my $mongodbPort;
		my $nosqlServicesRef = $self->getActiveServicesByType("nosqlServer");
		if ( !$self->getParamValue('nosqlSharded') ) {
			my $nosqlService = $nosqlServicesRef->[0];
			$nosqlHostname = $service->getHostnameForUsedService($nosqlService);
			$mongodbPort = $service->getPortNumberForUsedService( $nosqlService, 'mongod' );
		}
		else {

			# The mongos will be running on this app server
			$nosqlHostname = $service->host->hostName;
			if ( $service->mongosDocker ) {
				$nosqlHostname = $service->mongosDocker;
			}
			$mongodbPort = $service->internalPortMap->{'mongos'};
		}
		$jvmOpts .= " -DMONGODB_HOST=$nosqlHostname -DMONGODB_PORT=$mongodbPort ";

		if ( $self->getParamValue('nosqlReplicated') ) {
			my $nosqlService      = $nosqlServicesRef->[0];
			my $nosqlHostname     = $service->getHostnameForUsedService($nosqlService);
			my $mongodbPort       = $service->getPortNumberForUsedService( $nosqlService, 'mongod' );
			my $mongodbReplicaSet = "$nosqlHostname:$mongodbPort";
			for ( my $i = 1 ; $i <= $#{$nosqlServicesRef} ; $i++ ) {
				$nosqlService  = $nosqlServicesRef->[$i];
				$nosqlHostname = $service->getHostnameForUsedService($nosqlService);
				$mongodbPort   = $service->getPortNumberForUsedService( $nosqlService, 'mongod' );
				$mongodbReplicaSet .= ",$nosqlHostname:$mongodbPort";
			}
			$jvmOpts .= " -DMONGODB_REPLICA_SET=$mongodbReplicaSet ";
		}

		my $dbServicesRef = $self->getActiveServicesByType("dbServer");
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

# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AuctionDataManager;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;

use DataManagers::DataManager;
use Parameters qw(getParamValue);
use WeathervaneTypes;
use List::Util qw[min max];
use POSIX;
use Try::Tiny;
use Log::Log4perl qw(get_logger);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

extends 'DataManager';

has 'dockerConfigHashRef' => (
	is      => 'rw',
	isa     => 'HashRef',
	default => sub { {} },
);

# default scale factors
my $defaultUsersScaleFactor           = 5;
my $defaultUsersPerAuctionScaleFactor = 15.0;

override 'initialize' => sub {
	my ($self) = @_;	
	if ($self->getParamValue('dockerNet')) {
		$self->dockerConfigHashRef->{'net'} = $self->getParamValue('dockerNet');
	}
	my $workloadNum = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	$self->name("auctiondatamanagerW${workloadNum}A${appInstanceNum}");
	super();
};


sub startDataManagerContainer {
	my ( $self, $users, $applog ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $name        = $self->name;
	
	# Calculate the values for the environment variables used by the auctiondatamanager container
	my $jvmopts = $self->getParamValue('dbLoaderJvmOpts');
	my $loaderThreads = $self->getParamValue('dbLoaderThreads');
	my $prepThreads = $self->getParamValue('dbPrepThreads');
	my %envVarMap;
	$envVarMap{"USERSPERAUCTIONSCALEFACTOR"} = $self->getParamValue('usersPerAuctionScaleFactor');	
	$envVarMap{"USERS"} = $users;	
	$envVarMap{"MAXUSERS"} = $self->getParamValue('maxUsers');	
	$envVarMap{"WORKLOADNUM"} = $workloadNum;	
	$envVarMap{"APPINSTANCENUM"} = $appInstanceNum;	
	$envVarMap{"JVMOPTS"} = "\"$jvmopts\"";
	$envVarMap{"LOADERTHREADS"} = $loaderThreads;	
	$envVarMap{"PREPTHREADS"} = $prepThreads;	
	
	my $cassandraContactpoints = "";
	my $nosqlServicesRef = $self->appInstance->getAllServicesByType("nosqlServer");
	my $cassandraPort = $self->getPortNumberForUsedService($nosqlServicesRef->[0], $nosqlServicesRef->[0]->getImpl());
	foreach my $nosqlServer (@$nosqlServicesRef) {
		$cassandraContactpoints .= $self->getHostnameForUsedService($nosqlServer) . ",";
	}
	$cassandraContactpoints =~ s/,$//;		
	$envVarMap{"CASSANDRA_CONTACTPOINTS"} = $cassandraContactpoints;
	$envVarMap{"CASSANDRA_PORT"} = $cassandraPort;
	
	my $dbServicesRef = $self->appInstance->getAllServicesByType("dbServer");
	my $dbService     = $dbServicesRef->[0];
	my $dbHostname    = $self->getHostnameForUsedService($dbService);
	my $dbPort        = $self->getPortNumberForUsedService($dbService, $dbService->getImpl()) ;
	$envVarMap{"DBHOSTNAME"} = $dbHostname;
	$envVarMap{"DBPORT"} = $dbPort;
	
	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();
	$envVarMap{"SPRINGPROFILESACTIVE"} = $springProfilesActive;
	
	# Start the  auctiondatamanager container
	my %volumeMap;
	my %portMap;
	my $directMap = 0;
	my $cmd        = "";
	my $entryPoint = "";
	$self->host->dockerRun(
		$applog, $name,
		"auctiondatamanager", $directMap, \%portMap, \%volumeMap, \%envVarMap, $self->dockerConfigHashRef,
		$entryPoint, $cmd, 1
	);
}

sub stopDataManagerContainer {
	my ( $self, $applog ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $name        = $self->name;

	$self->host->dockerStopAndRemove( $applog, $name );
}

sub prepareDataServices {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $appInstance    = $self->appInstance;
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $reloadDb       = $self->getParamValue('reloadDb');
	my $logName = "$logPath/PrepareData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	$console_logger->info(
		"Configuring and starting data services for appInstance $appInstanceNum of workload $workloadNum.\n" );

	# Start the data services
	if ($reloadDb) {
		# Avoid an extra stop/start cycle for the data services since we know
		# we are reloading the data
		$appInstance->clearDataServicesBeforeStart($logPath);
	}
	
	my $allIsStarted = $appInstance->startServices("data", $logPath, 0);
	if ( !$allIsStarted ) {
		close $logHandle;
		return $allIsStarted;
	}
	
	# Make sure that the services know their external port numbers
	$self->appInstance->setExternalPortNumbers();	
	
	# This will stop and restart the data manager so that it has the right port numbers
	$self->startDataManagerContainer ($users, $logHandle);

	if ( !$reloadDb && !$self->isDataLoaded( $users, $logPath ) ) {
		# Need to stop and restart services so that we can clear out any old data
		$appInstance->stopServices("data", $logPath);
		$appInstance->clearDataServicesBeforeStart($logPath);
		$allIsStarted = $appInstance->startServices("data", $logPath, 0);
		if ( !$allIsStarted ) {
			close $logHandle;
			return $allIsStarted;
		}
		# Make sure that the services know their external port numbers
		$self->appInstance->setExternalPortNumbers();

		# stop and restart the data manager so that it has the right port numbers
		$self->stopDataManagerContainer($logHandle);
		$self->startDataManagerContainer($users, $logHandle);

		$logger->debug( "All data services configured and started for appInstance "
			  . "$appInstanceNum of workload $workloadNum.  " );
	}
	
	close $logHandle;
	return 1;
}

sub prepareData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $name        = $self->name;
	my $reloadDb       = $self->getParamValue('reloadDb');
	my $maxUsers = $self->getParamValue('maxUsers');
	my $appInstance    = $self->appInstance;
	my $retVal         = 0;

	my $logName = "$logPath/PrepareData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">>$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	$logger->debug("prepareData users = $users, logPath = $logPath");
	print $logHandle "prepareData users = $users, logPath = $logPath\n";

	sleep(10);
	# Make sure that the services know their external port numbers
	$self->appInstance->setExternalPortNumbers();	

	# Make sure that all of the data services are up
	$logger->debug(
		"Checking that all data services are up for appInstance $appInstanceNum of workload $workloadNum." );
	my $allUp = $appInstance->isUpDataServices($logPath);
	if ( !$allUp ) {
		$console_logger->error(
			"Couldn't bring up all data services for appInstance $appInstanceNum of workload $workloadNum." );
		return 0;
	}
	$logger->debug( "All data services are up for appInstance $appInstanceNum of workload $workloadNum." );
		
	if ($reloadDb || !$self->isDataLoaded( $users, $logPath )) {
		$appInstance->clearDataServicesAfterStart($logPath);
		$retVal = $self->loadData( $users, $logPath );
		if ( !$retVal ) { return 0; }
	}
	else {
		$console_logger->info( "Data is already loaded for appInstance "
			  . "$appInstanceNum of workload $workloadNum." );
	}

	$console_logger->info( "Preparing auctions and warming data-services for for appInstance "
				  . "$appInstanceNum of workload $workloadNum." );
	print $logHandle "Exec-ing perl /prepareData.pl  in container $name\n";
	$logger->debug("Exec-ing perl /prepareData.pl  in container $name");
	my $dockerHostString  = $self->host->dockerHostString;	
	my $cmdOut = `$dockerHostString docker exec $name perl /prepareData.pl`;
	print $logHandle "Output: $cmdOut, \$? = $?\n";
	$logger->debug("Output: $cmdOut, \$? = $?");
	if ($?) {
		$console_logger->error( "Data preparation process failed.  Check PrepareData.log for more information." );
		$self->stopDataManagerContainer($logHandle);
		return 0;
	}

	# cleanup the databases from any previous run
	$self->cleanData( $users, $logHandle );

	# stop the auctiondatamanager container
	$self->stopDataManagerContainer($logHandle);

	close $logHandle;
	return 1;
}

sub loadData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger   = get_logger("Console");
	my $logger           = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $hostname    = $self->host->name;
	my $name        = $self->name;

	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $logName          = "$logPath/loadData-W${workloadNum}I${appInstanceNum}-$hostname.log";
	my $appInstance      = $self->appInstance;

	$logger->debug("loadData for workload $workloadNum, appInstance $appInstanceNum");

	my $applog;
	open( $applog, ">$logName" )
	  or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	  };

	my $maxUsers = $self->getParamValue('maxUsers');	
	if ( $users > $maxUsers ) {
		$maxUsers = $users;
	}

	$console_logger->info(
		"Workload $workloadNum, appInstance $appInstanceNum: Loading data for a maximum of $maxUsers users" );

	$logger->debug("Exec-ing perl /loadData.pl in container $name");
	print $applog "Exec-ing perl /loadData.pl in container $name\n";
	my $dockerHostString  = $self->host->dockerHostString;
	
	open my $pipe, "$dockerHostString docker exec $name perl /loadData.pl  |"   or die "Couldn't execute program: $!";
 	while ( defined( my $line = <$pipe> )  ) {
		chomp($line);
		if ($line =~ /Loading/) {
			$console_logger->info("$line\n");
		} 
   	}
   	close $pipe;	
	
	# Get the logs from the auctionDataManager and store the info in the logs
	my $logOut = $self->host->dockerGetLogs($applog, $self->name);
	$logger->debug($logOut);
	
	close $applog;

	# Now make sure that the data is really loaded properly
	my $isDataLoaded = 0;
	try {
		$isDataLoaded = $self->isDataLoaded( $users, $logPath );
	};

	if ( !$isDataLoaded ) {
		$console_logger->error(
			"Data is still not loaded properly.  Check the logs of the data services for errors.\n" );
		return 0;
	}
	return 1;
}

sub isDataLoaded {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");

	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	$logger->debug("isDataLoaded for workload $workloadNum, appInstance $appInstanceNum");

	my $hostname = $self->host->name;
	my $name        = $self->name;

	my $logName = "$logPath/isDataLoaded-W${workloadNum}I${appInstanceNum}-$hostname.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog "Exec-ing perl /isDataLoaded.pl  in container $name\n";
	$logger->debug("Exec-ing perl /isDataLoaded.pl  in container $name");
	my $dockerHostString  = $self->host->dockerHostString;	
	my $cmdOut = `$dockerHostString docker exec $name perl /isDataLoaded.pl`;
	print $applog "Output: $cmdOut, \$? = $?\n";
	$logger->debug("Output: $cmdOut, \$? = $?");
	close $applog;
	if ($?) {
		$logger->debug( "Data is not loaded for workload $workloadNum, appInstance $appInstanceNum. \$cmdOut = $cmdOut" );
		return 0;
	}
	else {
		$logger->debug( "Data is loaded for workload $workloadNum, appInstance $appInstanceNum. \$cmdOut = $cmdOut" );
		return 1;
	}
}


sub cleanData {
	my ( $self, $users, $logHandle ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	foreach my $nosqlServerRef (@$nosqlServersRef) {
#		$nosqlServerRef->cleanData($users, $logHandle);
	}
}

__PACKAGE__->meta->make_immutable;

1;

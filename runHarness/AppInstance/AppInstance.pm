# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AppInstance;

use Moose;
use MooseX::Storage;
use MooseX::ClassAttribute;
use POSIX;
use Tie::IxHash;
use Log::Log4perl qw(get_logger);
use Instance;
use WeathervaneTypes;

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

extends 'Instance';

has 'users' => (
	is  => 'rw',
	isa => 'Int',
);

has 'curRateStep' => (
	is  => 'rw',
	isa => 'Int',
);

has 'minFailUsers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 9999999,
);

has 'maxPassUsers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

has 'maxLowUT' => (
	is      => 'rw',
	isa     => 'Num',
	default => 0,
);

has 'maxLowUTUsers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 0,
);

has 'minHighUT' => (
	is      => 'rw',
	isa     => 'Num',
	default => 9999999,
);

has 'minHighUTUsers' => (
	is      => 'rw',
	isa     => 'Int',
	default => 9999999,
);

has 'alreadyFoundMax' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

has 'workload' => (
	is  => 'rw',
	isa => 'Workload',
);

has 'dataManager' => (
	is  => 'rw',
	isa => 'DataManager',
);

class_has 'nextPortMultiplierByServiceType' => (
	is      => 'rw',
	isa     => 'HashRef[Int]',
	default => sub { {} },
);

has 'servicesByTypeHashRef' => (
	is      => 'rw',
	isa     => 'HashRef[ArrayRef[Service]]',
	default => sub { {} },
);

has 'initialNumServicesByTypeHashRef' => (
	is      => 'rw',
	isa     => 'HashRef[Int]',
	default => sub { {} },
);

has 'maxNumServicesByTypeHashRef' => (
	is      => 'rw',
	isa     => 'HashRef[Int]',
	default => sub { {} },
);

has 'passedLast' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 0,
);

# Depending on the runStrategy and loadPathType, the concept of pass/fail
# may not make sense for some appInstances
has 'isPassable' => (
	is      => 'rw',
	isa     => 'Bool',
	default => 1,
);

has 'host' => (
	is  => 'rw',
);

override 'initialize' => sub {
	my ($self) = @_;
	super();

	my $logger = get_logger("Weathervane::AppInstance::AppInstance");

	# Assign a name to this service
	my $workloadNum = $self->workload->instanceNum;
	my $appInstanceNum = $self->instanceNum;
	$self->name("W${workloadNum}A${appInstanceNum}");

	$self->curRateStep( $self->getParamValue('initialRateStep') );

	$self->users( $self->getParamValue('users') );
	my $userLoadPath = $self->getParamValue('userLoadPath');
	if ( $#$userLoadPath >= 0 ) {
		$logger->debug( "AppInstance " . $self->instanceNum . " uses a user load path." );
		my $parsedPathRef = parseLoadPath($userLoadPath);
		my $maxUsers         = $parsedPathRef->[0];
		if ( $maxUsers > $self->users ) {
			$self->users($maxUsers);
		}
	}
	
	my $loadPathType = $self->getParamValue('loadPathType');	
	if ($loadPathType eq 'interval') {
		# Instances with interval loadPathType are never passable
		$self->isPassable(0);    	
	}

};

sub parseLoadInterval {
	my ( $self, $loadIntervalRef ) = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $console_logger = get_logger("Console");

	my $users;
	if ( ( exists $loadIntervalRef->{"users"} ) && ( exists $loadIntervalRef->{"duration"} ) ) {
		$users = $loadIntervalRef->{"users"};
	}
	elsif (( exists $loadIntervalRef->{"startUsers"} )
		&& ( exists $loadIntervalRef->{"endUsers"} )
		&& ( exists $loadIntervalRef->{"duration"} ) )
	{
		$users = max( $loadIntervalRef->{"startUsers"}, $loadIntervalRef->{"endUsers"} );
	}
	elsif ( ( exists $loadIntervalRef->{"endUsers"} ) && ( exists $loadIntervalRef->{"duration"} ) ) {
		$users = $loadIntervalRef->{"endUsers"};
	}
	else {
		$console_logger->error( "Found an invalid load interval in load path: ", %$loadIntervalRef );
		exit(-1);
	}

	$logger->debug( "Parsed load interval %$loadIntervalRef.  Got users = $users, duration = ",
		$loadIntervalRef->{"duration"} );
	return [ $users, $loadIntervalRef->{"duration"} ];
}

sub parseLoadPath {
	my ( $self, $loadPathRef ) = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $console_logger = get_logger("Console");

	my $maxUsers      = 0;
	my $totalDuration = 0;
	foreach my $loadIntervalRef (@$loadPathRef) {
		my $parsedIntervalRef = parseLoadInterval($loadIntervalRef);
		my $users             = $parsedIntervalRef->[0];
		if ( $users > $maxUsers ) {
			$maxUsers = $users;
		}
		$totalDuration += $parsedIntervalRef->[1];
	}

	$logger->debug("Parsed load path @$loadPathRef.  Got maxUsers = $maxUsers, totalDuration = $totalDuration");
	return [ $maxUsers, $totalDuration ];
}

sub setDataManager {
	my ( $self, $dataManager ) = @_;
	$self->dataManager($dataManager);
}

sub setServicesByType {
	my ( $self, $serviceType, $servicesRef ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	$servicesByTypeHashRef->{$serviceType} = $servicesRef;
}

sub addServiceByType {
	my ( $self, $serviceType, $service ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	if ( !$servicesByTypeHashRef->{$serviceType} ) {
		$servicesByTypeHashRef->{$serviceType} = [];
	}
	push @{ $servicesByTypeHashRef->{$serviceType} }, $service;
}

sub getAllServicesByType {
	my ( $self, $serviceType ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	return $servicesByTypeHashRef->{$serviceType};
}

sub getTotalNumOfServiceType {
	my ( $self, $serviceType ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	my $servicesRef           = $servicesByTypeHashRef->{$serviceType};
	return $#{$servicesRef} + 1;
}

sub getServiceByTypeAndName {
	my ( $self, $serviceType, $name ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	my $servicesListRef       = $servicesByTypeHashRef->{$serviceType};
	my $logger                = get_logger("Weathervane::AppInstance::AppInstance");

	foreach my $service (@$servicesListRef) {
		if ( $service->name eq $name ) {
			$logger->debug( "getServiceByTypeAndName for type $serviceType and name $name "
				  . "returning service on host "
				  . $service->host->name );
			return $service;
		}
	}

	$logger->debug( "getServiceByTypeAndName for type $serviceType and name $name. " . "Service not found." );
	return "";
}

sub getNextPortMultiplierByServiceType {
	my ( $self, $serviceType ) = @_;
	if (   ( !exists $self->nextPortMultiplierByServiceType->{$serviceType} )
		|| ( !defined $self->nextPortMultiplierByServiceType->{$serviceType} ) )
	{
		$self->nextPortMultiplierByServiceType->{$serviceType} = 0;
	}
	my $multiplier = $self->nextPortMultiplierByServiceType->{$serviceType};
	$self->nextPortMultiplierByServiceType->{$serviceType} = $multiplier + 1;
	return $multiplier;
}

sub getEdgeService {
	my ($self) = @_;
	return $self->getParamValue('edgeService');
}

sub getUsers {
	my ($self) = @_;
	return $self->users;
}

sub getMaxLoadedUsers {
	my ($self)        = @_;
	my $dbServicesRef = $self->getAllServicesByType("dbServer");
	my $dbServer      = $dbServicesRef->[0];

	return $dbServer->getMaxLoadedUsers();
}

sub getLoadPath {
	my ($self) = @_;
	return $self->getParamValue('userLoadPath');
}

sub hasLoadPath {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $workloadNum    = $self->workload->instanceNum;
	my $appInstanceNum = $self->instanceNum;
	my $userLoadPath   = $self->getParamValue('userLoadPath');
	$logger->debug(
		"AppInstance $appInstanceNum of workload $workloadNum has userLoadPath @$userLoadPath of length $#$userLoadPath"
	);
	if ( $#$userLoadPath >= 0 ) {
		return 1;
	}
	else {
		return 0;
	}
}

sub getEdgeAddrsRef {
	my ($self) = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $workloadNum    = $self->workload->instanceNum;

	my $edgeHostsRef = [];
	my $edgeService  = $self->getEdgeService();
	my $edgeServices = $self->getAllServicesByType($edgeService);
	$logger->debug("getEdgeAddrsRef");
	foreach my $service (@$edgeServices) {
		push @$edgeHostsRef, [$service->host->name, $service->portMap->{"http"}, $service->portMap->{"https"}];
	}
	
	return $edgeHostsRef;
}

sub clearReloadDb {
	my ($self) = @_;
	$self->dataManager->setParamValue( 'reloadDb', 0 );;
}

sub checkConfig {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	$console_logger->error("Called checkConfig on an abstract instance of AppInstance");

	return 0;
}

sub redeploy {
	my ( $self, $logfile ) = @_;
	my $console_logger = get_logger("Console");
	$console_logger->error("Called redeploy on an abstract instance of AppInstance");

	return 0;
}

sub adjustUsersForFindMax {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"adjustUsersForFindMax start ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	if ( $self->alreadyFoundMax ) {
		return;
	}

	my $passed      = $self->passedLast();
	my $users       = $self->users;
	my $curRateStep = $self->curRateStep;
	my $maxPass     = $self->maxPassUsers;
	my $minFail     = $self->minFailUsers;

	if ($passed) {
		# Get a rate step that leaves next run at below minFail
		if ( ( $users + $curRateStep ) >= $minFail ) {
			$curRateStep = ceil( ($minFail - $maxPass) / 2 );
		}

		my $maxUsers = $self->getParamValue('maxUsers');
		my $newVal = $users + $curRateStep;
		if ($newVal > $maxUsers) {
			$newVal = $maxUsers;
			$curRateStep = $maxUsers - $users;
		}

		$self->users( $newVal );
		$self->curRateStep($curRateStep);

	}
	else {
		if ( ( $users - $curRateStep ) <= $maxPass ) {
			$curRateStep = ceil( ($minFail - $maxPass) / 2 );
		}

		my $nextUsers = $users - $curRateStep;
		if ( $nextUsers < $self->getParamValue('minimumUsers') ) {
			$nextUsers = $self->getParamValue('minimumUsers');
		}
		$self->users($nextUsers);
		$self->curRateStep($curRateStep);

	}
	$logger->debug(
		"adjustUsersForFindMax end ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub foundMax {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug("foundMax start");
	my $console_logger = get_logger("Console");

	if ( $self->alreadyFoundMax ) {
		return 1;
	}

	my $foundMax = 0;

	my $passed      = $self->passedLast();
	my $users       = $self->users;
	my $maxPass     = $self->maxPassUsers;
	my $minFail     = $self->minFailUsers;
	my $findMaxStopPct    = $self->getParamValue('findMaxStopPct');
	
	if ($passed) {
		if ( $users > $maxPass ) {
			$self->maxPassUsers($users);
			if (($minFail - $maxPass) < ($minFail * $findMaxStopPct)) {
				$foundMax = 1;
			}
		}

		my $maxUsers = $self->getParamValue('maxUsers');
		if ($users == $maxUsers) {
			$console_logger->warn("Workload ", $self->workload->instanceNum,
				", appInstance ", $self->instanceNum,
				": Passed at maximum number of loaded users $users.  Increase maxUsers and try again.");
			$foundMax = 1;
		}
	}
	else {
		if ( $users < $minFail ) {
			$self->minFailUsers($users);
			if (($minFail - $maxPass) < ($minFail * $findMaxStopPct)) {
				$foundMax = 1;
			}
		}

		my $minUsers    = $self->getParamValue('minimumUsers');
		if ($users == $minUsers) {
			$console_logger->info(
				"Workload ", $self->workload->instanceNum,
				", appInstance ", $self->instanceNum,
				": Can't run lower than Weathervane minumum users (" . $minUsers . ")"
			);
			$foundMax = 1;
		}
	}

	$self->alreadyFoundMax($foundMax);
	$logger->debug("foundMax return " . $foundMax,
		". Workload ", $self->workload->instanceNum,
		", appInstance ", $self->instanceNum
	);
	
	return $foundMax;
}

sub printFindMaxResult {
	my ($self) = @_;
	my $console_logger = get_logger("Console");
	my $maxUsers = $self->getParamValue('maxUsers');
	if (($self->maxPassUsers != $maxUsers) && ($self->maxPassUsers != 0)) {
		$console_logger->info("Workload ",$self->workload->instanceNum,", appInstance ",
				$self->instanceNum, ": Max passing load = ", $self->maxPassUsers);
	} elsif ($self->maxPassUsers == $maxUsers) {
		$console_logger->info("Workload ",$self->workload->instanceNum,
				", appInstance ", $self->instanceNum,
				": Max passing load would exceed maximum number of loaded db users ($maxUsers)");
	} else {
		$console_logger->info("Workload ",$self->workload->instanceNum,
				", appInstance ", $self->instanceNum,
				": Did not pass at any load.");
	}
}

sub resetFindMax {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"resetFindMax ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	$self->minFailUsers(99999999);
	$self->maxPassUsers(0);
	$self->alreadyFoundMax(0);

	$self->curRateStep(int( ( $self->curRateStep / 2 ) + 0.5 ));

}

sub getFindMaxInfoString {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getFindMaxInfoString ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
	my $returnString =
	    "Workload "
	  . $self->workload->instanceNum
	  . ", appInstance "
	  . $self->instanceNum . ": ";
	$returnString .= " Users = " . $self->users;
	$returnString .= " InitialRateStep = " . $self->curRateStep;
	return $returnString;
}

sub setPortNumbers {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"setPortNumbers start ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "setPortNumbers " . $service->name . "\n" );
			$service->setPortNumbers();
		}
	}
	$logger->debug(
		"setPortNumbers finish ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub setExternalPortNumbers {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"setExternalPortNumbers start ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		open( my $fileout, ">/dev/null" ) || die "Error opening /dev/null:$!";
		foreach my $service (@$servicesRef) {
			$logger->debug( "setExternalPortNumbers " . $service->name . "\n" );
			if ( $service->isRunning($fileout) ) {
				$service->setExternalPortNumbers();
			}
		}
		close $fileout;
	}
	$logger->debug(
		"setExternalPortNumbers finish ",
		"Workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub setLoadPathType {
	my ( $self, $loadPathType ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug("setLoadPathType to $loadPathType");
	
	if (($loadPathType eq 'interval') && (!$self->hasLoadPath())) {
		$logger->error("When using the interval run strategy, you must define a userLoadPath for all AppInstances");
		exit 1;
	}
	
	if (($loadPathType eq 'fixed') && ($self->hasLoadPath())) {
		$logger->error("When using the fixed or findMaxMultiRun run strategy you must not define a userLoadPath for any AppInstances");
		exit 1;
	}
	
	$self->setParamValue('loadPathType', $loadPathType);
}

sub startServices {
	my ( $self, $serviceTier, $setupLogDir, $forked ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl         = $self->getParamValue('workloadImpl');
	
	my $appInstanceName = $self->name;
	my $logName         = "$setupLogDir/start-$serviceTier-$appInstanceName.log";
	my $logFile;
	open( $logFile, " > $logName " ) or die " Error opening $logName: $!";

	my $users    = $self->dataManager->getParamValue('maxUsers');
	$logger->debug(
		"startServices for serviceTier $serviceTier, workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", impl = $impl", 
		" users = $users",
		" setupLogDir = $setupLogDir"
	);

	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypes = $serviceTiersHashRef->{$serviceTier};
	if ($serviceTypes) {	
		$logger->debug("startServices for serviceTier $serviceTier, serviceTypes = @$serviceTypes");
		foreach my $serviceType (@$serviceTypes) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
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
		my $allIsRunningAndUp = $self->isRunningAndUpServices($serviceTier, $logFile, $forked);
		if ( !$allIsRunningAndUp ) {
			close $logFile;
			return 0;
		}
	}
	close $logFile;
	return 1;
}

sub stopServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	my $appInstanceName = $self->name;
	$logger->debug("stopServices for serviceTier $serviceTier, workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", impl = $impl"	);

	my $logName         = "$setupLogDir/stop-$serviceTier-$appInstanceName.log";
	my $logFile;
	open( $logFile, " > $logName " ) or die " Error opening $logName: $!";

	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypesRef = $serviceTiersHashRef->{$serviceTier};	
	if ($serviceTypesRef) {
		foreach my $serviceType ( reverse @$serviceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			if ($#{$servicesRef} >= 0) {
				# Use the first instance of the service for stopping the 
				# service instances
				my $serviceRef = $servicesRef->[0];
				if ( $serviceRef->isReachable() ) {
					$logger->debug( "stop " . $serviceRef->name . "\n" );
					$serviceRef->stop($serviceType, $setupLogDir);
				}
			} else {
				next;
			}
		}
		my $allIsStopped = $self->waitForServicesStopped($serviceTier, 15, 6, 15, $logFile);
	}
	close $logFile;
	
}

sub stopDataManager {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug("stopDataManager with logDir $setupLogDir");

	my $appInstanceName = $self->name;
	my $logName         = "$setupLogDir/stopDataManager-$appInstanceName.log";
	my $logFile;
	open( $logFile, " > $logName " ) or die " Error opening $logName: $!";
	$self->dataManager->stopDataManagerContainer($logFile);
	close $logFile;
}

sub isRunningAndUpServices {
	my ( $self, $serviceTier, $logFile, $forked ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	my $console_logger = get_logger("Console");
	
	my $workloadNum    = $self->workload->instanceNum;
	my $appInstanceNum = $self->instanceNum;
		
	# Make sure that all of the services are running and up (ready for requests)
	$logger->debug(
		"Checking that all $serviceTier services are running for appInstance $appInstanceNum of workload $workloadNum." );
	my $retries=20;
	if ($serviceTier eq "backend") {
		# because of pre-warming we allow the backend longer to start
		$retries = 60;
	}
	my $allIsRunning = $self->waitForServicesRunning($serviceTier, 15, $retries, 30, $logFile);
	if ( !$allIsRunning ) {
		$console_logger->error(
			"Couldn't bring to running all $serviceTier services for appInstance $appInstanceNum of workload $workloadNum." );
		if ($forked) {
			exit;
		} else {
			return 0;
		}
	}
	$logger->debug(
		"Checking that all $serviceTier services are up for appInstance $appInstanceNum of workload $workloadNum." );
	my $allIsUp = $self->waitForServicesUp($serviceTier, 15, 40, 30, $logFile);
	if ( !$allIsUp ) {
		$console_logger->error(
			"Couldn't bring up all $serviceTier services for appInstance $appInstanceNum of workload $workloadNum." );
		if ($forked) {
			exit;
		} else {
			return 0;
		}
	}
	$logger->debug( "All $serviceTier services are up for appInstance $appInstanceNum of workload $workloadNum." );
	return 1;
}

# Running == the process is started, but the application may not be ready to accept requests
sub waitForServicesRunning {
	my ( $self, $serviceTier, $initialDelaySeconds, $retries, $periodSeconds, $logFile ) = @_;
	
	sleep $initialDelaySeconds;
	
	my $impl   = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypesRef = $serviceTiersHashRef->{$serviceTier};
	if ($serviceTypesRef) {
		while ($retries >= 0) {
			my $allIsRunning = 1;
			foreach my $serviceType ( reverse @$serviceTypesRef ) {
				my $servicesRef = $self->getAllServicesByType($serviceType);
				if ($#{$servicesRef} >= 0) {
					foreach my $serviceRef (@$servicesRef) {
						my ($serviceIsRunning, $errorStr) = $serviceRef->isRunning($logFile);
						if (!$serviceIsRunning && defined $errorStr) {
							return 0; #short circuit waiting, retries, and sleeps in cases like FailedScheduling
						}
						$allIsRunning &= $serviceIsRunning;
						if (!$allIsRunning) {
							last;  #short circuit checking all services
						}
						if ((ref $serviceRef->host) eq "KubernetesCluster") {
							last;  #for Kubernetes, use only the first instance to check with num
						}
					}
					if (!$allIsRunning) {
						last;  #short circuit checking all types
					}
				} else {
					next;
				}
			}
		
			if ($allIsRunning) {
				return 1;
			}
			sleep $periodSeconds;
			$retries--;
		}
	}
	return 0;
}

# Running == the process is started, but the application may not be ready to accept requests
sub waitForServicesStopped {
	my ( $self, $serviceTier, $initialDelaySeconds, $retries, $periodSeconds, $logFile ) = @_;
	
	sleep $initialDelaySeconds;
	
	my $impl   = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypesRef = $serviceTiersHashRef->{$serviceTier};
	if ($serviceTypesRef) {
		while ($retries >= 0) {
			my $allIsStopped = 1;
			foreach my $serviceType ( reverse @$serviceTypesRef ) {
				my $servicesRef = $self->getAllServicesByType($serviceType);
				if ($#{$servicesRef} >= 0) {
					# Use the first instance of the service for isStopped the 
					# service instances
					my $serviceRef = $servicesRef->[0];
					$allIsStopped &= $serviceRef->isStopped($logFile);
					if (!$allIsStopped) {
						last;  #short circuit checking all types
					}
				} else {
					next;
				}
			}
			if ($allIsStopped) {
				return 1;
			}
			sleep $periodSeconds;
			$retries--;
		}
	}
	return 0;
}

# Up == the process is started and the application is ready to accept requests
sub waitForServicesUp {
	my ( $self, $serviceTier, $initialDelaySeconds, $retries, $periodSeconds, $logFile ) = @_;
	
	sleep $initialDelaySeconds;
	
	my $impl   = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypesRef = $serviceTiersHashRef->{$serviceTier};
	if ($serviceTypesRef) {
		while ($retries >= 0) {
			my $allIsUp = 1;
			foreach my $serviceType ( reverse @$serviceTypesRef ) {
				my $servicesRef = $self->getAllServicesByType($serviceType);
				if ($#{$servicesRef} >= 0) {
					foreach my $serviceRef (@$servicesRef) {
						$allIsUp &= $serviceRef->isUp($logFile);
						if (!$allIsUp) {
							last;  #short circuit checking all services
						}
						if ((ref $serviceRef->host) eq "KubernetesCluster") {
							last;  #for Kubernetes, use only the first instance to check with num
						}
					}
					if (!$allIsUp) {
						last;  #short circuit checking all types
					}
				} else {
					next;
				}
			}
		
			if ($allIsUp) {
				return 1;
			}
			sleep $periodSeconds;
			$retries--;
		}
	}
	return 0;
}

sub removeServices {
	my ( $self, $serviceTier, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug("removing $serviceTier services with log dir $setupLogDir");

	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $serviceTypesRef = $serviceTiersHashRef->{$serviceTier};
	if ($serviceTypesRef) {
		foreach my $serviceType ( reverse @$serviceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			if ($#{$servicesRef} >= 0) {
				# Use the first instance of the service for removing the 
				# service instances
				my $serviceRef = $servicesRef->[0];
				$serviceRef->remove($setupLogDir);
			} else {
				next;
			}
		}
	}
}

sub isUp {
	my ( $self, $retriesRemaining, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"isUp for workload ", $self->workload->instanceNum,
		", appInstance ",     $self->instanceNum
	);
	my $impl  = $self->getParamValue('workloadImpl');
	my $allUp = 1;
	my $isUp;

	my $appInstanceName = $self->name;
	my $logName         = "$logPath/isUp-$appInstanceName.log";
	my $log;
	open( $log, " > $logName " ) or die " Error opening $logName: $!";

	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $dataServiceTypes           = $serviceTiersHashRef->{"data"};
	my $backendServiceTypes        = $serviceTiersHashRef->{"backend"};
	my $frontendServiceTypes       = $serviceTiersHashRef->{"frontend"};
	my $infrastructureServiceTypes = $serviceTiersHashRef->{"infrastructure"};

	foreach my $serviceType ( @$dataServiceTypes, @$backendServiceTypes, @$frontendServiceTypes, @$infrastructureServiceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$isUp = $service->isUp($log);
			if ( !$isUp ) {
				$allUp = 0;
				if ( ( $retriesRemaining == 0 ) && !$isUp ) {

					# no more retries so give an error
					my $hostname = $service->host->name;
					$console_logger->error( "Couldn't start $serviceType "
						  . $service->getImpl() . " on "
						  . $hostname
						  . ". Check logs for run." );
				}
			}
		}
	}
	$logger->debug(
		"isUp finished for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", impl = $impl returning ", $allUp
	);

	close $log;
	return $allUp;

}

sub isUpDataServices {
	my ( $self, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"isUpDataServices for workload ", $self->workload->instanceNum,
		", appInstance ",                 $self->instanceNum
	);
	my $retries = $self->getParamValue('isUpRetries');
	my $allUp;
	my $impl = $self->getParamValue('workloadImpl');

	my $appInstanceName = $self->name;
	my $logName         = "$logPath/isUpDataServices-$appInstanceName.log";
	my $log;
	open( $log, " > $logName " ) or die " Error opening $logName: $!";

	my $isUp;
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $dataServiceTypes           = $serviceTiersHashRef->{"data"};

	do {
		sleep 30;
		$allUp = 1;
		$retries--;
		foreach my $serviceType (@$dataServiceTypes) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$isUp = $service->isUp($log);
				if ( !$isUp ) {
					$allUp = 0;
					if ( $retries == 0 ) {

						# no more retries so give an error
						$console_logger->error( "Couldn't start $serviceType "
							  . $service->getImpl() . " on "
							  . $service->host->name
							  . ". Check logs for run. " );
					}
				}
			}
		}
	} while ( ( $retries > 0 ) && !$allUp );

	close $log;
	$logger->debug(
		"isUpDataServices finished for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", impl = $impl returning ", $allUp
	);
	return $allUp;

}

sub clearDataServicesBeforeStart {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"clearDataServicesBeforeStart for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $impl             = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $dataServiceTypes           = $serviceTiersHashRef->{"data"};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->clearDataBeforeStart($setupLogDir);
		}
	}
	$logger->debug(
		"clearDataServicesBeforeStart finished for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub clearDataServicesAfterStart {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"clearDataServicesAfterStart for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

	my $impl             = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $dataServiceTypes           = $serviceTiersHashRef->{"data"};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->clearDataAfterStart($setupLogDir);
		}
	}
	$logger->debug(
		"clearDataServicesAfterStart finish for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub cleanDataServiceStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanDataServiceStatsFiles for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
	my $pid;
	my @pids;

	if ( $self->getParamValue('logLevel') >= 3 ) {

		my $impl             = $self->getParamValue('workloadImpl');
		my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
		my $dataServiceTypes           = $serviceTiersHashRef->{"data"};
		foreach my $serviceType (@$dataServiceTypes) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					exit;
				}
				else {
					push @pids, $pid;
				}
				$service->cleanStatsFiles();
			}
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
	$logger->debug(
		"cleanDataServiceStatsFiles finish for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

}

sub cleanDataServiceLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanDataServiceLogFiles for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
	my $pid;
	my @pids;

	# clean log files on services
	my $impl             = $self->getParamValue('workloadImpl');
	my $serviceTiersHashRef = $WeathervaneTypes::workloadToServiceTypes{$impl};
	my $dataServiceTypes           = $serviceTiersHashRef->{"data"};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$pid = fork();
			if ( !defined $pid ) {
				$logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				$service->cleanLogFiles();
				exit;
			}
			else {
				push @pids, $pid;
			}
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
	$logger->debug(
		"cleanDataServiceLogFiles finish for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

}

sub cleanupDataServices {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanupDataServices for workload ", $self->workload->instanceNum,
		", appInstance ",                    $self->instanceNum
	);

	$self->cleanDataServiceStatsFiles();
	$self->cleanDataServiceLogFiles();

	$logger->debug(
		"cleanupDataServices finish for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanStatsFiles for workload ", $self->workload->instanceNum,
		", appInstance ",                $self->instanceNum
	);
	my $pid;
	my @pids;

	if ( $self->getParamValue('logLevel') >= 3 ) {

		my $impl         = $self->getParamValue('workloadImpl');
		my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
		foreach my $serviceType (@$serviceTypes) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				if ( $service->isReachable() ) {
					$logger->debug( ": CleanStatsFiles for " . $service->name . "\n" );
					$pid = fork();
					if ( !defined $pid ) {
						$logger->error("Couldn't fork a process: $!");
						exit(-1);
					}
					elsif ( $pid == 0 ) {
						$service->cleanStatsFiles();
						exit;
					}
					else {
						push @pids, $pid;
					}
				}
			}
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub cleanLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanLogFiles for workload ", $self->workload->instanceNum,
		", appInstance ",              $self->instanceNum
	);
	my $pid;
	my @pids;

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( ": cleanLogFiles for " . $service->name . "\n" );
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					$service->cleanLogFiles();
					exit;
				}
				else {
					push @pids, $pid;
				}
			}
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub startStatsCollection {
	my ($self, $tmpDir)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"startStatsCollection for workload ", $self->workload->instanceNum,
		", appInstance ",                     $self->instanceNum
	);

	my $intervalLengthSec = $self->getParamValue('statsInterval');
	my $steadyStateLength = $self->getParamValue('numQosPeriods') * $self->getParamValue('qosPeriodSec');
	my $numIntervals      = floor( $steadyStateLength / ( $intervalLengthSec * 1.0 ) );

	$console_logger->info("Starting performance statistics collection on application services.\n");

	# Start starts collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->startStatsCollection( $intervalLengthSec, $numIntervals, $tmpDir );
		}
	}
}

sub stopStatsCollection {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"stopStatsCollection for workload ", $self->workload->instanceNum,
		", appInstance ",                    $self->instanceNum
	);

	# Start stops collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->stopStatsCollection();
		}
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getStatsFiles for workload ", $self->workload->instanceNum,
		", appInstance ",              $self->instanceNum
	);

	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/appInstance" . $self->instanceNum;
	}

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $service->host->name;
				if ( !( -e $destinationPath ) ) {
					`mkdir -p $destinationPath`;
				}
				$service->getStatsFiles($destinationPath);
			}
		}
	}
}

sub getLogFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getLogFiles for workload ", $self->workload->instanceNum,
		", appInstance ",            $self->instanceNum
	);

	my $pid;
	my @pids;

	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/appInstance" . $self->instanceNum;
	}

	#  collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					my $name = $service->host->name;
					my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $name;
					if ( !( -e $destinationPath ) ) {
						`mkdir -p $destinationPath`;
					}
					$service->getLogFiles($destinationPath);
					exit;
				}
				else {
					push @pids, $pid;
				}
			}
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub getDeployedConfiguration {
	my ( $self, $destinationPath) = @_;
	
}

sub getConfigFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getConfigFiles for workload ", $self->workload->instanceNum,
		", appInstance ",               $self->instanceNum
	);
	my $pid;
	my @pids;
	
	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/appInstance" . $self->instanceNum;
	}
	if ( !( -e $newBaseDestinationPath ) ) {
		`mkdir -p $newBaseDestinationPath`;
	}

	# If AI is running on Kubernetes, get the layout of the pods
	$self->getDeployedConfiguration($newBaseDestinationPath);

	#  collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					my $name = $service->host->name;
					my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $name;
					if ( !( -e $destinationPath ) ) {
						`mkdir -p $destinationPath`;
					}
					$service->getConfigFiles($destinationPath);
					exit;
				}
				else {
					push @pids, $pid;
				}
			}
		}
	}

	foreach $pid (@pids) {
		waitpid $pid, 0;
	}

}

sub sanityCheckServices {
	my ( $self, $cleanupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"sanityCheckServices for workload ", $self->workload->instanceNum,
		", appInstance ",                    $self->instanceNum
	);

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	my $passed       = 1;
	foreach my $serviceType (@$serviceTypes) {
		my $servicesListRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesListRef) {
			$passed = $service->sanityCheck($cleanupLogDir) && $passed;
		}
	}

	$logger->debug(
		"sanityCheckServices finish for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum,
		", impl = $impl. Returning ", $passed
	);

	return $passed;
}

sub cleanup {
	my ( $self, $cleanupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");

}

sub cleanData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanData for workload ", $self->workload->instanceNum,
		", appInstance ",          $self->instanceNum
	);

	my $users = $self->users;

	return $self->dataManager->cleanData( $users, $setupLogDir );
}

sub prepareDataServices {
	my ( $self, $setupLogDir, $forked ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $users = $self->users;
	$logger->debug(
		"prepareDataServices for workload ", $self->workload->instanceNum,
		", appInstance ",            $self->instanceNum,
		", users ",            $users,
		", logDir ",            $setupLogDir
	);

	my $allIsStarted = $self->dataManager->prepareDataServices( $users, $setupLogDir );
	if (!$allIsStarted && $forked) {
		exit;
	}
	return $allIsStarted;
}

sub prepareData {
	my ( $self, $setupLogDir, $forked ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $users = $self->users;
	$logger->debug(
		"prepareData for workload ", $self->workload->instanceNum,
		", appInstance ",            $self->instanceNum,
		", users ",            $users,
		", logDir ",            $setupLogDir
	);

	my $allIsStarted = $self->dataManager->prepareData( $users, $setupLogDir );
	if (!$allIsStarted && $forked) {
		exit;
	}
	return $allIsStarted;
}

sub loadData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"loadData for workload ", $self->workload->instanceNum,
		", appInstance ",         $self->instanceNum
	);
	my $users = $self->users;

	$self->dataManager->loadData( $users, $setupLogDir );
}

sub workloadRunning {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug("appInstance workloadRunning");
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->workloadRunning();
		}
	}

}

sub getHostStatsSummary {
	my ( $self, $csvRef, $statsLogPath, $filePrefix, $prefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getHostStatsSummary for workload ", $self->workload->instanceNum,
		", appInstance ",                    $self->instanceNum
	);
	tie( my %csvRefByHostname, 'Tie::IxHash' );
}

sub getStatsSummary {
	my ( $self, $csvRef, $prefix, $statsLogPath ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getStatsSummary for workload ", $self->workload->instanceNum,
		", appInstance ",                $self->instanceNum
	);

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		my $numServices = $#$servicesRef;
		if ( $numServices < 1 ) {

			# Only include services for which there is an instance
			next;
		}

		# Only call getStatsSummary on one service of each type.
		my $service         = $servicesRef->[0];
		my $destinationPath = $statsLogPath . "/" . $serviceType;
		my $tmpCsvRef       = $service->getStatsSummary($destinationPath);
		foreach my $key ( keys %$tmpCsvRef ) {
			$csvRef->{ $prefix . $key } = $tmpCsvRef->{$key};
		}
	}
	$logger->debug(
		"getStatsSummary finished for workload ",
		$self->workload->instanceNum,
		", appInstance ",
		$self->instanceNum
	);

}

__PACKAGE__->meta->make_immutable;

1;

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

has 'minRateStep' => (
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

has 'lastTargetUtUtilization' => (
	is      => 'rw',
	isa     => 'Num',
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

has 'configPath' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
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

override 'initialize' => sub {
	my ($self) = @_;
	super();

	my $logger = get_logger("Weathervane::AppInstance::AppInstance");

	$self->curRateStep( $self->getParamValue('initialRateStep') );
	$self->minRateStep( $self->getParamValue('minRateStep') );

	# if the distDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $weathervaneHome = $self->getParamValue('weathervaneHome');
	my $distDir         = $self->getParamValue('distDir');
	if ( !( $distDir =~ /^\// ) ) {
		$distDir = $weathervaneHome . "/" . $distDir;
	}
	$self->setParamValue( 'distDir', $distDir );

	$self->users( $self->getParamValue('users') );
	my $userLoadPath = $self->getParamValue('userLoadPath');
	if ( $#$userLoadPath >= 0 ) {
		$logger->debug( "AppInstance " . $self->getParamValue('instanceNum') . " uses a user load path." );
		my $parsedPathRef = parseLoadPath($userLoadPath);
		my $maxUsers         = $parsedPathRef->[0];
		if ( $maxUsers > $self->users ) {
			$self->users($maxUsers);
		}
	}

};

sub initializeServiceConfig {
	my ($self)         = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $console_logger = get_logger("Console");

	$self->configPath( $self->getParamValue('configPath') );
	my $serviceTypeToInitialMaxMinListHash = $self->parseConfigPath( $self->configPath );

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $initialNum = $serviceTypeToInitialMaxMinListHash->{$serviceType}->[0];
		my $maxNum     = $serviceTypeToInitialMaxMinListHash->{$serviceType}->[1];
		my $minNum     = $serviceTypeToInitialMaxMinListHash->{$serviceType}->[2];
		my $totalNum   = $self->getTotalNumOfServiceType($serviceType);
		$logger->debug(
			"For service $serviceType got initial number $initialNum, max number $maxNum, and min number $minNum");
		if ( $maxNum > $totalNum ) {
			$console_logger->warn(
				    "Error: The specified configPath requires at least $maxNum instances of service-type $serviceType, "
				  . "but there are only $totalNum specified in the config file." );
			exit -1;
		}
		$self->initialNumServicesByTypeHashRef->{$serviceType} = $initialNum;
		$self->maxNumServicesByTypeHashRef->{$serviceType}     = $maxNum;

		# Now mark the initial services as active
		my $servicesListRef = $self->getAllServicesByType($serviceType);
		for ( my $i = 0 ; $i < $initialNum ; $i++ ) {
			$servicesListRef->[$i]->isActive(1);
		}
	}

}

sub parseConfigPath {
	my ( $self, $configPath ) = @_;
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	my $console_logger = get_logger("Console");

	# This is a hash from a serviceType to a a tuple of the
	# initial number of that service type that are active and the
	# maximum number of that type.
	my $serviceTypeToInitialMaxMinListHash = {};

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {

		# Initialize the results to me the total number of services, which
		# will be changed if this service is include in a config path.
		my $initialNumServices = $self->getTotalNumOfServiceType($serviceType);
		$serviceTypeToInitialMaxMinListHash->{$serviceType} =
		  [ $initialNumServices, $initialNumServices, $initialNumServices ];
	}

	if ( ( $#$configPath + 1 ) > 0 ) {

		# Get the initial number of services for those service types mentioned in the first interval.
		# If a service isn't mentioned in the first interval then it starts with all specified
		# instances of the service type.
		my $firstInterval = $configPath->[0];
		foreach my $serviceType (@$serviceTypes) {
			my $indexName = "num" . ucfirst($serviceType) . "s";
			if ( ( exists $firstInterval->{$indexName} ) && ( defined $firstInterval->{$indexName} ) ) {
				$serviceTypeToInitialMaxMinListHash->{$serviceType}->[0] = $firstInterval->{$indexName};
				$serviceTypeToInitialMaxMinListHash->{$serviceType}->[1] = $firstInterval->{$indexName};
				$serviceTypeToInitialMaxMinListHash->{$serviceType}->[2] = $firstInterval->{$indexName};
			}
		}

		# Now find the maximum for each service type mentioned in a configPath
		foreach my $configInterval (@$configPath) {
			foreach my $serviceType (@$serviceTypes) {
				my $curMax    = $serviceTypeToInitialMaxMinListHash->{$serviceType}->[1];
				my $curMin    = $serviceTypeToInitialMaxMinListHash->{$serviceType}->[2];
				my $indexName = "num" . ucfirst($serviceType) . "s";
				if ( ( exists $configInterval->{$indexName} ) && ( defined $configInterval->{$indexName} ) ) {
					if ( $configInterval->{$indexName} > $curMax ) {
						$serviceTypeToInitialMaxMinListHash->{$serviceType}->[1] = $configInterval->{$indexName};
					}
					if ( $configInterval->{$indexName} < $curMin ) {
						$serviceTypeToInitialMaxMinListHash->{$serviceType}->[2] = $configInterval->{$indexName};
					}
				}
			}
		}
	}

	$logger->debug( "Parsed config path.  For web server got initialNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"webServer"}->[0]
		  . ", maxNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"webServer"}->[1]
		  . ", minNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"webServer"}->[2] );
	$logger->debug( "Parsed config path.  For app server got initialNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"appServer"}->[0]
		  . ", maxNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"appServer"}->[1]
		  . ", minNumServices = "
		  . $serviceTypeToInitialMaxMinListHash->{"appServer"}->[2] );
	return $serviceTypeToInitialMaxMinListHash;
}

sub getConfigPath {
	my ( $self, $serviceType ) = @_;

	return $self->configPath;
}

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

sub getInitialNumOfServiceType {
	my ( $self, $serviceType ) = @_;
	return $self->initialNumServicesByTypeHashRef->{$serviceType};
}

sub getMaxNumOfServiceType {
	my ( $self, $serviceType ) = @_;
	return $self->maxNumServicesByTypeHashRef->{$serviceType};
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

sub getInactiveServicesByType {
	my ( $self, $serviceType ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	my $servicesListRef       = $servicesByTypeHashRef->{$serviceType};
	my $logger                = get_logger("Weathervane::AppInstance::AppInstance");

	my @inactiveServices = ();
	foreach my $service (@$servicesListRef) {
		if ( !$service->isActive ) {
			push @inactiveServices, $service;
		}
	}

	$logger->debug("getInactiveServicesByType for type $serviceType returning: @inactiveServices");

	return \@inactiveServices;
}

sub getActiveServicesByType {
	my ( $self, $serviceType ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	my $servicesListRef       = $servicesByTypeHashRef->{$serviceType};
	my $logger                = get_logger("Weathervane::AppInstance::AppInstance");

	my @activeServices = ();
	foreach my $service (@$servicesListRef) {
		if ( $service->isActive ) {
			push @activeServices, $service;
		}
	}
	$logger->debug("getActiveServicesByType for type $serviceType returning: @activeServices");

	return \@activeServices;
}

sub getServiceByTypeAndName {
	my ( $self, $serviceType, $dockerName ) = @_;
	my $servicesByTypeHashRef = $self->servicesByTypeHashRef;
	my $servicesListRef       = $servicesByTypeHashRef->{$serviceType};
	my $logger                = get_logger("Weathervane::AppInstance::AppInstance");

	foreach my $service (@$servicesListRef) {
		if ( $service->getParamValue("dockerName") eq $dockerName ) {
			$logger->debug( "getServiceByTypeAndName for type $serviceType and name $dockerName "
				  . "returning service on host "
				  . $service->host->hostName );
			return $service;
		}
	}

	$logger->debug( "getServiceByTypeAndName for type $serviceType and name $dockerName. " . "Service not found." );
	return "";
}

sub getNumActiveOfServiceType {
	my ( $self, $serviceType ) = @_;
	my $activeServicesRef = $self->getActiveServicesByType($serviceType);
	return $#{$activeServicesRef} + 1;
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

sub getInstanceNum {
	my ($self) = @_;
	return $self->getParamValue('instanceNum');
}

sub getUsers {
	my ($self) = @_;
	return $self->users;
}

sub getMaxLoadedUsers {
	my ($self)        = @_;
	my $dbServicesRef = $self->getActiveServicesByType("dbServer");
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
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('instanceNum');
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

sub getWwwHostname {
	my ($self) = @_;
	return $self->getParamValue('wwwHostname');
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
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	if ( $self->alreadyFoundMax ) {
		return;
	}

	my $passed      = $self->passedLast();
	my $users       = $self->users;
	my $curRateStep = $self->curRateStep;
	my $minRateStep = $self->minRateStep;
	my $maxPass     = $self->maxPassUsers;
	my $minFail     = $self->minFailUsers;

	if ($passed) {

		if ( $users > $maxPass ) {
			$self->maxPassUsers($users);
		}

		# Get a rate step that leaves next run at below minFail
		while ( ( $users + $curRateStep ) >= $minFail ) {
			$curRateStep = ceil( $curRateStep / 2 );
			if ( $curRateStep < $minRateStep ) {
				$curRateStep = $minRateStep;
				last;
			}
		}

		$self->users( $users + $curRateStep );
		$self->curRateStep($curRateStep);

	}
	else {
		if ( $users < $minFail ) {
			$self->minFailUsers($users);
		}

		while ( ( $users - $curRateStep ) <= $maxPass ) {
			$curRateStep = ceil( $curRateStep / 2 );
			if ( $curRateStep < $minRateStep ) {
				$curRateStep = $minRateStep;
				last;
			}
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
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
}

sub adjustUsersForTargetUt {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"adjustUsersForTargetUt start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	if ( $self->alreadyFoundMax ) {
		return;
	}

	my $passed                     = $self->passedLast();
	my $users                      = $self->users;
	my $targetUtilization          = $self->getParamValue('targetUtilization');
	my $targetUtilizationMarginPct = $self->getParamValue('targetUtilizationMarginPct');

	my $cpuUt = $self->lastTargetUtUtilization;

	# find the next number of users if trying to hit a target utilization.
	my $targetUtilizationMargin = $targetUtilizationMarginPct * $targetUtilization;
	my $usersPerPct             = $users / $cpuUt;
	if ( $cpuUt < ( $targetUtilization - $targetUtilizationMargin ) ) {
		$users = ceil( $users + ( $targetUtilization - $cpuUt ) * $usersPerPct );
		if ( $users > $self->minHighUTUsers ) {
			$users = ceil( ( $self->maxLowUTUsers + $self->minHighUTUsers ) / 2 );
		}
	}
	elsif ( $cpuUt > ( $targetUtilization + $targetUtilizationMargin ) ) {
		$users = floor( $users - ( $cpuUt - $targetUtilization ) * $usersPerPct );
		if ( $users < $self->maxLowUTUsers ) {
			$users = ceil( ( $self->maxLowUTUsers + $self->minHighUTUsers ) / 2 );
		}
	}

	$self->users($users);
	$logger->debug(
		"adjustUsersForTargetUt end ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
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
	my $curRateStep = $self->curRateStep;
	my $minRateStep = $self->minRateStep;
	my $maxPass     = $self->maxPassUsers;
	my $minFail     = $self->minFailUsers;
	my $minUsers    = $self->getParamValue('minimumUsers');

	if ($passed) {

		# At a maximum if can't run another run, even at minimum
		# step size, at a number of users lower than the current
		# minFail
		while ( ( $users + $curRateStep ) >= $minFail ) {
			$curRateStep = ceil( $curRateStep / 2 );
			if ( $curRateStep < $minRateStep ) {
				$curRateStep = $minRateStep;
				last;
			}
		}

		if ( ( $users + $curRateStep ) >= $minFail ) {

			# Already failed at one step increase
			$console_logger->info(
				"Workload ",
				$self->getParamValue('workloadNum'),
				", appInstance ",
				$self->getParamValue('instanceNum'),
				": At maximum of $users"
			);
			$foundMax = 1;

		}

	}
	else {

		# Run Failed.  Determine whether already hit maximum.
		# At a maximum if can't run another run, even at minimum
		# step size, at a number of users higher than the current
		# maxPass
		while ( ( $users - $curRateStep ) <= $maxPass ) {
			$curRateStep = ceil( $curRateStep / 2 );
			if ( $curRateStep < $minRateStep ) {
				$curRateStep = $minRateStep;
				last;
			}
		}

		my $nextUsers = $users - $curRateStep;
		if ( ( $nextUsers <= $maxPass ) || ( $nextUsers < $minUsers ) ) {
			$console_logger->info(
				"Workload ",
				$self->getParamValue('workloadNum'),
				", appInstance ",
				$self->getParamValue('instanceNum'),
				": At maximum of $maxPass"
			);

			# put the users back to maxPass
			$self->users($maxPass);
			$foundMax = 1;
		}
	}

	$self->alreadyFoundMax($foundMax);
	$logger->debug(
		"foundMax return " . $foundMax,
		". Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	return $foundMax;
}

sub hitTargetUt {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"hitTargetUt start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	my $console_logger = get_logger("Console");
	my $foundMax       = 0;
	if ( $self->alreadyFoundMax ) {
		return 1;
	}

	my $passed                       = $self->passedLast();
	my $users                        = $self->users;
	my $targetUtilization            = $self->getParamValue('targetUtilization');
	my $targetUtilizationServiceType = $self->getParamValue('targetUtilizationServiceType');
	my $targetUtilizationMarginPct   = $self->getParamValue('targetUtilizationMarginPct');

	# First need to get the average utilization for the
	my $cpuUt = $self->lastTargetUtUtilization;
	$console_logger->info(
		"For workload ",
		$self->getParamValue('workloadNum'),
		", AppInstance ",
		$self->getParamValue('instanceNum'),
		", the average CPU Utilization for $targetUtilizationServiceType tier was $cpuUt"
	);

	# find the next number of users if trying to hit a target utilization.
	my $targetUtilizationMargin = $targetUtilizationMarginPct * $targetUtilization;
	if (   ( $cpuUt >= ( $targetUtilization - $targetUtilizationMargin ) )
		&& ( $cpuUt <= ( $targetUtilization + $targetUtilizationMargin ) ) )
	{
		$foundMax = 1;
	}
	elsif ( $cpuUt < ( $targetUtilization - $targetUtilizationMargin ) ) {
		if ( !$passed ) {
			$console_logger->error(
				"Run Failed.  Workload ",
				$self->getParamValue('workloadNum'),
				", AppInstance ",
				$self->getParamValue('instanceNum'),
				", cannot reach target CPU utilization. Failed at $cpuUt\%"
			);
			exit(-1);
		}
		my $usersPerPct = $users / $cpuUt;
		if ( $cpuUt > $self->maxLowUT ) {

			# keep track of low utilization closest to target and
			# the number of users that gave that utilization
			$self->maxLowUT($cpuUt);
			$self->maxLowUTUsers($users);
		}

	}
	elsif ( $cpuUt > ( $targetUtilization + $targetUtilizationMargin ) ) {
		my $usersPerPct = $users / $cpuUt;
		if ( $cpuUt < $self->minHighUT ) {

			# keep track of high utilization closest to target and
			# the number of users that gave that utilization
			$self->minHighUT($cpuUt);
			$self->minHighUTUsers($users);
		}

	}

	$self->alreadyFoundMax($foundMax);
	$logger->debug(
		"hitTargetUt return " . $foundMax,
		" Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	return $foundMax;

}

sub resetFindMax {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"resetFindMax ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	$self->minFailUsers(99999999);
	$self->maxPassUsers(0);
	$self->alreadyFoundMax(0);

	# Reduce the min rate step and start step at twice new min
	my $newMinRateStep = int( ( $self->minRateStep / 2 ) + 0.5 );
	$self->minRateStep($newMinRateStep);
	$self->curRateStep( 2 * $newMinRateStep );

}

sub getFindMaxInfoString {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getFindMaxInfoString ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $returnString =
	    "Workload "
	  . $self->getParamValue('workloadNum')
	  . ", appInstance "
	  . $self->getParamValue('appInstanceNum') . ": ";
	$returnString .= " Users = " . $self->users;
	$returnString .= " InitialRateStep = " . $self->curRateStep;
	$returnString .= " MinRateStep = " . $self->minRateStep . "\n";
	return $returnString;
}

sub configureAndStartInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $users  = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}
	my $impl         = $self->getParamValue('workloadImpl');
	my $suffix       = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');
	my $serviceTypes = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			foreach my $service (@$servicesRef) {
				$logger->debug( "Create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
}

sub configureAndStartFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"configureAndStartFrontendServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $users = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}

	my $impl         = $self->getParamValue('workloadImpl');
	my $suffix       = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');
	my $serviceTypes = $WeathervaneTypes::frontendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};

	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			foreach my $service (@$servicesRef) {
				$logger->debug( "Create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
}

sub configureAndStartBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"configureAndStartBackendServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $users = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}

	my $impl   = $self->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $serviceTypes          = $WeathervaneTypes::backendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			foreach my $service (@$servicesRef) {
				$logger->debug( "Create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}

		sleep 15;
	}
}

sub configureAndStartDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"configureAndStartDataServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $users = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}

	my $impl   = $self->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $serviceTypes          = $WeathervaneTypes::dataServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			foreach my $service (@$servicesRef) {
				$logger->debug( "Create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}

		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
}

sub startInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
}

sub startFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"startFrontendServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::frontendServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
	$logger->debug(
		"startFrontendServices finish ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
}

sub startBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"startBackendServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::backendServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
	$logger->debug(
		"startBackendServices finish ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

}

sub startDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"startDataServices start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "Start " . $service->getDockerName() . "\n" );
			$service->start($setupLogDir);
		}
	}
	$logger->debug(
		"startDataServices finish ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
}

sub pretouchData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"pretouchData start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);

	$self->dataManager->pretouchData($setupLogDir);
}

sub setPortNumbers {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"setPortNumbers start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "setPortNumbers " . $service->getDockerName() . "\n" );
			$service->setPortNumbers();
		}
	}
	$logger->debug(
		"setPortNumbers finish ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
}

sub setExternalPortNumbers {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"setExternalPortNumbers start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		open( my $fileout, ">/dev/null" ) || die "Error opening /dev/null:$!";
		foreach my $service (@$servicesRef) {
			$logger->debug( "setExternalPortNumbers " . $service->getDockerName() . "\n" );
			if ( $service->isRunning($fileout) ) {
				$service->setExternalPortNumbers();
			}
		}
		close $fileout;
	}
	$logger->debug(
		"setExternalPortNumbers finish ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
}

sub unRegisterPortNumbers {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"unRegisterPortNumbers start ",
		"Workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('instanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	$self->dataManager->unRegisterPortsWithHost();

	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "unRegisterPortNumbers " . $service->getDockerName() . "\n" );
			$service->unRegisterPortsWithHost();
		}
	}
}

sub stopInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug(
		"stopInfrastructureServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl"
	);
	my $serviceTypes = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( "stop " . $service->getDockerName() . "\n" );
				$service->stop($setupLogDir);
			}
		}
	}
}

sub stopFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug("");
	my $impl = $self->getParamValue('workloadImpl');
	$logger->debug(
		"stopFrontendServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl"
	);
	my $serviceTypes = $WeathervaneTypes::frontendServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( "stop " . $service->getDockerName() . "\n" );
				$service->stop($setupLogDir);
			}
		}
	}
}

sub stopBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug(
		"stopBackendServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl"
	);

	my $serviceTypes = $WeathervaneTypes::backendServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( "stop " . $service->getDockerName() . "\n" );
				$service->stop($setupLogDir);
			}
		}
	}
}

sub stopDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug(
		"stopDataServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl"
	);

	my $serviceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( "stop " . $service->getDockerName() . "\n" );
				$service->stop($setupLogDir);
			}
		}
	}
}

sub removeInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug("removing infrastructure services with log dir $setupLogDir");

	my $serviceTypes          = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				if ( $service->isReachable() ) {
					$logger->debug( "remove " . $service->getDockerName() . "\n" );
					$service->remove($setupLogDir);
				}
			}
		}
	}
}

sub removeFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');
	$logger->debug(
		"removeFrontendServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl"
	);

	my $serviceTypes          = $WeathervaneTypes::frontendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				if ( $service->isReachable() ) {
					$logger->debug( "remove " . $service->getDockerName() . "\n" );
					$service->remove($setupLogDir);
				}
			}
		}
	}
}

sub removeBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"removeBackendServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                      $self->getParamValue('appInstanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::backendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				if ( $service->isReachable() ) {
					$logger->debug( "remove " . $service->getDockerName() . "\n" );
					$service->remove($setupLogDir);
				}
			}
		}
	}
}

sub removeDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"removeDataServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                   $self->getParamValue('appInstanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::dataServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getAllServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				if ( $service->isReachable() ) {
					$logger->debug( "remove " . $service->getDockerName() . "\n" );
					$service->remove($setupLogDir);
				}
			}
		}
	}
}

sub createInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $impl   = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$logger->debug( "create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}
	}
}

sub createFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"createFrontendServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                       $self->getParamValue('appInstanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::frontendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {

		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$logger->debug( "create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}
	}
}

sub createBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"createBackendServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                      $self->getParamValue('appInstanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::backendServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$logger->debug( "create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}
	}
}

sub createDataServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"createDataServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                   $self->getParamValue('appInstanceNum')
	);
	my $impl = $self->getParamValue('workloadImpl');

	my $serviceTypes          = $WeathervaneTypes::dataServiceTypes{$impl};
	my $dockerServiceTypesRef = $WeathervaneTypes::dockerServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		if ( $serviceType ~~ @$dockerServiceTypesRef ) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$logger->debug( "create " . $service->getDockerName() . "\n" );
				$service->create($setupLogDir);
			}
		}
	}
}

sub configureInfrastructureServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	my $users  = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}

	my $impl   = $self->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $serviceTypes = $WeathervaneTypes::infrastructureServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}
	}
}

sub configureFrontendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"configureFrontendServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
	my $users = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}
	my $impl   = $self->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $serviceTypes = $WeathervaneTypes::frontendServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}
	}
}

sub configureBackendServices {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"configureBackendServices for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
	my $users = $self->users;

	# If in interactive mode, then configure services for maxUsers load
	my $interactive = $self->getParamValue('interactive');
	my $maxUsers    = $self->dataManager->getParamValue('maxUsers');
	if ( $interactive && ( $maxUsers > $users ) ) {
		$users = $maxUsers;
	}
	my $impl   = $self->getParamValue('workloadImpl');
	my $suffix = "_W" . $self->getParamValue('workloadNum') . "I" . $self->getParamValue('appInstanceNum');

	my $serviceTypes = $WeathervaneTypes::backendServiceTypes{$impl};
	foreach my $serviceType ( reverse @$serviceTypes ) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$logger->debug( "configure " . $service->getDockerName() . "\n" );
			$service->configure( $setupLogDir, $users, $suffix );
		}
	}
}

sub isUp {
	my ( $self, $retriesRemaining, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"isUp for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",     $self->getParamValue('appInstanceNum')
	);
	my $impl  = $self->getParamValue('workloadImpl');
	my $allUp = 1;
	my $isUp;

	my $appInstanceName = $self->getParamValue('appInstanceName');
	my $logName         = "$logPath/isUp-$appInstanceName.log";
	my $log;
	open( $log, " > $logName " ) or die " Error opening $logName: $!";

	my $dataServiceTypes           = $WeathervaneTypes::dataServiceTypes{$impl};
	my $backendServiceTypes        = $WeathervaneTypes::backendServiceTypes{$impl};
	my $frontendServiceTypes       = $WeathervaneTypes::frontendServiceTypes{$impl};
	my $infrastructureServiceTypes = $WeathervaneTypes::frontendServiceTypes{$impl};

	foreach my $serviceType ( @$dataServiceTypes, @$backendServiceTypes, @$frontendServiceTypes ) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$isUp = $service->isUp($log);
			if ( !$isUp ) {
				$allUp = 0;
				if ( ( $retriesRemaining == 0 ) && !$isUp ) {

					# no more retries so give an error
					$console_logger->error( "Couldn't start $serviceType "
						  . $service->getImpl() . " on "
						  . $service->host->hostName
						  . ". Check logs for run." );
				}
			}
		}
	}
	$logger->debug(
		"isUp finished for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
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
		"isUpDataServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                 $self->getParamValue('appInstanceNum')
	);
	my $retries = $self->getParamValue('isUpRetries');
	my $allUp;
	my $impl = $self->getParamValue('workloadImpl');

	my $appInstanceName = $self->getParamValue('appInstanceName');
	my $logName         = "$logPath/isUpDataServices-$appInstanceName.log";
	my $log;
	open( $log, " > $logName " ) or die " Error opening $logName: $!";

	my $isUp;
	my $dataServiceTypes = $WeathervaneTypes::dataServiceTypes{$impl};

	do {
		sleep 30;
		$allUp = 1;
		$retries--;
		foreach my $serviceType (@$dataServiceTypes) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
			foreach my $service (@$servicesRef) {
				$isUp = $service->isUp($log);
				if ( !$isUp ) {
					$allUp = 0;
					if ( $retries == 0 ) {

						# no more retries so give an error
						$console_logger->error( "Couldn't start $serviceType "
							  . $service->getImpl() . " on "
							  . $service->host->hostName
							  . ". Check logs for run. " );
					}
				}
			}
		}
	} while ( ( $retries > 0 ) && !$allUp );

	close $log;
	$logger->debug(
		"isUpDataServices finished for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl returning ", $allUp
	);
	return $allUp;

}

sub clearDataServicesBeforeStart {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"clearDataServicesBeforeStart for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);

	my $impl             = $self->getParamValue('workloadImpl');
	my $dataServiceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->clearDataBeforeStart($setupLogDir);
		}
	}
	$logger->debug(
		"clearDataServicesBeforeStart finished for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
}

sub clearDataServicesAfterStart {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"clearDataServicesAfterStart for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);

	my $impl             = $self->getParamValue('workloadImpl');
	my $dataServiceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->clearDataAfterStart($setupLogDir);
		}
	}
	$logger->debug(
		"clearDataServicesAfterStart finish for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
}

sub cleanDataServiceStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanDataServiceStatsFiles for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
	my $pid;
	my @pids;

	if ( $self->getParamValue('logLevel') >= 3 ) {

		my $impl             = $self->getParamValue('workloadImpl');
		my $dataServiceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
		foreach my $serviceType (@$dataServiceTypes) {
			my $servicesRef = $self->getActiveServicesByType($serviceType);
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
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);

}

sub cleanDataServiceLogFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanDataServiceLogFiles for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
	my $pid;
	my @pids;

	# clean log files on services
	my $impl             = $self->getParamValue('workloadImpl');
	my $dataServiceTypes = $WeathervaneTypes::dataServiceTypes{$impl};
	foreach my $serviceType (@$dataServiceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
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
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);

}

sub cleanupDataServices {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanupDataServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                    $self->getParamValue('appInstanceNum')
	);

	$self->cleanDataServiceStatsFiles();
	$self->cleanDataServiceLogFiles();

	$logger->debug(
		"cleanupDataServices finish for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
}

sub cleanStatsFiles {
	my ($self) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanStatsFiles for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                $self->getParamValue('appInstanceNum')
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
					$logger->debug( ": CleanStatsFiles for " . $service->getParamValue('dockerName') . "\n" );
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
		"cleanLogFiles for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",              $self->getParamValue('appInstanceNum')
	);
	my $pid;
	my @pids;

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$logger->debug( ": cleanLogFiles for " . $service->getParamValue('dockerName') . "\n" );
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
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"startStatsCollection for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                     $self->getParamValue('appInstanceNum')
	);

	my $intervalLengthSec = $self->getParamValue('statsInterval');
	my $steadyStateLength = $self->getParamValue('steadyState');
	my $numIntervals      = floor( $steadyStateLength / ( $intervalLengthSec * 1.0 ) );

	$console_logger->info("Starting performance statistics collection on application services.\n");

	# Start starts collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->startStatsCollection( $intervalLengthSec, $numIntervals );
		}
	}
}

sub stopStatsCollection {
	my ($self)         = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"stopStatsCollection for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                    $self->getParamValue('appInstanceNum')
	);

	# Start stops collection on services
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->stopStatsCollection();
		}
	}

}

sub getStatsFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getStatsFiles for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",              $self->getParamValue('appInstanceNum')
	);

	my $newBaseDestinationPath = $baseDestinationPath;
	if ($usePrefix) {
		$newBaseDestinationPath .= "/appInstance" . $self->getParamValue("instanceNum");
	}

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getAllServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $service->host->hostName;
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
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $service->host->hostName;
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

sub getConfigFiles {
	my ( $self, $baseDestinationPath, $usePrefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getConfigFiles for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",               $self->getParamValue('appInstanceNum')
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
		foreach my $service (@$servicesRef) {
			if ( $service->isReachable() ) {
				$pid = fork();
				if ( !defined $pid ) {
					$logger->error("Couldn't fork a process: $!");
					exit(-1);
				}
				elsif ( $pid == 0 ) {
					my $destinationPath = $newBaseDestinationPath . "/" . $serviceType . "/" . $service->host->hostName;
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
		"sanityCheckServices for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                    $self->getParamValue('appInstanceNum')
	);

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	my $passed       = 1;
	foreach my $serviceType (@$serviceTypes) {
		if ( $serviceType eq "ipManager" ) {
			next;
		}
		my $servicesListRef = $self->getActiveServicesByType($serviceType);

		foreach my $service (@$servicesListRef) {
			$passed = $service->sanityCheck($cleanupLogDir) && $passed;
		}
	}

	$logger->debug(
		"sanityCheckServices finish for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum'),
		", impl = $impl. Returning ", $passed
	);

	return $passed;
}

sub cleanData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"cleanData for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",          $self->getParamValue('appInstanceNum')
	);

	my $users = $self->users;

	return $self->dataManager->cleanData( $users, $setupLogDir );
}

sub prepareData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"prepareData for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",            $self->getParamValue('appInstanceNum')
	);
	my $users = $self->users;

	return $self->dataManager->prepareData( $users, $setupLogDir );
}

sub loadData {
	my ( $self, $setupLogDir ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"loadData for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",         $self->getParamValue('appInstanceNum')
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
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		foreach my $service (@$servicesRef) {
			$service->workloadRunning();
		}
	}

}

sub getHostStatsSummary {
	my ( $self, $csvRef, $statsLogPath, $filePrefix, $prefix ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getHostStatsSummary for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                    $self->getParamValue('appInstanceNum')
	);
	tie( my %csvRefByHostname, 'Tie::IxHash' );

	# Get the list of all hosts used in this workload and
	# get the stats for each such host
	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		if ( $serviceType eq "ipManager" ) {
			next;
		}
		my $servicesListRef = $self->getActiveServicesByType($serviceType);

		foreach my $service (@$servicesListRef) {
			my $hostname = $service->host->hostName;
			if (   ( !exists $csvRefByHostname{$hostname} )
				|| ( !defined $csvRefByHostname{$hostname} ) )
			{
				my $destinationPath = $statsLogPath . "/" . $hostname;
				$csvRefByHostname{$hostname} = $service->host->getStatsSummary($destinationPath);
			}

		}
	}

	# Compute averages for each service type and print a
	# file with the stats for all services
	my $workloadNum     = $self->getParamValue('workloadNum');
	my $summaryFileName = "${filePrefix}host_stats_summary.csv";
	open( HOSTCSVFILE, ">>$statsLogPath/$summaryFileName" )
	  or die "Can't open $statsLogPath/$summaryFileName: $!\n";
	print HOSTCSVFILE "Service Type, Hostname, IP Addr";
	my $firstKey   = ( keys %csvRefByHostname )[0];
	my $csvHashRef = $csvRefByHostname{$firstKey};
	foreach my $key ( keys %$csvHashRef ) {
		print HOSTCSVFILE ", $key";
	}
	print HOSTCSVFILE "\n";

	foreach my $serviceType (@$serviceTypes) {
		if ( $serviceType eq "ipManager" ) {
			next;
		}
		$logger->debug("getHostStatsSummary aggregating stats for hosts running service type $serviceType");
		my $servicesRef = $self->getActiveServicesByType($serviceType);
		my $numServices = $#$servicesRef + 1;
		if ( $numServices < 1 ) {
			$logger->debug("getHostStatsSummary there are no active ${serviceType}s to aggregate over");

			# Only include services for which there is an instance
			next;
		}
		tie( my %accumulatedCsv, 'Tie::IxHash' );
		%accumulatedCsv = ();
		my @avgKeys = ( "cpuUT", "cpuIdle_stdDev", "avgWait" );
		foreach my $service (@$servicesRef) {
			$csvHashRef = $csvRefByHostname{ $service->host->hostName };
			print HOSTCSVFILE "$serviceType," . $service->host->hostName . "," . $service->host->ipAddr;
			foreach my $key ( keys %$csvHashRef ) {
				if ( $key ~~ @avgKeys ) {
					if ( !( exists $accumulatedCsv{"${serviceType}_average_$key"} ) ) {
						$accumulatedCsv{"${serviceType}_average_$key"} = $csvHashRef->{$key};
					}
					else {
						$accumulatedCsv{"${serviceType}_average_$key"} += $csvHashRef->{$key};
					}
				}
				else {
					if ( !( exists $accumulatedCsv{"${serviceType}_total_$key"} ) ) {
						$accumulatedCsv{"${serviceType}_total_$key"} = $csvHashRef->{$key};
					}
					else {
						$accumulatedCsv{"${serviceType}_total_$key"} += $csvHashRef->{$key};
					}
				}
				print HOSTCSVFILE "," . $csvHashRef->{$key};
			}
			print HOSTCSVFILE "\n";

			$service->host->stopNscd();

		}

		# Now turn the total into averages for the "cpuUT", "cpuIdle_stdDev", and "avgWait"
		my $targetUtilizationServiceType = $self->getParamValue('targetUtilizationServiceType');
		foreach my $key (@avgKeys) {
			$accumulatedCsv{"${serviceType}_average_$key"} /= $numServices;
			if (   ( $key eq 'cpuUT' )
				&& ( $serviceType eq $targetUtilizationServiceType ) )
			{
				$self->lastTargetUtUtilization( $accumulatedCsv{"${serviceType}_average_$key"} );
			}
		}

		# Now add the key/value pairs to the returned csv
		foreach my $key ( keys %accumulatedCsv ) {
			$csvRef->{ $prefix . $key } = $accumulatedCsv{$key};
		}

	}
	close HOSTCSVFILE;
	$logger->debug(
		"getHostStatsSummary finished for workload ",
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);
}

sub getStatsSummary {
	my ( $self, $csvRef, $prefix, $statsLogPath ) = @_;
	my $logger = get_logger("Weathervane::AppInstance::AppInstance");
	$logger->debug(
		"getStatsSummary for workload ", $self->getParamValue('workloadNum'),
		", appInstance ",                $self->getParamValue('appInstanceNum')
	);

	my $impl         = $self->getParamValue('workloadImpl');
	my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};
	foreach my $serviceType (@$serviceTypes) {
		my $servicesRef = $self->getActiveServicesByType($serviceType);
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
		$self->getParamValue('workloadNum'),
		", appInstance ",
		$self->getParamValue('appInstanceNum')
	);

}

__PACKAGE__->meta->make_immutable;

1;

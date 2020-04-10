# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package AuctionKubernetesDataManager;

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

# default scale factors
my $defaultUsersScaleFactor           = 5;
my $defaultUsersPerAuctionScaleFactor = 15.0;

override 'initialize' => sub {
	my ($self) = @_;

	my $workloadNum = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	$self->name("auctiondatamanagerW${workloadNum}A${appInstanceNum}");

	super();

};

sub startDataManagerContainer {
	my ( $self, $users, $applog ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");

	my $namespace = $self->appInstance->namespace;
	my $configDir = $self->getParamValue('configDir');
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $jvmopts = $self->getParamValue('dbLoaderJvmOpts');
	my $loaderThreads = $self->getParamValue('dbLoaderThreads');
	my $prepThreads = $self->getParamValue('dbPrepThreads');

	my $springProfilesActive = $self->appInstance->getSpringProfilesActive();

	open( FILEIN,  "$configDir/kubernetes/auctionDataManager.yaml" ) or die "$configDir/kubernetes/auctionDataManager.yaml: $!\n";
	open( FILEOUT, ">/tmp/auctionDataManager-$namespace.yaml" )             or die "Can't open file /tmp/auctionDataManager-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /^\s+USERS:/ ) {
			print FILEOUT "  USERS: \"$users\"\n";
		}
		elsif ( $inline =~ /MAXUSERS:/ ) {
			print FILEOUT "  MAXUSERS: \"" . $self->getParamValue('maxUsers') . "\"\n";
		}
		elsif ( $inline =~ /USERSPERAUCTIONSCALEFACTOR:/ ) {
			print FILEOUT "  USERSPERAUCTIONSCALEFACTOR: \"" . $self->getParamValue('usersPerAuctionScaleFactor') . "\"\n";
		}
		elsif ( $inline =~ /WORKLOADNUM:/ ) {
			print FILEOUT "  WORKLOADNUM: \"$workloadNum\"\n";
		}
		elsif ( $inline =~ /JVMOPTS:/ ) {
			print FILEOUT "  JVMOPTS: \"$jvmopts\"\n";
		}
		elsif ( $inline =~ /LOADERTHREADS:/ ) {
			print FILEOUT "  LOADERTHREADS: \"$loaderThreads\"\n";
		}
		elsif ( $inline =~ /PREPTHREADS:/ ) {
			print FILEOUT "  PREPTHREADS: \"$prepThreads\"\n";
		}
		elsif ( $inline =~ /APPINSTANCENUM:/ ) {
			print FILEOUT "  APPINSTANCENUM: \"$appInstanceNum\"\n";
		}
		elsif ( $inline =~ /SPRINGPROFILESACTIVE:/ ) {
			print FILEOUT "  SPRINGPROFILESACTIVE: \"$springProfilesActive\"\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		elsif ( $inline =~ /(\s+\-\simage:\s)(.*\/)(.*\:)/ ) {
			my $version  = $self->host->getParamValue('dockerWeathervaneVersion');
			my $dockerNamespace = $self->host->getParamValue('dockerNamespace');
			print FILEOUT "${1}$dockerNamespace/${3}$version\n";
		}
		elsif ( $inline =~ /(\s+)resources/ )  {
			my $indent = $1;
			if ($self->getParamValue('useKubernetesRequests') && $self->getParamValue('useDataManagerRequests')) {
				print FILEOUT $inline;
				print FILEOUT "$indent  requests:\n";
				print FILEOUT "$indent    cpu: " . $self->getParamValue('dbLoaderCpus') . "\n";
				print FILEOUT "$indent    memory: " . $self->getParamValue('dbLoaderMem') . "\n";
			}
			do {
				$inline = <FILEIN>;
			} while(!($inline =~ /envFrom/));
			print FILEOUT $inline;			
		}
		elsif ( $inline =~ /(\s+)\-\skey\:\swvw1i1/ ) {
			print FILEOUT "${1}- key: wvw${workloadNum}i${appInstanceNum}\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;	

	my $cluster = $self->host;
	$cluster->kubernetesApply("/tmp/auctionDataManager-${namespace}.yaml", $namespace);

	sleep 15;
	my $retries = 20;
	while ($retries >= 0) {
		my $isRunning = $cluster->kubernetesAreAllPodRunningWithNum("tier=dataManager", $namespace, 1 );
		
		if ($isRunning) {
			return 1;
		}
		sleep 30;
		$retries--;
	}
	return 0;
}

sub stopDataManagerContainer {
	my ( $self, $applog ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	my $cluster = $self->host;
	
	$cluster->kubernetesDelete("configMap", "auctiondatamanager-config", $self->appInstance->namespace);
	$cluster->kubernetesDelete("deployment", "auctiondatamanager", $self->appInstance->namespace);

}

sub prepareDataServices {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionDataManager");
	my $reloadDb       = $self->getParamValue('reloadDb');
	my $appInstance    = $self->appInstance;
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;

	$console_logger->info(
		"Configuring and starting data services for appInstance $appInstanceNum of workload $workloadNum.\n" );

	# Start the data services
	if ($reloadDb) {
		# Avoid an extra stop/start cycle for the data services since we know
		# we are reloading the data
		$appInstance->clearDataServicesBeforeStart($logPath);
	}
	my $allIsStarted = $appInstance->startServices("data", $logPath, 0);
	
	if (!$allIsStarted) {
		if ($self->getParamValue("reloadOnFailure")) {
			# Delete the PVCs for this namespace and try again
			$console_logger->info(
				"Couldn't start data services for appInstance $appInstanceNum of workload $workloadNum. Clearing data and retrying.\n" );
			$appInstance->stopServices("data", $logPath);
			my $cluster = $self->host;
			my $namespace = $self->appInstance->namespace;
			$cluster->kubernetesDeleteAllWithLabelAndResourceType("app=auction", "pvc", $namespace );
			$allIsStarted = $appInstance->startServices("data", $logPath, 0);
		} else {
			$console_logger->info(
				"Couldn't start data services for appInstance $appInstanceNum of workload $workloadNum.\n" . 
				"See the Troubleshooting section of the User's Guide for assistance.\n" . 			
				"If this problem recurs, you can enable auto-remediation by setting \"reloadOnFailure\": true, in your configuration file.\n"
				);			
		}	
	}

	return $allIsStarted;
}


sub prepareData {
	my ( $self, $users, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $name        = $self->name;
	my $reloadDb       = $self->getParamValue('reloadDb');
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

	$self->startDataManagerContainer ($users, $logHandle);
		
	if ($reloadDb) {
		$appInstance->clearDataServicesAfterStart($logPath);

		# Have been asked to reload the data
		$retVal = $self->loadData( $users, $logPath );
		if ( !$retVal ) { return 0; }
	}
	else {
		if ( !$self->isDataLoaded( $users, $logPath ) ) {
			$console_logger->info(
				    "Data is not loaded for $users users for appInstance "
				  . "$appInstanceNum of workload $workloadNum. Loading data." );

			# Load the data
			$appInstance->stopServices("data", $logPath);
			$appInstance->clearDataServicesBeforeStart($logPath);
			$appInstance->startServices("data", $logPath, 0);
			$appInstance->clearDataServicesAfterStart($logPath);

			$retVal = $self->loadData( $users, $logPath );
			if ( !$retVal ) { return 0; }
		}
		else {
			$console_logger->info( "Data is already loaded for appInstance "
				  . "$appInstanceNum of workload $workloadNum." );
		}
	}

	$console_logger->info( "Preparing auctions and warming data-services for appInstance "
				  . "$appInstanceNum of workload $workloadNum." );
	print $logHandle "Exec-ing perl /prepareData.pl  in container $name\n";
	$logger->debug("Exec-ing perl /prepareData.pl  in container $name");
	my $cluster  = $self->host;	
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne("auctiondatamanager", "perl /prepareData.pl", $self->appInstance->namespace);
	print $logHandle "Output: cmdFailed = $cmdFailed, outString = $outString\n";
	$logger->debug("Output: cmdFailed = $cmdFailed, outString = $outString");
	if ($cmdFailed) {
		$console_logger->error( "Data preparation process failed.  Check PrepareData.log for more information." );
		$self->stopDataManagerContainer($logHandle);
		return 0;
	} 
	
	# Wait for the databases to finish any compaction
	my $cmdSucceeded = $self->waitForReady();
	if (!$cmdSucceeded) {
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
	my $logger           = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");

	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $cluster = $self->host;
	my $logName          = "$logPath/loadData-W${workloadNum}I${appInstanceNum}.log";
	my $namespace = $self->appInstance->namespace;
	
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

	$logger->debug("Exec-ing perl /loadData.pl");
	print $applog "Exec-ing perl /loadData.pl\n";
	my $kubernetesConfigFile = $cluster->getParamValue('kubeconfigFile');
	# Get the list of pods
	my $cmd;
	my $outString;	
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl get pod -o=jsonpath='{.items[*].metadata.name}' --selector=impl=auctiondatamanager --namespace=$namespace 2>&1";
	$outString = `$cmd`;
	$logger->debug("Command: $cmd");
	$logger->debug("Output: $outString");
	print $applog "Command: $cmd\n";
	print $applog "Output: $outString\n";
	my @lines = split /\s+/, $outString;
	if ($#lines < 0) {
		$console_logger->error("loadData: There are no pods with label auctiondatamanager in namespace $namespace");
		exit(-1);
	}
	
	# Get the name of the first pod
	my $podName = $lines[0];
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl exec -c auctiondatamanager --namespace=$namespace $podName -- perl /loadData.pl"; 
	$logger->debug("opening pipe with command $cmd");
	print $applog "opening pipe with command $cmd\n";
	open my $pipe, "$cmd |"   or die "Couldn't execute program: $!";
 	while ( defined( my $line = <$pipe> )  ) {
		chomp($line);
		if ($line =~ /Loading/) {
			$console_logger->info("$line\n");
		} 
		$logger->debug("Got line: $line");
		print $applog "Got line: $line\n";
   	}
   	close $pipe;	
	close $applog;
	
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
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");

	my $cluster = $self->host;
	my $namespace = $self->appInstance->namespace;
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	$logger->debug("isDataLoaded for workload $workloadNum, appInstance $appInstanceNum");

	my $logName = "$logPath/isDataLoaded-W${workloadNum}I${appInstanceNum}.log";
	my $applog;
	open( $applog, ">$logName" )
	  || die "Error opening /$logName:$!";

	print $applog "Exec-ing perl /isDataLoaded.pl\n";
	$logger->debug("Exec-ing perl /isDataLoaded.pl");
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne("auctiondatamanager", "perl /isDataLoaded.pl", $namespace);
	if ($cmdFailed) {
		$logger->debug( "Data is not loaded for workload $workloadNum, appInstance $appInstanceNum. \$cmdFailed = $cmdFailed" );
		print $applog "Data is not loaded for workload $workloadNum, appInstance $appInstanceNum. \$cmdFailed = $cmdFailed\n";
		return 0;
	}
	else {
		$logger->debug( "Data is loaded for workload $workloadNum, appInstance $appInstanceNum. \$outString = $outString" );
		print $applog "Data is loaded for workload $workloadNum, appInstance $appInstanceNum. \$outString = $outString\n";
		return 1;
	}
	close $applog;
}

sub cleanData {
	my ( $self, $users, $logHandle ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	#$nosqlServersRef->[0]->cleanData($users, $logHandle);

	my $dbServersRef = $self->appInstance->getAllServicesByType('dbServer');
	$dbServersRef->[0]->cleanData($users, $logHandle);
}

sub waitForReady {
	my ( $self ) = @_;
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
	return $nosqlServersRef->[0]->waitForReady();
}

__PACKAGE__->meta->make_immutable;

1;

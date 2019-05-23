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
	my $heap = $self->getParamValue('dbLoaderHeap');
	my $threads = $self->getParamValue('dbLoaderThreads');

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
		elsif ( $inline =~ /HEAP:/ ) {
			print FILEOUT "  HEAP: \"$heap\"\n";
		}
		elsif ( $inline =~ /THREADS:/ ) {
			print FILEOUT "  THREADS: \"$threads\"\n";
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
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;	

	my $cluster = $self->host;
	$cluster->kubernetesApply("/tmp/auctionDataManager-${namespace}.yaml", $namespace);

	sleep 15;
	my $retries = 3;
	while ($retries >= 0) {
		my $isRunning = $cluster->kubernetesAreAllPodRunningWithNum("tier=dataManager", $namespace, 1 );
		
		if ($isRunning) {
			return 1;
		}
		sleep 15;
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
	$appInstance->startServices("data", $logPath);

	close $logHandle;
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
			$appInstance->startServices("data", $logPath);
			$appInstance->clearDataServicesAfterStart($logPath);

			$retVal = $self->loadData( $users, $logPath );
			if ( !$retVal ) { return 0; }
		}
		else {
			$console_logger->info( "Data is already loaded for appInstance "
				  . "$appInstanceNum of workload $workloadNum.  Preparing data for current run." );

			# cleanup the databases from any previous run
			$self->cleanData( $users, $logHandle );

		}
	}

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

	# stop the auctiondatamanager container
	$self->stopDataManagerContainer($logHandle);

	close $logHandle;
}

sub pretouchData {
	my ( $self, $logPath ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->appInstance->instanceNum;
	my $name        = $self->name;
	my $retVal         = 0;
	$logger->debug( "pretouchData for workload ", $workloadNum );
	
	my $cluster = $self->host;
	my $namespace = $self->appInstance->namespace;
	
	my $logName = "$logPath/PretouchData_W${workloadNum}I${appInstanceNum}.log";
	my $logHandle;
	open( $logHandle, ">$logName" ) or do {
		$console_logger->error("Error opening $logName:$!");
		return 0;
	};

	# ToDo: Pretouch cassandra here or in datamanager container
	
	$logger->debug( "pretouchData complete for workload ", $workloadNum );

	close $logHandle;
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
	my $kubernetesConfigFile = $cluster->getParamValue('kubernetesConfigFile');
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
	$cmd = "KUBECONFIG=$kubernetesConfigFile kubectl exec -c auctiondatamanager --namespace=$namespace $podName perl /loadData.pl"; 
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
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::DataManager::AuctionKubernetesDataManager");
	my $workloadNum    = $self->appInstance->workload->instanceNum;
	my $appInstanceNum = $self->instanceNum;
	my $name        = $self->name;
	my $cluster = $self->host;
	my $namespace = $self->appInstance->namespace;

	my $retVal      = 0;


	$console_logger->info(
		"Cleaning and compacting storage on all data services.  This can take a long time after large runs." );
	$logger->debug("cleanData.  user = $users");

	$logger->debug(
		"cleanData. Cleaning up data services for appInstance " . "$appInstanceNum of workload $workloadNum." );
	print $logHandle "Cleaning up data services for appInstance " . "$appInstanceNum of workload $workloadNum.\n";

	print $logHandle "Exec-ing perl /cleanData.pl  in container $name\n";
	$logger->debug("Exec-ing perl /cleanData.pl  in container $name");
	my ($cmdFailed, $outString) = $cluster->kubernetesExecOne("auctiondatamanager", "perl /cleanData.pl", $namespace);
	print $logHandle "Output: cmdFailed = $cmdFailed, outString = $outString\n";
	$logger->debug("Output: cmdFailed = $cmdFailed, outString = $outString");
	if ($cmdFailed) {
		$console_logger->error(
			"Data cleaning process failed.  Check CleanData_W${workloadNum}I${appInstanceNum}.log for more information."
		);
		return 0;
	}
	
	# ToDo: Compact cassandra is not done by dataManager container
	my $nosqlServersRef = $self->appInstance->getAllServicesByType('nosqlServer');
}

__PACKAGE__->meta->make_immutable;

1;

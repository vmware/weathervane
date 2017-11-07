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
package ScheduledElasticityService;

use Moose;
use MooseX::Storage;

use Services::Service;
use Parameters qw(getParamValue);
use Statistics::Descriptive;
use Log::Log4perl qw(get_logger);
use WeathervaneTypes;
use JSON;

use LWP;
use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'ElasticityService', );

has '+version' => ( default => 'xx', );

has '+description' => ( default => '', );

# After processing the individual config paths, this has a list of
# configuration changes, where each entry is a map that has:
# "delay" => how long to wait before implementing this change
# "type" => type of service to add/remove
# "change" => number of services to add (positive) or remove (negative)
has 'configChangePath' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

override 'initialize' => sub {
	my ( $self, $numMsgServers ) = @_;

	super();
};

sub manageConfigPath {
	my ( $self, $configPathRef ) = @_;

	my $tmpDir         = $self->getParamValue('tmpDir');
	my $workloadNum    = $self->getParamValue('workloadNum');
	my $appInstanceNum = $self->getParamValue('appInstanceNum');
	my $logName        = "$tmpDir/W${workloadNum}I${appInstanceNum}-configChange.log";

	my $log;
	open( $log, ">$logName" ) || die "Error opening $logName:$!";
	select($log);
	$|=1;

	my $pid = fork();
	if ( $pid == 0 ) {
		my $logger         = get_logger("Weathervane::Services::ElasticityService");
		my $console_logger = get_logger("Console");

		my $configurationManagersRef = $self->appInstance->getActiveServicesByType("configurationManager");
		if ( $#$configurationManagersRef < 0 ) {
			$console_logger->warn(
				"Trying to manage configPath, but there are no active configurationManagers.  Aborting configPath");
			exit(-1);
		}
		my $configurationManager = $configurationManagersRef->[0];
		my $hostname             = $configurationManager->host->hostName;
		my $port                 = $configurationManager->portMap->{ $configurationManager->getImpl() };

		my $impl         = $self->getParamValue('workloadImpl');
		my $serviceTypes = $WeathervaneTypes::serviceTypes{$impl};

		my $runTime =
		  $self->getParamValue('rampUp') + $self->getParamValue('steadyState') + $self->getParamValue('rampDown');
		$logger->debug("ElasticityService manageConfigPath.  runTime = $runTime");

		my $accumulatedDuration = 0;

		# hash from service type to number active in previous interval
		my $previousNumByServiceType = {};
		foreach my $serviceType (@$serviceTypes) {
			$previousNumByServiceType->{$serviceType} = $self->appInstance->getInitialNumOfServiceType($serviceType);
		}

		my $ua = LWP::UserAgent->new;

		# Adding can take a long time
		$ua->timeout(1200);
		$ua->agent("Weathervane/1.0");

		my $json = JSON->new;
		$json = $json->relaxed(1);
		$json = $json->pretty(1);

		do {

			foreach my $configInterval (@$configPathRef) {
				my $timestamp = localtime();
				my $duration  = $configInterval->{"duration"};
				$logger->debug("ElasticityService manageConfigPath. interval duration = $duration");

				# Hash from serviceType to the change in the number of services from the previous interval
				my $changeByServiceType = {};

				# Find the change in number of instances for each service type
				my $isChange = 0;
				foreach my $serviceType (@$serviceTypes) {
					my $indexName = "num" . ucfirst($serviceType) . "s";
					if ( ( exists $configInterval->{$indexName} ) && ( defined $configInterval->{$indexName} ) ) {
						$changeByServiceType->{$serviceType} =
						  $configInterval->{$indexName} - $previousNumByServiceType->{$serviceType};
						$previousNumByServiceType->{$serviceType} = $configInterval->{$indexName};
						if ( $changeByServiceType->{$serviceType} != 0 ) {
							$isChange = 1;
						}
					}
					else {
						$changeByServiceType->{$serviceType} = 0;
					}
					$logger->debug( "ElasticityService manageConfigPath for $serviceType change = "
						  . $changeByServiceType->{$serviceType} );
				}

				# Record the time before sending the change message
				my $changeStartTime = time();

				if ($isChange) {

					# Now create the message for the change and send it.
					my %servicesBeingActivatedByType;
					my $changeMessageContent = {};
					foreach my $serviceType (@$serviceTypes) {
						my $change = $changeByServiceType->{$serviceType};
						if ( $change > 0 ) {
							my $servicesToAddList       = [];
							my $inactiveServicesListRef = $self->appInstance->getInactiveServicesByType($serviceType);
							if ( ( $#$inactiveServicesListRef + 1 ) < $change ) {
								$console_logger->warn(
									"Trying to add $change instances of $serviceType but there are not enough inactive"
									  . " services of that type.  Aborting configPath configuration changes." );
								exit(-1);
							}
							for ( my $i = 0 ; $i < $change ; $i++ ) {
								my $service = $inactiveServicesListRef->[$i];

								my %paramHash = %{ $service->paramHashRef };
								$paramHash{"class"} = $serviceType;

								foreach my $portName ( keys %{ $service->internalPortMap } ) {
									$paramHash{ $portName . "InternalPort" } = $service->internalPortMap->{$portName};
								}
								foreach my $portName ( keys %{ $service->portMap } ) {
									$paramHash{ $portName . "Port" } = $service->portMap->{$portName};
								}
								$paramHash{"hostHostName"}     = $service->host->hostName;
								$paramHash{"hostIpAddr"}       = $service->host->ipAddr;
								$paramHash{"hostCpus"}         = $service->host->cpus + 0;
								$paramHash{"hostMemKb"}        = $service->host->memKb + 0;
								$paramHash{"hostIsBonneville"} = $service->host->isBonneville();

								push @$servicesToAddList, \%paramHash;
								if ( !( exists $servicesBeingActivatedByType{$serviceType} ) ) {
									$servicesBeingActivatedByType{$serviceType} = [];
								}
								push @{ $servicesBeingActivatedByType{$serviceType} }, $service;
							}
							$changeMessageContent->{ $serviceType . "sToAdd" } = $servicesToAddList;
							$changeMessageContent->{ "num" . ucfirst($serviceType) . "sToRemove" } = 0;
						}
						elsif ( $change < 0 ) {
							$change *= -1;
							my $serviceIdsToRemoveList = [];
							my $activeServicesListRef  = $self->appInstance->getActiveServicesByType($serviceType);
							if ( ( $#$activeServicesListRef + 1 ) < $change ) {
								$console_logger->warn(
									"Trying to remove $change instances of $serviceType but there are not enough active"
									  . " services of that type.  Aborting configPath configuration changes." );
								exit(-1);
							}

							$changeMessageContent->{ "num" . ucfirst($serviceType) . "sToRemove" } = $change;
						}
						else {
							$changeMessageContent->{ "num" . ucfirst($serviceType) . "sToRemove" } = 0;
						}

					}

					# Send the changeConfiguration message
					my $content = $json->encode($changeMessageContent);
					my $url     = "http://$hostname:$port/configuration";
					$logger->debug("Sending put to $url");
					$logger->debug("Content = $content");
					my $req = HTTP::Request->new( PUT => $url );
					$req->content_type('application/json');
					$req->header( Accept => "application/json" );
					$req->content($content);

					my $res = $ua->request($req);
					$logger->debug( "Response status line: " . $res->status_line );
					my $contentHashRef = $json->decode( $res->content );
					$logger->debug( "Response content:\n" . $res->content );

					# If the request was sucessful, then we need to marks the services activated/non-active
					# as appropriate and store the ids in the added services
					if ( $res->is_success ) {
						foreach my $serviceType (@$serviceTypes) {
							if ( exists $servicesBeingActivatedByType{$serviceType} ) {
								my $servicesBeingActivatedListRef = $servicesBeingActivatedByType{$serviceType};
								my $addServiceIdsListRef;
								if ( exists $contentHashRef->{ "added" . ucfirst($serviceType) . "Ids" } ) {
									$addServiceIdsListRef =
									  $contentHashRef->{ "added" . ucfirst($serviceType) . "Ids" };

									if ( $#$addServiceIdsListRef < $#$servicesBeingActivatedListRef ) {
										$console_logger->warn(
											    "Adding services of $serviceType was successful, but configuration "
											  . "manager didn't return enough Ids for the added services.\n"
											  . "Returned "
											  . $#$addServiceIdsListRef + 1
											  . ", Expected "
											  . $#$servicesBeingActivatedListRef + 1
											  . ".\nAborting following configPath" );
										exit -1;
									}
								}
								else {
									$console_logger->warn(
										    "Adding services of $serviceType was successful, but configuration "
										  . "manager didn't return Ids for the added services.\n"
										  . "Aborting following configPath" );
									exit -1;
								}
								my $cnt = 0;
								for my $service (@$servicesBeingActivatedListRef) {
									$service->isActive(1);
									$service->id( $addServiceIdsListRef->[$cnt] );
									$cnt++;
								}
							}
						}

						if (   ( exists $contentHashRef->{"appServersRemoved"} )
							&& ( defined $contentHashRef->{"appServersRemoved"} ) )
						{
							my $appServersRemovedListRef = $contentHashRef->{"appServersRemoved"};

							foreach my $appServerHashRef (@$appServersRemovedListRef) {
								my $service =
								  $self->appInstance->getServiceByTypeAndName( "appServer",
									$appServerHashRef->{"dockerName"} );
								$service->isActive(0);
							}
						}
						if (   ( exists $contentHashRef->{"webServersRemoved"} )
							&& ( defined $contentHashRef->{"webServersRemoved"} ) )
						{
							my $webServersRemovedListRef = $contentHashRef->{"webServersRemoved"};

							foreach my $webServerHashRef (@$webServersRemovedListRef) {
								my $service =
								  $self->appInstance->getServiceByTypeAndName( "webServer",
									$webServerHashRef->{"dockerName"} );
								$service->isActive(0);
							}
						}

					}
					else {
						$console_logger->warn( "Trying to change configuration got error response "
							  . $res->status_line
							  . ".  Aborting configPath" );
						close $log;
						exit(-1);
					}
				}

				# Now sleep for the rest of the interval duration
				my $changeEndTime  = time();
				my $changeDuration = $changeEndTime - $changeStartTime;
				$logger->debug("Configuration change took $changeDuration seconds");
				
				# Log the change
				$timestamp = localtime();
				if ($isChange) {
					print $log "$timestamp changeDuration:${changeDuration}sec ";
					foreach my $serviceType (@$serviceTypes) {
						my $change = $changeByServiceType->{$serviceType};
						if ( $change > 0 ) {
							print $log "$serviceType:+$change;";
						}
						elsif ( $change < 0 ) {
							print $log "$serviceType:$change;";
						}
					}
					print $log "\n";
				}
				my $remainingDuration = $duration - $changeDuration;
				print $log "$timestamp remainingDuration:${remainingDuration}sec ";
				foreach my $serviceType (@$serviceTypes) {
					print $log "num${serviceType}s:" . $previousNumByServiceType->{$serviceType} . ";";
				}
				print $log "\n";


				$accumulatedDuration += $duration;
				if ( $remainingDuration < 0 ) {

					# If we have gone over the stated interval, need to add
					# that time to the accumulatedDuration
					$accumulatedDuration -= $remainingDuration;
				}
				if ( $accumulatedDuration > $runTime ) {

					# If this interval exceeds the run duration then
					# stop the process
					$logger->debug(
"ElasticityService manageConfigPath. accumulatedDuration > runTime ($accumulatedDuration > $runTime), stopping."
					);
					close $log;
					exit(0);
				}

				if ( $remainingDuration > 0 ) {
					$logger->debug("ElasticityService manageConfigPath. Sleeping for $remainingDuration.");
					sleep($remainingDuration);
				}
			}

		} while ( $self->getParamValue('repeatConfigPath') );

		close $log;
		exit(0);
	}

}

sub workloadRunning {
	my ($self) = @_;

	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $logger           = get_logger("Weathervane::Services::ElasticityService");

	$logger->debug("ElasticityService workloadRunning");

	my $configPathRef = $self->appInstance->getConfigPath();
	if ( ( defined $configPathRef ) && ( $#$configPathRef > 0 ) ) {
		$logger->debug("ElasticityService workloadRunning have configPath");
		$self->manageConfigPath($configPathRef);
	}
}

sub stopInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ElasticityService");
	$logger->debug("stop ElasticityService");
}

sub startInstance {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::ElasticityService");
	$logger->debug("start ElasticityService");
}

sub isUp {
	my ( $self, $fileout ) = @_;

	return 1;

}

sub isRunning {
	my ( $self, $fileout ) = @_;
	return 1;
}

sub setPortNumbers {
	my ($self) = @_;

}

sub setExternalPortNumbers {
	my ($self) = @_;

}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $hostname = $self->host->hostName;

}

sub stopStatsCollection {
	my ( $self, $host, $configPath ) = @_;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

}

sub cleanStatsFiles {
	my ($self) = @_;
	my $hostname = $self->host->hostName;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;
}

sub cleanLogFiles {
	my ($self) = @_;

}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

}

sub getConfigSummary {
	my ($self) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();

	return \%csv;
}

__PACKAGE__->meta->make_immutable;

1;

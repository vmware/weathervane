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
package PostgresqlKubernetesService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::KubernetesService;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'KubernetesService';

has '+name' => ( default => 'PostgreSQL 9.3', );

has '+version' => ( default => '9.3.5', );

has '+description' => ( default => '', );

override 'initialize' => sub {
	my ($self) = @_;

	super();
};

sub clearDataBeforeStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $name        = $self->getParamValue('dockerName');
	$logger->debug("clearDataBeforeStart for $name");
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlService");
	my $cluster    = $self->host;
	my $name        = $self->getParamValue('dockerName');

	$logger->debug("clearDataAfterStart for $name");

	my $time     = `date +%H:%M`;
	chomp($time);
	my $logName = "$logPath/ClearDataPostgresql-$name-$time.log";

	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From PortgreSQL\n";

	$cluster->kubernetesExecOne($self->getImpl(), "/clearAfterStart.sh", $self->namespace);

	close $applog;

}

sub configure {
	my ( $self, $dblog, $serviceType, $users, $numShards, $numReplicas ) = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlKubernetesService");
	$logger->debug("Configure Postgresql kubernetes");
	print $dblog "Configure Postgresql Kubernetes\n";

	my $namespace = $self->namespace;	
	my $configDir        = $self->getParamValue('configDir');

	my $totalMemory;
	my $totalMemoryUnit;
	if (   ( exists $self->dockerConfigHashRef->{'memory'} )
		&&  $self->dockerConfigHashRef->{'memory'}  )
	{
		my $memString = $self->dockerConfigHashRef->{'memory'};
		$logger->debug("docker memory is set to $memString, using this to tune postgres.");
		$memString =~ /(\d+)\s*(\w)/;
		$totalMemory = $1;
		$totalMemoryUnit = $2;
	} else {
		$totalMemory = 0;
		$totalMemoryUnit = 0;		
	}

	open( FILEIN,  "$configDir/kubernetes/postgresql.yaml" ) or die "$configDir/kubernetes/postgresql.yaml: $!\n";
	open( FILEOUT, ">/tmp/postgresql-$namespace.yaml" )             or die "Can't open file /tmp/postgresql-$namespace.yaml: $!\n";
	
	while ( my $inline = <FILEIN> ) {

		if ( $inline =~ /POSTGRESTOTALMEM:/ ) {
			print FILEOUT "  POSTGRESTOTALMEM: \"$totalMemory\"\n";
		}
		elsif ( $inline =~ /POSTGRESTOTALMEMUNIT:/ ) {
			print FILEOUT "  POSTGRESTOTALMEMUNIT: \"$totalMemoryUnit\"\n";
		}
		elsif ( $inline =~ /POSTGRESSHAREDBUFFERS:/ ) {
			print FILEOUT "  POSTGRESSHAREDBUFFERS: \"" . $self->getParamValue('postgresqlSharedBuffers') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESSHAREDBUFFERSPCT:/ ) {
			print FILEOUT "  POSTGRESSHAREDBUFFERSPCT: \"" . $self->getParamValue('postgresqlSharedBuffersPct') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESEFFECTIVECACHESIZE:/ ) {
			print FILEOUT "  POSTGRESEFFECTIVECACHESIZE: \"" . $self->getParamValue('postgresqlEffectiveCacheSize') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESEFFECTIVECACHESIZEPCT/ ) {
			print FILEOUT "  POSTGRESEFFECTIVECACHESIZEPCT: \"" . $self->getParamValue('postgresqlEffectiveCacheSizePct') . "\"\n";
		}
		elsif ( $inline =~ /POSTGRESMAXCONNECTIONS/ ) {
			print FILEOUT "  POSTGRESMAXCONNECTIONS: \"" . $self->getParamValue('postgresqlMaxConnections') . "\"\n";
		}
		elsif ( $inline =~ /(\s+)imagePullPolicy/ ) {
			print FILEOUT "${1}imagePullPolicy: " . $self->appInstance->imagePullPolicy . "\n";
		}
		else {
			print FILEOUT $inline;
		}

	}
	
	close FILEIN;
	close FILEOUT;
	
		

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;


}

sub cleanLogFiles {
	my ($self)            = @_;
	my $logger = get_logger("Weathervane::Services::PostgresqlDockerService");
	$logger->debug("cleanLogFiles");

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
	$csv{"postgresqlEffectiveCacheSize"} = $self->getParamValue('postgresqlEffectiveCacheSize');
	$csv{"postgresqlSharedBuffers"}      = $self->getParamValue('postgresqlSharedBuffers');
	$csv{"postgresqlMaxConnections"}     = $self->getParamValue('postgresqlMaxConnections');
	return \%csv;
}

sub getStatsSummary {
	my ( $self, $statsLogPath, $users ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	%csv = ();
	return \%csv;
}

# Get the max number of users loaded in the database
sub getMaxLoadedUsers {
	my ($self) = @_;
	
	my $cluster = $self->host;
	my $impl = $self->getImpl();
	my $maxUsers = $cluster->kubernetesExecOne($impl, "psql -U auction  -t -q --command=\"select maxusers from dbbenchmarkinfo;\"", $self->namespace);
	chomp($maxUsers);
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

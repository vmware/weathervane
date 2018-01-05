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
package RunManager;

use Moose;
use MooseX::Storage;
use VirtualInfrastructures::VirtualInfrastructure;
use Services::Service;
use RunProcedures::RunProcedure;
use Factories::RunProcedureFactory;
use WorkloadDrivers::WorkloadDriver;
use DataManagers::DataManager;
use Instance;
use Log::Log4perl qw(get_logger);

use Parameters qw(getParamValue setParamValue);

with Storage( 'format' => 'JSON', 'io' => 'File' );

use namespace::autoclean;

use WeathervaneTypes;

extends 'Instance';

has 'name' => (
	is  => 'ro',
	isa => 'Str',
);

has 'description' => (
	is  => 'ro',
	isa => 'Str',
);

has 'viRef' => (
	is  => 'rw',
	isa => 'ScalarRef[VirtualInfrastructure]',
);

has 'hostsListRef' => (
	is      => 'rw',
	isa     => 'ArrayRef',
	default => sub { [] },
);

has 'servicesRef' => (
	is      => 'rw',
	isa     => 'ArrayRef[Service]',
	default => sub { [] },
);

has 'servicesByTypeRef' => (
	is      => 'rw',
	isa     => 'HashRef[ArrayRef[Service]]',
	default => sub { {} },
);


has 'runProcedure' => (
	is  => 'rw',
	isa => 'RunProcedure',
);

has 'resultsFileDir' => (
	is  => 'rw',
	isa => 'Str',
);

override 'initialize' => sub {
	my ( $self ) = @_;
	my $paramHashRef = $self->paramHashRef;	

	# if the resultsFileDir doesn't start with a / then it
	# is relative to weathervaneHome
	my $resultsFileDir = $paramHashRef->{'resultsFileDir' };
	if ( !( $resultsFileDir =~ /^\// ) ) {
		my $weathervaneHome =  $paramHashRef->{'weathervaneHome' };
		if ( $resultsFileDir eq "" ) {
			$resultsFileDir = $weathervaneHome;
		}
		else {
			$resultsFileDir = $weathervaneHome . "/" . $resultsFileDir;
		}
	}
	$paramHashRef->{'resultsFileDir' } = $resultsFileDir;

	super();

};

sub setRunProcedure {
	my ( $self, $runProcedure ) = @_;
	$self->runProcedure($runProcedure);
}

sub start {
	die "Can only stop a concrete sub-class of RunManager";
}

sub printCsv {
	my ( $self, $csvHashRef, $printHeader ) = @_;
	my $debug_logger = get_logger("Weathervane::RunManager::RunManager");
	## print the csv headers to the results file
	open( CSVFILE, ">>" . $self->getParamValue('resultsFileDir') . "/" . $self->getParamValue('resultsFileName') )
	  or die "Couldn't open file >>" . $self->getParamValue('resultsFileDir') . "/" . $self->getParamValue('resultsFileName') . " :$!\n";
	if ($printHeader) {
		foreach my $key ( keys %$csvHashRef ) {
			print CSVFILE "$key,";
		}
		print CSVFILE "\n";
	}
	foreach my $key ( keys %$csvHashRef ) {
		$debug_logger->debug("printCsv: printing value for key $key");
		print CSVFILE $csvHashRef->{$key} . ",";
	}
	print CSVFILE "\n";
	close CSVFILE;
}

sub toString {
	my ($self) = @_;

	return "RunManager " . $self->name();
}

__PACKAGE__->meta->make_immutable;

1;

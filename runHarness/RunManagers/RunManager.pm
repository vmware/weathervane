# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
		if ((exists $csvHashRef->{$key}) && (defined $csvHashRef->{$key})) {
			$debug_logger->debug("printCsv: printing value for key $key");
			print CSVFILE $csvHashRef->{$key} . ",";
		}
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

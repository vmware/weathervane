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
package Parameters;

use Carp 'verbose';
#$SIG{__DIE__} = sub { Carp::confess(@_) };

use Tie::IxHash;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

use strict;
use JSON;
use Log::Log4perl qw(get_logger :levels);
use Scalar::Util qw(looks_like_number);

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA = qw( Exporter);
	@EXPORT_OK =
	  qw(getParamDefault getParamType getParamKeys getParamValue setParamValue usage fullUsage mergeParameters);
}

my @constructedNameParameters = ( "hostName", "vmName" );
my @instancesWithConstructedNames = (
	"drivers", "nosqlServers", "dbServers",
	"ipManagers",    "configurationManagers",    "elasticityServices",
	"coordinationServers",
	 "lbServers",        "webServers",   "msgServers",
	"appServers",    "fileServers",      "viHosts",      "viMgmtHostInstance",
	"dataManagerInstance"
);

my @dockerNameParameters = ( "dockerName" );
my @instancesWithDockerName = (
	"drivers", "nosqlServers", "dbServers",
	"ipManagers",    "configurationManagers",    "elasticityServices",
	"coordinationServers",
	 "lbServers",        "webServers",   "msgServers",
	"appServers",    "fileServers",	"dataManagerInstance"
);

my @constructedAppInstanceNameParameters     = ("appInstanceName");
my @instancesWithConstructedAppInstanceNames = ( "appInstances", );

my @constructedWwwHostnameParameters     = ("wwwHostname");
my @instancesWithConstructedWwwHostnames = ( "appInstances", );

my @nonInstanceHashParameters = ("dockerServiceImages");
my @nonInstanceListParameters = ('userLoadPath', 'configPath');
my @runLengthParams = ( 'steadyState', 'rampUp', 'rampDown'  );

sub getParamHashAsJson {
	my ($key, $paramHashRef) = @_;
	
	
}

sub getParamDefault {
	my ($key) = @_;

	my @keys = keys %Parameters::parameters;
	if ( !( $key ~~ @keys ) ) {
		die "getParamDefault: No parameter key $key exists in Parameters";
	}

	return ( $Parameters::parameters{$key}->{"default"} );
}

sub getParamType {
	my ($key) = @_;

	my @keys = keys %Parameters::parameters;
	if ( !( $key ~~ @keys ) ) {
		die "getParamType: No parameter key $key exists in Parameters";
	}

	return ( $Parameters::parameters{$key}->{"type"} );
}

sub getParamKeys {

	my @keys = keys %Parameters::parameters;

	return \@keys;
}

sub getParentList {
	my ( $paramHashRef, $key ) = @_;
	my @parentList = ();
	my $parent     = $Parameters::parameters{$key}->{"parent"};
	while ($parent) {
		unshift @parentList, $parent;
		$parent = $Parameters::parameters{$parent}->{"parent"};
	}
	return \@parentList;
}

sub getParentHashRef {
	my ( $paramHashRef, $key ) = @_;

	my @keys = keys %Parameters::parameters;
	if ( !( $key ~~ @keys ) ) {
		die "getParamValue: No parameter $key exists in Parameters";
	}

	# List of parents in the hierarchy
	my $parentListRef = getParentList( $paramHashRef, $key );

	# traverse the hierarchy to get the hash containing the key
	my $levelHashRef = $paramHashRef;
	foreach my $level (@$parentListRef) {
		$levelHashRef = $levelHashRef->{$level};
	}

	return $levelHashRef;
}

sub getHierarchyParamList {
	my ( $paramHashRef, $key, $parentParamHashRef, $instanceParamHashRef ) = @_;

	# use a hash to ensure uniqueness of keys
	my %params;

	# List of parents in the hierarchy
	my $parentListRef = getParentList( $paramHashRef, $key );
	push @$parentListRef, $key;

	# traverse the hierarchy to get the parameters
	my $levelHashRef = $paramHashRef;
	foreach my $param ( keys %$levelHashRef ) {
		if (   ( $param ~~ @nonInstanceHashParameters ) || ( $param ~~ @nonInstanceListParameters )
			|| ( ( ref( $levelHashRef->{$param} ) ne "HASH" ) && ( ref( $levelHashRef->{$param} ) ne "ARRAY" ) ) )
		{
			$params{$param} = 1;
		}
	}
	foreach my $level (@$parentListRef) {
		$levelHashRef = $levelHashRef->{$level};
		foreach my $param ( keys %$levelHashRef ) {
			if (   ( ( $level eq $key ) && ( exists $Parameters::parameters{$param}->{"isa"} ) )
				|| ( $param ~~ @nonInstanceHashParameters ) || ( $param ~~ @nonInstanceListParameters )
				|| ( ( ref( $levelHashRef->{$param} ) ne "HASH" ) && ( ref( $levelHashRef->{$param} ) ne "ARRAY" ) ) )
			{
				$params{$param} = 1;
			}
		}
	}

	foreach my $param ( keys %$parentParamHashRef ) {
		if (
			( $param ~~ @nonInstanceHashParameters ) || ( $param ~~ @nonInstanceListParameters )
			|| (   ( ref( $parentParamHashRef->{$param} ) ne "HASH" )
				&& ( ref( $parentParamHashRef->{$param} ) ne "ARRAY" ) )
		  )
		{
			$params{$param} = 1;
		}
	}

	foreach my $param ( keys %$instanceParamHashRef ) {
		if (
			( $param ~~ @nonInstanceHashParameters ) || ( $param ~~ @nonInstanceListParameters )
			|| (   ( ref( $instanceParamHashRef->{$param} ) ne "HASH" )
				&& ( ref( $instanceParamHashRef->{$param} ) ne "ARRAY" ) )
		  )
		{
			$params{$param} = 1;
		}
	}

	my @keys = keys %params;
	return \@keys;
}

sub getParamValue {
	my ( $paramHashRef, $key ) = @_;
	my $parentHashRef = getParentHashRef( $paramHashRef, $key );

	return ( $parentHashRef->{$key} );
}

sub setParamValue {
	my ( $paramHashRef, $key, $value ) = @_;
	my $parentHashRef = getParentHashRef( $paramHashRef, $key );

	if (looks_like_number($value)) {
		# Want numbers to be numbers, not strings
		$parentHashRef->{$key} = $value + 0;		
	} else {	
		$parentHashRef->{$key} = $value;	
	}
}

sub usage {
	my @keys = keys %Parameters::parameters;
	print "Usage:  ./weathervane.pl [options]\n";
	foreach my $key (@keys) {
		if ( $Parameters::parameters{$key}->{"showUsage"} ) {
			print "Parameter Name:         " . $key . "\n";
			print "Parameter Description:  " . $Parameters::parameters{$key}->{"usageText"} . "\n";
			print "Parameter Default:      " . $Parameters::parameters{$key}->{"default"} . "\n";
			print "\n";
		}
	}
}

sub fullUsage {

	my @keys = keys %Parameters::parameters;
	print "Usage:  ./weathervane.pl [options]\n";
	my $i = 0;
	foreach my $key (@keys) {
		$i++;
		print "Parameter Name:         " . $key . "\n";
		print "Parameter Description:  " . $Parameters::parameters{$key}->{"usageText"} . "\n";
		print "Parameter Default:      " . $Parameters::parameters{$key}->{"default"} . "\n";
		print "\n";
	}
	print "There are $i parameters\n";
}

sub mergeParameters {
	my ( $paramCommandLineHashRef, $paramConfigHashRef ) = @_;

	# The hash in which to create the merged parameter set
	tie( my %parameterHash, 'Tie::IxHash' );

	# Create the structure from the defaults
	my %defaultsHashRefHash;
	my @parameterKeys = keys %Parameters::parameters;
	foreach my $parameterKey (@parameterKeys) {
		my $parent  = $Parameters::parameters{$parameterKey}->{"parent"};
		my $type    = $Parameters::parameters{$parameterKey}->{"type"};
		my $default = $Parameters::parameters{$parameterKey}->{"default"};

		# To avoid having to search through the levels of the hash of hash references
		# We save off the hash reference associated with each name.  This only
		# works because we know that the parameter names are globally unique
		if ( $type eq "hash" ) {
			$defaultsHashRefHash{$parameterKey} = $default;
		}

		if ( !$parent ) {
			$parameterHash{$parameterKey} = $default;
		}
		else {
			$defaultsHashRefHash{$parent}->{$parameterKey} = $default;
		}
	}

	# Overlay the parameters from the config file.
	# First pull out all of the sub hashRefs
	my %configHashRefHash;
	my %toCheckForSubHashRefs;    # Hash of hashRefs that need to be check for contained hashRefs
	my @configParameterKeys = keys %$paramConfigHashRef;

	# Get the top Level first
	foreach my $parameterKey (@configParameterKeys) {
		if ( ref( $paramConfigHashRef->{$parameterKey} ) eq "HASH" ) {
			$configHashRefHash{$parameterKey}     = $paramConfigHashRef->{$parameterKey};
			$toCheckForSubHashRefs{$parameterKey} = $paramConfigHashRef->{$parameterKey};
		}
	}

	# Now get all sub-hashes
	while ( my @keys = keys %toCheckForSubHashRefs ) {
		foreach my $parameterKey (@keys) {
			my $hashrefToCheck = delete $toCheckForSubHashRefs{$parameterKey};
			my @subKeys        = keys %$hashrefToCheck;
			foreach my $subKey (@subKeys) {
				if ( ref( $hashrefToCheck->{$subKey} ) eq "HASH" ) {
					$configHashRefHash{$subKey}     = $hashrefToCheck->{$subKey};
					$toCheckForSubHashRefs{$subKey} = $hashrefToCheck->{$subKey};
				}
			}
		}
	}

	# Now do the actual overlay

	# start with the top level
	foreach my $parameterKey ( keys %$paramConfigHashRef ) {
		my $parent = $Parameters::parameters{$parameterKey}->{"parent"};
		my $type   = $Parameters::parameters{$parameterKey}->{"type"};
		my $value  = $paramConfigHashRef->{$parameterKey};

		if ( ( $type eq "hash" ) && ( $parameterKey ne "loggers" ) ) {
			next;
		}

		if ( !$parent ) {
			if ($type eq "!") {
				if ($value) {
					$parameterHash{$parameterKey} = JSON::true;
				} else {
					$parameterHash{$parameterKey} = JSON::false;					
				}
			} else {
				$parameterHash{$parameterKey} = $value;
			}
		}
		else {
			if ($type eq "!") {
				if ($value) {
					$defaultsHashRefHash{$parent}->{$parameterKey} = JSON::true;
				} else {
					$defaultsHashRefHash{$parent}->{$parameterKey} = JSON::false;					
				}
			} else {
				$defaultsHashRefHash{$parent}->{$parameterKey} = $value;
			}
		}
	}

	# now do the sub-hashes
	foreach my $parameterKey ( keys %configHashRefHash ) {
		my $subHashRef = $configHashRefHash{$parameterKey};
		foreach my $key ( keys %$subHashRef ) {
			my $parent = $Parameters::parameters{$key}->{"parent"};
			my $type   = $Parameters::parameters{$key}->{"type"};
			my $value  = $subHashRef->{$key};

			if ( $type eq "hash" ) {
				next;
			}
			if ( !$parent ) {
				if ($type eq "!") {
					if ($value) {
						$parameterHash{$key} = JSON::true;
					} else {
						$parameterHash{$key} = JSON::false;					
					}
				} else {
					$parameterHash{$key} = $value;
				}
			}
			else {
				if ($type eq "!") {
					if ($value) {
						$defaultsHashRefHash{$parent}->{$key} = JSON::true;
					} else {
						$defaultsHashRefHash{$parent}->{$key} = JSON::false;					
					}
				} else {
					$defaultsHashRefHash{$parent}->{$key} = $value;
				}
			}
		}

	}

	# Overlay the parameters from the command line.  There is no hierarchy
	# in the command=line parameters
	foreach my $key ( keys %$paramCommandLineHashRef ) {
		my $parent = $Parameters::parameters{$key}->{"parent"};
		my $type   = $Parameters::parameters{$key}->{"type"};
		my $value  = $paramCommandLineHashRef->{$key};
		if ( $type eq "hash" ) {
			next;
		}

		if ( !$parent ) {
			if ($type eq "!") {
				if ($value) {
					$parameterHash{$key} = JSON::true;
				} else {
					$parameterHash{$key} = JSON::false;					
				}
			} else {
				$parameterHash{$key} = $value;
			}
		}
		else {
			if ($type eq "!") {
				if ($value) {
					$defaultsHashRefHash{$parent}->{$key} = JSON::true;
				} else {
					$defaultsHashRefHash{$parent}->{$key} = JSON::false;					
				}
			} else {
				$defaultsHashRefHash{$parent}->{$key} = $value;
			}
		}
	}

	return \%parameterHash;
}

sub getMostSpecificValue {
	my ( $paramsHashRef, $parentParamHashRef, $instanceHashRef, $param ) = @_;

	if ( $param ~~ @runLengthParams ) {

		# The run length params must be specified at the top level and must
		# be the same for all workloads
		return getParamValue( $paramsHashRef, $param );
	}

	# Look for value first in instance, then in parent instance
	# and finally get the default
	my $value;
	if (   ( exists $instanceHashRef->{$param} )
		&& ( defined $instanceHashRef->{$param} ) )
	{
		$value = $instanceHashRef->{$param};
	}
	elsif (( exists $parentParamHashRef->{$param} )
		&& ( defined $parentParamHashRef->{$param} ) )
	{
		$value = $parentParamHashRef->{$param};
	}
	else {
		$value = getParamValue( $paramsHashRef, $param );
	}
	return $value;
}

sub getInstanceParamHashRef {
	my ( $paramsHashRef, $parentHashRef, $instanceHashRef, $instanceKey, $instanceNum, $allParamsRef, $useAllSuffixes )
	  = @_;

	my %instanceParamHash;

	my $parent = $Parameters::parameters{$instanceKey}->{"parent"};
	if ( !exists $Parameters::parameters{$instanceKey}->{"isa"} ) {
		die "Trying to get instance parameters for an $instanceKey, but this is not an instance of any type";
	}
	my $isa = $Parameters::parameters{$instanceKey}->{"isa"};

	my $appInstanceSuffix = "";
	my $appInstanceNum    = "";
	if (   $useAllSuffixes
		&& ( exists $parentHashRef->{'appInstanceSuffix'} )
		&& ( $parentHashRef->{'appInstanceSuffix'} )
		&& ( exists $parentHashRef->{'appInstanceNum'} )
		&& ( $parentHashRef->{'appInstanceNum'} ) )
	{
		$appInstanceSuffix = $parentHashRef->{'appInstanceSuffix'};
		$appInstanceNum    = $parentHashRef->{'appInstanceNum'};
	}
	my $wkldSuffix = "";
	my $wkldNum    = "";
	if (   $useAllSuffixes
		&& ( exists $parentHashRef->{'workloadSuffix'} )
		&& ( $parentHashRef->{'workloadSuffix'} )
		&& ( exists $parentHashRef->{'workloadNum'} )
		&& ( $parentHashRef->{'workloadNum'} ) )
	{
		$wkldSuffix = $parentHashRef->{'workloadSuffix'};
		$wkldNum    = $parentHashRef->{'workloadNum'};
	}

	# Iterate through the parameters, adding the most specific value to the
	# paramHash.  Construct the parameters that must be built for specific instance types
	foreach my $param (@$allParamsRef) {

		my $value = getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, $param );

		# Construct the parameters that are not set and so should be constructed for certain instance types
		if ( !$value ) {

			# Add the parameters that must be constructed based on the default rules
			if ( ( $param ~~ @constructedNameParameters ) && ( $instanceKey ~~ @instancesWithConstructedNames ) ) {

				# No name was explicitly specified, so we need to construct one.
				my $hostnamePrefix =
				  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "hostnamePrefix" );
				my $suffix = getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, $isa . "Suffix" );
				$value =
				    $hostnamePrefix
				  . $wkldSuffix
				  . $wkldNum
				  . $appInstanceSuffix
				  . $appInstanceNum
				  . $suffix
				  . $instanceNum;
			}

			if ( ( $param ~~ @dockerNameParameters ) && ( $instanceKey ~~ @instancesWithDockerName ) ) {

				# No name was explicitly specified, so we need to construct one.
				my $hostnamePrefix =
				  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "hostnamePrefix" );
				my $suffix = getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, $isa . "Suffix" );
				$value =
				    $hostnamePrefix
				  . $wkldSuffix
				  . $wkldNum
				  . $appInstanceSuffix
				  . $appInstanceNum
				  . $suffix
				  . $instanceNum
				  . "D";
			}

			if (   ( $param ~~ @constructedAppInstanceNameParameters )
				&& ( $instanceKey ~~ @instancesWithConstructedAppInstanceNames ) )
			{
				my $hostnamePrefix =
				  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "hostnamePrefix" );
				if ($useAllSuffixes) {
					$wkldSuffix =
					  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "workloadSuffix" );
					$wkldNum = getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "workloadNum" );
					if ($wkldSuffix) {
						$wkldSuffix .= $wkldNum;
					}
					else {
						$wkldSuffix = "W" . $wkldNum;
					}

					$appInstanceSuffix =
					  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "appInstanceSuffix" );
					if ($appInstanceSuffix) {
						$appInstanceSuffix .= $instanceNum;
					}
					else {
						$appInstanceSuffix = "I" . $instanceNum;
					}
				}
				$value = $hostnamePrefix . $wkldSuffix . $appInstanceSuffix;

			}

			if (   ( $param ~~ @constructedWwwHostnameParameters )
				&& ( $instanceKey ~~ @instancesWithConstructedWwwHostnames ) )
			{
				if ($useAllSuffixes) {
					$wkldSuffix =
					  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "workloadSuffix" );
					if ($wkldSuffix) {
						$wkldNum =
						  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "workloadNum" );
						$wkldSuffix .= $wkldNum;
					}
					$appInstanceSuffix =
					  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "appInstanceSuffix" );
					if ($appInstanceSuffix) {
						$appInstanceSuffix .= $instanceNum;
					}
				}
				my $prefix =
				  getMostSpecificValue( $paramsHashRef, $parentHashRef, $instanceHashRef, "wwwHostnamePrefix" );
				$value = $prefix . $wkldSuffix . $appInstanceSuffix;

			}

		}
		$instanceParamHash{$param} = $value;

	}

	# Set the instanceNum in the params
	$instanceParamHash{"instanceNum"} = $instanceNum;

	return \%instanceParamHash;
}

# This method is used to get the parameters for the instances of a service
# using the num${serviceType}s parameter to define the count of instances.
# The startingInstanceNumber is used to assign instanceNumbers to instance
# parameters that require a number.
sub getDefaultInstanceParamHashRefs {
	my ( $paramsHashRef, $parentParamHashRef, $numToCreate, $instanceKey, $startingInstanceNum, $useAllSuffixes ) = @_;
	if ( !defined $useAllSuffixes ) {
		$useAllSuffixes = 0;
	}

	my @instanceParamHashRefs = ();
	my $isa                   = $Parameters::parameters{$instanceKey}->{"isa"};
	my $allParamsRef          = getHierarchyParamList( $paramsHashRef, $isa, $parentParamHashRef, {} );

	for (
		my $instanceNum = $startingInstanceNum ;
		$instanceNum < ( $numToCreate + $startingInstanceNum ) ;
		$instanceNum++
	  )
	{
		my $instanceParamHashRef =
		  getInstanceParamHashRef( $paramsHashRef, $parentParamHashRef, {}, $instanceKey, $instanceNum, $allParamsRef,
			$useAllSuffixes );
		push @instanceParamHashRefs, $instanceParamHashRef;
	}

	return \@instanceParamHashRefs;
}

# This method is used to get the parameters for the instances of a service
# that are partially defined by Instance hashes in the input configuration
# The startingInstanceNumber is used to assign instanceNumbers to instance
# parameters that require a number.
sub getInstanceParamHashRefs {
	my ( $paramsHashRef, $parentParamHashRef, $instancesListRef, $instanceKey, $startingInstanceNum, $useAllSuffixes ) =
	  @_;
	if ( !defined $useAllSuffixes ) {
		$useAllSuffixes = 0;
	}

	my @instanceParamHashRefs = ();
	my $instanceNum           = $startingInstanceNum;
	my $isa                   = $Parameters::parameters{$instanceKey}->{"isa"};

	foreach my $instanceHashRef (@$instancesListRef) {

		my $allParamsRef = getHierarchyParamList( $paramsHashRef, $isa, $parentParamHashRef, $instanceHashRef );

		my $instanceParamHashRef =
		  getInstanceParamHashRef( $paramsHashRef, $parentParamHashRef, $instanceHashRef, $instanceKey, $instanceNum,
			$allParamsRef, $useAllSuffixes );
		push @instanceParamHashRefs, $instanceParamHashRef;

		$instanceNum++;
	}

	return \@instanceParamHashRefs;
}

# This gets the parameters for singleton instances, like the
# dataManager, etc.
# Instance number for singletons is assumed to be 1
sub getSingletonInstanceParamHashRef {
	my ( $paramsHashRef, $parentParamHashRef, $instanceKey, $useAllSuffixes ) = @_;
	my $instanceNum = 1;
	if ( !defined $useAllSuffixes ) {
		$useAllSuffixes = 0;
	}
	my $instanceHashRef = {};
	if ( exists $parentParamHashRef->{$instanceKey} ) {
		$instanceHashRef = $parentParamHashRef->{$instanceKey};
	}

	my $isa = $Parameters::parameters{$instanceKey}->{"isa"};

	# get the list of parameters that are in the hierararchy above the instance plus
	# the parameters that are in the parent that may be specified as defaults for lower-level instances
	my $allParamsRef = getHierarchyParamList( $paramsHashRef, $isa, $parentParamHashRef, $instanceHashRef );

	return getInstanceParamHashRef( $paramsHashRef, $parentParamHashRef, $instanceHashRef, $instanceKey, $instanceNum,
		$allParamsRef, $useAllSuffixes );

}

our $version = "1.1.0";

# These variables contain the key names for the parameter hashes
tie( our %parameters, 'Tie::IxHash' );
$parameters{"version"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "",
	"usageText" => "If present, the Weathervane run harness shows the version information at the start of the runs.",
	"showUsage" => 1,
};

$parameters{"runManager"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"runProc"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"workload"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"workloadDriver"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appInstance"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dataManager"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"host"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"virtualInfrastructure"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"virtualInfrastructureInstance"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"isa"       => "virtualInfrastructure",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"loggers"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dataManagerInstance"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"isa"       => "dataManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"runManagerInstance"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "",
	"isa"       => "runManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"runProcInstance"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runManager",
	"isa"       => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"drivers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "workload",
	"isa"       => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"workloads"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "runProc",
	"isa"       => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appInstances"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "workload",
	"isa"       => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"hosts"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "runProc",
	"isa"       => "host",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"ipManager"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"ipManagers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "ipManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"configurationManager"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"coordinationServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"elasticityService"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"configurationManagers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "configurationManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"coordinationServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"elasticityServices"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "elasticityService",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"lbServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"lbServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"webServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"webServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "webServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dbServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dbServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nosqlServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nosqlServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "nosqlServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"fileServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"fileServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "fileServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"msgServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"msgServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "msgServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServer"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServers"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"isa"       => "appServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"hostName"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"vmName"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dockerName"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appInstanceName"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"instanceNum"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"accept"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "",
	"usageText" => "Specifying this parameter indicates acceptance of the COPYRIGHT and LICENSE.",
	"showUsage" => 1,
};

$parameters{"help"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "",
	"usageText" => "Prints usage information for common parameters.",
	"showUsage" => 1,
};

$parameters{"interactive"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "",
	"usageText" => "Setting interactive to true causes the run harness to run in interactive mode.\nIn interactive mode it is possible to manually adjust the number of users interacting with each application instance.",
	"showUsage" => 1,
};

$parameters{"users"} = {
	"type"    => "=s",
	"default" => "300",
	"parent"  => "appInstance",
	"usageText" =>
"This is the number of simulated users to use for a run.\n\tThe number of simulated users is the primary metric of load for the Weathervane benchmark.",
	"showUsage" => 1,
};

$parameters{"maxUsers"} = {
	"type"    => "=i",
	"default" => 300,
	"parent"  => "dataManager",
	"usageText" =>
"This parameter controls how much data is pre-loaded into the data services.\nIt is the maximum number of simulated users that will be used for this data-load.\n",
	"showUsage" => 1,
};

$parameters{"description"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "runManager",
	"usageText" => "This parameter is used to include a description of the run in the csv summary file",
	"showUsage" => 1,
};

$parameters{"runLength"} = {
	"type"      => "=s",
	"default"   => "medium",
	"parent"    => "runProc",
	"usageText" => "This is a shortcut for specifying the length of a run.\n\t"
	  . "Allowable values:\n\t"
	  . "short (120s, 180s, 60s)\n\t"
	  . "medium (600s, 900s, 60s)\n\t"
	  . "long ( 600s, 1800s, 120s)",
	"showUsage" => 1,
};
$parameters{"rampUp"} = {
	"type"    => "=i",
	"default" => "",
	"parent"  => "runProc",
	"usageText" =>
"This is the length of the ramp-up period for the run.\n\tIt overrides the ramp-up length set by the runLength parameter.\n\tThe number of users is slowly increased over the course of the ramp-up period.",
	"showUsage" => 1,
};
$parameters{"steadyState"} = {
	"type"    => "=i",
	"default" => "",
	"parent"  => "runProc",
	"usageText" =>
"This is the length of the steady-state period for the run.\n\tIt overrides the steady-state length set by the runLength parameter.\n\tThe steady-state must be long enough for the performance metrics to stabilize.",
	"showUsage" => 1,
};
$parameters{"rampDown"} = {
	"type"      => "=i",
	"default"   => "",
	"parent"    => "runProc",
	"usageText" => "This is the length of the ramp-down period for the run.\n\t"
	  . "It overrides the ramp-down length set by the runLength parameter.",
	"showUsage" => 1,
};

$parameters{"userLoadPath"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"usageText" => "This is the load path for the run. It is a list of load intervals. ",
	"showUsage" => 1,
};

$parameters{"repeatUserLoadPath"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"configPath"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "appInstance",
	"usageText" => "This is the configuration path for the number of web and app servers.\n" . 
	"It is a list of intervals, with each interval having a duration and a number of web and app servers. ",
	"showUsage" => 1,
};

$parameters{"repeatConfigPath"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"maxDuration"} = {
	"type"      => "=i",
	"default"   => 7200,
	"parent"    => "runProc",
	"usageText" => "This maximum run duration, in seconds, that needs to be supported "
	  . "by the preloaded data.  If the current load won't support this duration then "
	  . "the data will be reloaded.\n" . "The default is 7200, equal to 2 hours.",
	"showUsage" => 1,
};

# Parameters for selecting the runManager
$parameters{"runStrategy"} = {
	"type"      => "=s",
	"default"   => "single",
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

# Parameters for selecting the runProcedure
$parameters{"runProcedure"} = {
	"type"      => "=s",
	"default"   => "full",
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"logLevel"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "",
	"usageText" => "The Logging level controls the amount of information that is \n\t"
	  . "collected during a run and placed in the output directory\n\t"
	  . "for the run.  Each level also collects all data specified \n\t"
	  . "in all lower levels.\n\t"
	  . "The log levels are as follows:\n\t"
	  . " 0 : The only data saved for a run is the results file and\n\t"
	  . "     the logs generated by the run script.\n\t"
	  . " 1 : After a run, copy over the log files from the application services.  \n\t"
	  . " 2 : Collect performance data on all workload-driver and application hosts\n\t"
	  . " 3 : Collect performance stats from the workload-drivers and all application services.\n\t"
	  . " 4 : Collect performance data from all virtual-infrastructure hosts",
	"showUsage" => 1,
};

$parameters{"isUpRetries"} = {
	"type"      => "=i",
	"default"   => 3,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"stop"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runManager",
	"usageText" => "The stop parameter instructs the run script to attempt to cleanly stop an active run",
	"showUsage" => 1,
};

$parameters{"redeploy"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"backup"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"rebackup"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};
$parameters{"reloadDb"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "Force the harness to reload the database even if it is already loaded.",
	"showUsage" => 1,
};
$parameters{"fullFilePath"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"stopServices"} = {
	"type"      => "!",
	"default"   => 1,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"restartNtp"} = {
	"type"      => "!",
	"default"   => 0,
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};
$parameters{"harnessHostNtpServer"} = {
	"type"      => "!",
	"default"   => 0,
	"parent"    => "host",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"configFile"} = {
	"type"    => "=s",
	"default" => "/root/weathervane/weathervane.config",
	"parent"  => "",
	"usageText" =>
"This is the name of the Weathervane configuration file.\n\tIt must either include the full path to the file\n\tor be relative to the directory from which the script is run",
	"showUsage" => 1,
};

$parameters{"responseTimePassingPercentile"} = {
	"type"      => "=f",
	"default"   => 0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};


# parameters related to loading the DB
$parameters{"loadDb"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"powerOnVms"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "If powerOnVms is set to true, the script will make sure that all of\n\t"
	  . "the VMs for the run are powered on.  For this to work, the VMs must be on the defined\n\t"
	  . "viHosts, and passwordless-ssh must be set up for all virtual-infrastructure hosts.\n\t"
	  . "powerOnVms currently works only with vSphere.",
	"showUsage" => 1,
};

$parameters{"powerOffVms"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "If powerOffVms is set to true, the script will make sure that all of\n\t"
	  . "the VMs whose names start with the hostnamePrefix that are on the viHosts and \n\t"
	  . "that are not needed for the run are powered off. \n\t"
	  . "For this to work, the VMs must be on the defined\n\t"
	  . "viHosts, and passwordless-ssh must be set up for all virtual-infrastructure hosts.\n\t"
	  . "powerOffVms currently works only with vSphere.",
	"showUsage" => 1,
};


$parameters{"powerOffAllVms"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "runProc",
	"usageText" => "If powerOffAllVms is set to true, the script will make sure that all of\n\t"
	  . "the VMs on the viHosts that are not needed for the run are powered off. \n\t"
	  . "For this to work, the VMs must be on the defined\n\t"
	  . "viHosts, and passwordless-ssh must be set up for all virtual-infrastructure hosts.\n\t"
	  . "powerOffVms currently works only with vSphere.",
	"showUsage" => 0,
};

# stats collection script call-out variables
$parameters{"startStatsScript"} = {
	"type"      => "=s",
	"default"   => '',
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};
$parameters{"stopStatsScript"} = {
	"type"      => "=s",
	"default"   => '',
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerWeathervaneVersion"} = {
	"type"      => "=s",
	"default"   => "1.1.0",
	"parent"    => "host",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dockerNamespace"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "host",
	"usageText" => "This is the namespace from which to pull the Docker images.  It\nshould be either a username on Docker Hub, or a \nprivate registry hostname:portnumber.",
	"showUsage" => 1,
};

$parameters{"useDocker"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerCpus"} = {
	"type"      => "=f",
	"default"   => 0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerCpuShares"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerCpuSetCpus"} = {
	"type"      => "=s",
	"default"   => "unset",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerCpuSetMems"} = {
	"type"      => "=s",
	"default"   => "unset",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerMemory"} = {
	"type"      => "=s",
	"default"   => 0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerMemorySwap"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerNet"} = {
	"type"      => "=s",
	"default"   => "bridge",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"vicHost"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "host",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerHostPort"} = {
	"type"      => "=i",
	"default"   => 2376,
	"parent"    => "host",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dockerServiceImages"} = {
	"type"    => "=s",
	"default" => {
		"nginx"      => "weathervane-nginx",
		"tomcat"     => "weathervane-tomcat",
		"haproxy"    => "weathervane-haproxy",
		"rabbitmq"   => "weathervane-rabbitmq",
		"postgresql" => "weathervane-postgresql",
		"mongodb"    => "weathervane-mongodb",
		"zookeeper"  => "weathervane-zookeeper",
		"webConfig"  => "weathervane-cm",
	},
	"parent"    => "host",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServerPerformanceMonitor"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mustPass"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"stopOnFailure"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"numAppInstances"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workload",
	"isa"       => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"numDrivers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workload",
	"isa"       => "workloadDriver",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numWorkloads"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "runProc",
	"isa"       => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numIpManagers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "ipManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"useVirtualIp"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"numConfigurationManagers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "configurationManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numCoordinationServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "coordinationServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numElasticityServices"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "elasticityService",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numLbServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "lbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numWebServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numAppServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "appServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numDbServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"numNosqlServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "nosqlServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nosqlReplicated"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nosqlSharded"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nosqlReplicasPerShard"} = {
	"type"      => "=i",
	"default"   => 3,
	"parent"    => "nosqlServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numMsgServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "msgServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"numFileServers"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"isa"       => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"viMgmtHost"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"viMgmtHostSuffix"} = {
	"type"      => "=s",
	"default"   => "ViMgmt",
	"parent"    => "viMgmtHost",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"numViMgmtHosts"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "virtualInfrastructure",
	"isa"       => "viMgmtHost",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"viMgmtHosts"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "virtualInfrastructure",
	"isa"       => "viMgmtHost",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"viHost"} = {
	"type"      => "hash",
	"default"   => {},
	"parent"    => "runProc",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"viHostSuffix"} = {
	"type"      => "=s",
	"default"   => "Vi",
	"parent"    => "viHost",
	"usageText" => "",
	"showUsage" => 0,
};


$parameters{"numViHosts"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "virtualInfrastructure",
	"isa"       => "viHost",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"viHosts"} = {
	"type"      => "list",
	"default"   => [],
	"parent"    => "virtualInfrastructure",
	"isa"       => "viHost",
	"usageText" => "",
	"showUsage" => 0,
};

# parameter for selecting the workload driver and application
$parameters{"workloadImpl"} = {
	"type"      => "=s",
	"default"   => "auction",
	"parent"    => "workload",
	"usageText" => "This parameter is used to select which workload should be used.\n\t"
	  . "At the present time, only auction is supported.",
	"showUsage" => 0,
};

$parameters{"appInstanceImpl"} = {
	"type"      => "=s",
	"default"   => "auction",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"edgeService"} = {
	"type"      => "=s",
	"parent"    => "appInstance",
	"default"   => "lbServer",
	"showUsage" => 0,
};

# parameters for selecting service implementations
$parameters{"ipManagerImpl"} = {
	"type"      => "=s",
	"default"   => "keepalived",
	"parent"    => "appInstance",
	"showUsage" => 0,
};

$parameters{"configurationManagerImpl"} = {
	"type"      => "=s",
	"default"   => "webConfig",
	"parent"    => "appInstance",
	"usageText" => "Controls which configuration manager to use.  Currently must be webConfig.",
	"showUsage" => 0,
};

$parameters{"elasticityServiceImpl"} = {
	"type"      => "=s",
	"default"   => "scheduledES",
	"parent"    => "appInstance",
	"usageText" => "Controls which elasticity service to use.  Currently must be localElasticity.",
	"showUsage" => 0,
};

$parameters{"coordinationServerImpl"} = {
	"type"      => "=s",
	"default"   => "zookeeper",
	"parent"    => "appInstance",
	"usageText" => "Controls which coordination server to use.  Currently must be zookeeper.",
	"showUsage" => 0,
};

$parameters{"lbServerImpl"} = {
	"type"      => "=s",
	"default"   => "haproxy",
	"parent"    => "appInstance",
	"usageText" => "Controls which load-balancer to use.  Currently must be haproxy.",
	"showUsage" => 0,
};
$parameters{"appServerImpl"} = {
	"type"      => "=s",
	"default"   => "tomcat",
	"parent"    => "appInstance",
	"usageText" => "Controls which Application Server to use.\n\t" . "Currently only tomcat is supported.",
	"showUsage" => 0,
};
$parameters{"appServerCacheImpl"} = {
	"type"      => "=s",
	"default"   => "ehcache",
	"parent"    => "appInstance",
	"usageText" => "Controls which cache provider to use in the Application Server.\n\t" . "Currently ehcache and ignite are supported.",
	"showUsage" => 0,
};
$parameters{"webServerImpl"} = {
	"type"      => "=s",
	"default"   => "nginx",
	"parent"    => "appInstance",
	"usageText" => "Controls which Web Server to use.\n\tMust be one of: httpd or nginx",
	"showUsage" => 1,
};
$parameters{"dbServerImpl"} = {
	"type"      => "=s",
	"default"   => "postgresql",
	"parent"    => "appInstance",
	"usageText" => "Controls which database to use.\n\tMust be one of: mysql, postgresql",
	"showUsage" => 1,
};
$parameters{"nosqlServerImpl"} = {
	"type"      => "=s",
	"default"   => "mongodb",
	"parent"    => "appInstance",
	"usageText" => "Controls which NoSQL data-store to use.\n\t" . "Currently only MongoDB is supported.",
	"showUsage" => 0,
};
$parameters{"msgServerImpl"} = {
	"type"      => "=s",
	"default"   => "rabbitmq",
	"parent"    => "appInstance",
	"usageText" => "Controls which message server to use.\n\t" . "Currently only RabbitMQ is supported.",
	"showUsage" => 0,
};
$parameters{"fileServerImpl"} = {
	"type"      => "=s",
	"default"   => "nfs",
	"parent"    => "appInstance",
	"usageText" => "Controls which file server to use.\n\t" . "Currently only NFS is supported.",
	"showUsage" => 0,
};
$parameters{"imageStoreType"} = {
	"type"      => "=s",
	"default"   => "mongodb",
	"parent"    => "appInstance",
	"usageText" => "Controls which imageStore implementation to use.\n\t"
	  . "Must be one of: mongodb, filesystem, filesystemApp, or memory",
	"showUsage" => 1,
};

$parameters{"ssl"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "workload",
	"usageText" => "Controls whether to use SSL between the workload driver and the application.",
	"showUsage" => 0,
};

$parameters{"randomizeImages"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "appServer",
	"usageText" => "Controls whether to add random noise to images before writing them to the imageStore.",
	"showUsage" => 0,
};

$parameters{"useImageWriterThreads"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "appServer",
	"usageText" => "Controls whether to use separate threads for writing images in the Auction application.",
	"showUsage" => 0,
};

$parameters{"imageWriterThreads"} = {
	"type"    => "=i",
	"default" => 0,
	"parent"  => "appServer",
	"usageText" =>
"Controls how many threads to use for writing images out by the Auction application.  Setting this overrides the default, which is 5 threads/cpu on the app server.",
	"showUsage" => 0,
};

$parameters{"numClientUpdateThreads"} = {
	"type"      => "=i",
	"default"   => 2,
	"parent"    => "appServer",
	"usageText" => "Controls how many threads to use for running client bid updates in the Auction application. ",
	"showUsage" => 0,
};

$parameters{"numAuctioneerThreads"} = {
	"type"      => "=i",
	"default"   => 2,
	"parent"    => "appServer",
	"usageText" => "Controls how many threads to use for running auctioneers in the Auction application. ",
	"showUsage" => 0,
};

$parameters{"highBidQueueConcurrency"} = {
	"type"    => "=i",
	"default" => 0,
	"parent"  => "appInstance",
	"usageText" =>
	  "Controls how many threads to use for handling rabbitmq highBid message callbacks in the Auction application. ",
	"showUsage" => 0,
};

$parameters{"newBidQueueConcurrency"} = {
	"type"    => "=i",
	"default" => 0,
	"parent"  => "appInstance",
	"usageText" =>
	  "Controls how many threads to use for handling rabbitmq newBid message callbacks in the Auction application. ",
	"showUsage" => 0,
};

$parameters{"prewarmAppServers"} = {
	"type"    => "!",
	"default"   => JSON::true,
	"parent"  => "appInstance",
	"usageText" =>
	  "Controls whether the run harness using the configuration manager to pre-warm the app servers.\n" .
	  "Must have a configuration manager in the configuration when setting this option to true.",
	"showUsage" => 1,
};

$parameters{"virtualInfrastructureType"} = {
	"type"      => "=s",
	"default"   => "vsphere",
	"parent"    => "virtualInfrastructure",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"initialRateStep"} = {
	"type"      => "=i",
	"default"   => 500,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"minRateStep"} = {
	"type"      => "=i",
	"default"   => 125,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"repeatsAtMax"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"targetUtilization"} = {
	"type"      => "=i",
	"default"   => 70,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"targetUtilizationMarginPct"} = {
	"type"      => "=f",
	"default"   => 0.02,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};
$parameters{"targetUtilizationServiceType"} = {
	"type"      => "=s",
	"default"   => "appServer",
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dbLoaderThreads"} = {
	"type"      => "=i",
	"default"   => 6,
	"parent"    => "dataManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"dbLoaderHeap"} = {
	"type"      => "=s",
	"default"   => "4G",
	"parent"    => "dataManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"scale"} = {
	"type"      => "=i",
	"default"   => -1,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"useThinkTime"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"driverJvmOpts"} = {
	"type"      => "=s",
	"default"   => "-Xmx2g -Xms2g -XX:+AlwaysPreTouch",
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"driverMaxConnPerUser"} = {
	"type"      => "=i",
	"default"   => 4,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"driverThreads"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"driverHttpThreads"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"driverMaxTotalConnectionsMultiplier"} = {
	"type"      => "=f",
	"default"   => 2,
	"usageText" => "",
	"parent"    => "workloadDriver",
	"showUsage" => 0,
};

$parameters{"driverJvmDnsTtl"} = {
	"type"      => "=i",
	"default"   => 5,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

# Parameters specific to the configuration service
$parameters{"configurationManagerJvmOpts"} = {
	"type"      => "=s",
	"default"   => "-Xmx500m -Xms500m -XX:+AlwaysPreTouch",
	"parent"    => "configurationManager",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"maxLogLines"} = {
	"type"      => "=i",
	"default"   => 4000,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

# Parameters specific to App Servers

$parameters{"appServerThumbnailImageCacheSizeMultiplier"} = {
	"type"      => "=i",
	"default"   => 25,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServerPreviewImageCacheSizeMultiplier"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServerFullImageCacheSizeMultiplier"} = {
	"type"      => "=i",
	"parent"    => "appInstance",
	"default"   => 0,
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServerThreads"} = {
	"type"      => "=i",
	"default"   => 50,
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"appServerJdbcConnections"} = {
	"type"      => "=i",
	"default"   => 51,
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"appServerJvmOpts"} = {
	"type"      => "=s",
	"default"   => "-Xmx2G -Xms2G -XX:+AlwaysPreTouch",
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdKeepalive"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdKeepaliveTimeout"} = {
	"type"      => "=i",
	"default"   => 120,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdMaxKeepaliveRequests"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdMaxClients"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdThreadsPerChild"} = {
	"type"      => "=i",
	"default"   => 100,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"httpdMinSpareThreads"} = {
	"type"      => "=i",
	"default"   => 25,
	"usageText" => "",
	"parent"    => "webServer",
	"showUsage" => 1,
};

$parameters{"httpdMaxSpareThreads"} = {
	"type"      => "=i",
	"default"   => 2000,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

# parameters specific to Nginx
$parameters{"nginxKeepaliveTimeout"} = {
	"type"      => "=i",
	"default"   => 120,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nginxMaxKeepaliveRequests"} = {
	"type"      => "=i",
	"default"   => 1000,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nginxWorkerConnections"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nginxUseNamedVolumes"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nginxCacheVolume"} = {
	"type"      => "=s",
	"default"   => "nginxCache",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nginxCacheVolumeSize"} = {
	"type"      => "=s",
	"default"   => "12GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

# Parameters specific to haproxy
$parameters{"haproxyProcPerCpu"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"haproxyTerminateTLS"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"haproxyAppServerMaxConn"} = {
	"type"      => "=i",
	"default"   => 10000,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"haproxyMaxConn"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"frontendConnectionMultiplier"} = {
	"type"      => "=i",
	"default"   => 10,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

# Parameters specific to MySQL
$parameters{"mysqlStatsInterval"} = {
	"type"      => "=i",
	"default"   => 120,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mysqlInnodbBufferPoolSize"} = {
	"type"      => "=s",
	"default"   => 0,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"mysqlInnodbBufferPoolSizePct"} = {
	"type"      => "=f",
	"default"   => 0.75,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"mysqlMaxConnections"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

# Parameters specific to PostgreSQL
$parameters{"postgresqlSharedBuffers"} = {
	"type"      => "=s",
	"default"   => 0,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"postgresqlSharedBuffersPct"} = {
	"type"      => "=f",
	"default"   => 0.25,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"postgresqlEffectiveCacheSize"} = {
	"type"      => "=s",
	"default"   => 0,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"postgresqlEffectiveCacheSizePct"} = {
	"type"      => "=f",
	"default"   => 0.65,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"postgresqlMaxConnections"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 1,
};

# Parameters specific to MongoDB
$parameters{"mongodbUseTHP"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "nosqlServer",
	"usageText" => "Controls whether transparent huge pages are used on the MongoDB VM.",
	"showUsage" => 1,
};

$parameters{"mongodbTouch"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "appInstance",
	"usageText" => "Controls whether the Attendance, Bid, imageThumbnail, and imageInfo tables are preloaded using touch.",
	"showUsage" => 0,
};

$parameters{"mongodbTouchFull"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "Controls whether the imageFull tables are preloaded using touch.",
	"showUsage" => 0,
};

$parameters{"mongodbTouchPreview"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "Controls whether the imagePreview tables are preloaded using touch.",
	"showUsage" => 0,
};

$parameters{"mongodbCompact"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "appInstance",
	"usageText" => "Controls whether storage is reclaimed from MongoDB by compacting the tables after a run.",
	"showUsage" => 0,
};

# Parameters specific to NFS
$parameters{"nfsProcessCount"} = {
	"type"      => "=i",
	"default"   => 32,
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nfsServiceName"} = {
	"type"      => "=s",
	"default"   => "nfs-server",
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nfsRsize"} = {
	"type"      => "=i",
	"default"   => 65536,
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nfsWsize"} = {
	"type"      => "=i",
	"default"   => 1048567,
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nfsServerAsync"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"nfsClientAsync"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "fileServer",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"appServerEnableJprofiler"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 0,
};

# parameters specific to tomcat
$parameters{"tomcatCatalinaHome"} = {
	"type"      => "=s",
	"default"   => "/opt/apache-tomcat",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"tomcatCatalinaBase"} = {
	"type"      => "=s",
	"default"   => "/opt/apache-tomcat-auction1",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"igniteAuthTokenCacheMode"} = {
	"type"      => "=s",
	"default"   => "REPLICATED",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"igniteCopyOnRead"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};


# parameters specific to Apache httpd
$parameters{"httpdServerRoot"} = {
	"type"      => "=s",
	"default"   => "/etc/httpd",
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"nginxServerRoot"} = {
	"type"      => "=s",
	"default"   => "/etc/nginx",
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nginxDocumentRoot"} = {
	"type"      => "=s",
	"default"   => "/usr/share/nginx/html",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"httpdDocumentRoot"} = {
	"type"      => "=s",
	"default"   => "/var/www/vhosts/auction/html",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"haproxyServerRoot"} = {
	"type"      => "=s",
	"parent"    => "lbServer",
	"default"   => "/etc/haproxy",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"workloadDriverPort"} = {
	"type"      => "=i",
	"default"   => 7500,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"workloadDriverPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};


$parameters{"configurationManagerPort"} = {
	"type"      => "=i",
	"default"   => 8888,
	"parent"    => "configurationManager",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"configurationManagerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "configurationManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"zookeeperRoot"} = {
	"type"      => "=i",
	"default"   => "/opt/zookeeper",
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"zookeeperDataDir"} = {
	"type"      => "=i",
	"default"   => "/mnt/zookeeper",
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"zookeeperClientPort"} = {
	"type"      => "=i",
	"default"   => 2181,
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"zookeeperPeerPort"} = {
	"type"      => "=i",
	"default"   => 2888,
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"zookeeperElectionPort"} = {
	"type"      => "=i",
	"default"   => 3888,
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"coordinationServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "coordinationServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"lbServerPortOffset"} = {
	"type"      => "=i",
	"default"   => 7000,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"lbServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "lbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"webServerPortOffset"} = {
	"type"      => "=i",
	"default"   => 9000,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"webServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "webServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"appServerPortOffset"} = {
	"type"      => "=i",
	"default"   => 8000,
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"appServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "appServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"msgServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "msgServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dbServerPortStep"} = {
	"type"      => "=i",
	"default"   => 1,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"nosqlServerPortStep"} = {
	"type"      => "=i",
	"default"   => 100,
	"parent"    => "nosqlServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mysqlPort"} = {
	"type"      => "=i",
	"default"   => 3306,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"postgresqlPort"} = {
	"type"      => "=i",
	"default"   => 5432,
	"parent"    => "dbServer",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"rabbitmqPort"} = {
	"type"      => "=i",
	"default"   => 5672,
	"parent"    => "msgServer",
	"usageText" => "",
	"showUsage" => 0,
};

# Parameters specific to keepalived
$parameters{"keepalivedServerRoot"} = {
	"type"      => "=s",
	"default"   => "/etc/keepalived",
	"parent"    => "ipManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mysqlBackupDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbBackup/mysql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mysqlDataDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbData/mysql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mysqlLogDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbLogs/mysql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlBackupDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbBackup/postgresql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlDataDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbData/postgresql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlUseNamedVolumes"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"postgresqlDataVolume"} = {
	"type"      => "=s",
	"default"   => "postgresqlData",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlDataVolumeSize"} = {
	"type"      => "=s",
	"default"   => "20GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlLogDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbLogs/postgresql",
	"usageText" => "",
	"parent"    => "appInstance",
	"showUsage" => 0,
};

$parameters{"postgresqlLogVolume"} = {
	"type"      => "=s",
	"default"   => "postgresqlLogs",
	"usageText" => "",
	"parent"    => "appInstance",
	"showUsage" => 0,
};

$parameters{"postgresqlLogVolumeSize"} = {
	"type"      => "=s",
	"default"   => "20GB",
	"usageText" => "",
	"parent"    => "appInstance",
	"showUsage" => 0,
};

$parameters{"postgresqlConfDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/dbData/postgresql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlHome"} = {
	"type"      => "=s",
	"default"   => "/usr/pgsql-9.3",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"postgresqlServiceName"} = {
	"type"      => "=s",
	"default"   => "postgresql-9.3",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbBackupDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/mongoBackup",
	"parent"    => "nosqlServer",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbDataDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/mongoData",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbUseNamedVolumes"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 1,
};

$parameters{"mongodbDataVolume"} = {
	"type"      => "=s",
	"default"   => "mongoData",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbDataVolumeSize"} = {
	"type"      => "=s",
	"default"   => "200GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC1DataDir"} = {
	"type"      => "=s",
	"parent"    => "appInstance",
	"default"   => "/mnt/mongoC1Data",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC1DataVolume"} = {
	"type"      => "=s",
	"default"   => "mongoC1Data",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC1DataVolumeSize"} = {
	"type"      => "=s",
	"default"   => "10GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC2DataDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/mongoC2Data",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC2DataVolume"} = {
	"type"      => "=s",
	"default"   => "mongoC2Data",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC2DataVolumeSize"} = {
	"type"      => "=s",
	"default"   => "10GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC3DataDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/mongoC3Data",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC3DataVolume"} = {
	"type"      => "=s",
	"default"   => "mongoC3Data",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"mongodbC3DataVolumeSize"} = {
	"type"      => "=s",
	"default"   => "10GB",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"rampupInterval"} = {
	"type"      => "=i",
	"default"   => 10,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"imageStoreDir"} = {
	"type"    => "=s",
	"default" => "/mnt/imageStore",
	"parent"  => "appInstance",
	"usageText" =>
"This is the location of the directory in which images are stored when the\n\timageStore type is filesystem.   This is the \n\tdirectory that is exported by NFS and mounted by other VMs.",
	"showUsage" => 0,
};

$parameters{"imageStoreBackupDir"} = {
	"type"      => "=s",
	"default"   => "/mnt/imageStoreBackup",
	"parent"    => "appInstance",
	"usageText" => "This is the directory in which backups of the filesystem-based imageStore are saved.",
	"showUsage" => 0,
};

$parameters{"wwwHostnamePrefix"} = {
	"type"    => "=s",
	"default" => "www",
	"parent"  => "appInstance",
	"usageText" =>
	  "This is the suffix for the hostname that is used as the main entry-point for a Auction application.",
	"showUsage" => 0,
};

$parameters{"wwwHostname"} = {
	"type"      => "=s",
	"default"   => "",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"hostnamePrefix"} = {
	"type"      => "=s",
	"default"   => "Auction",
	"parent"    => "",
	"usageText" => "This is the prefix used for hostnames and VM names.",
	"showUsage" => 1,
};

$parameters{"appInstanceSuffix"} = {
	"type"      => "=s",
	"default"   => "I",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"useAllSuffixes"} = {
	"type"    => "!",
	"default" => JSON::false,
	"parent"  => "",
	"usageText" =>
	  "Controls whether to use workload and appInstance suffixes in hostnames when only one workload or appInstance.",
	"showUsage" => 0,
};

$parameters{"workloadSuffix"} = {
	"type"      => "=s",
	"default"   => "W",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"dataManagerSuffix"} = {
	"type"      => "=s",
	"default"   => "Dm",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"workloadDriverSuffix"} = {
	"type"      => "=s",
	"default"   => "Driver",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"ipManagerSuffix"} = {
	"type"      => "=s",
	"default"   => "Lb",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,

};
$parameters{"configurationManagerSuffix"} = {
	"type"      => "=s",
	"default"   => "Cm",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"coordinationServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Cs",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"elasticityServiceSuffix"} = {
	"type"      => "=s",
	"default"   => "Es",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"lbServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Lb",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"appServerSuffix"} = {
	"type"      => "=s",
	"default"   => "App",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"webServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Web",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"dbServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Db",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"nosqlServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Nosql",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"msgServerSuffix"} = {
	"type"      => "=s",
	"default"   => "Msg",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"fileServerSuffix"} = {
	"type"      => "=s",
	"default"   => "File",
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"weathervaneHome"} = {
	"type"    => "=s",
	"default" => "/root/weathervane",
	"parent"  => "",
	"usageText" =>
"This is the base directory under which the Weathervane harness expects to find its files.\n\tIf other directory related parameters are not diven with a full\n\tpath, they will be realative to this directory.",
	"showUsage" => 1,
};

# If not absolute (starting with /) these directories are relative
# to weathervaneHome
$parameters{"tmpDir"} = {
	"type"    => "=s",
	"default" => "tmpLog",
	"parent"  => "runProc",
	"usageText" =>
"This is the directory in which Weathervane stores temporary files during a run.\n\tDo not use /tmp or any directory whose contents you wish to keep.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"outputDir"} = {
	"type"    => "=s",
	"default" => "output",
	"parent"  => "runProc",
	"usageText" =>
"This is the directory in which Weathervane stores the output from runs.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"sequenceNumberFile"} = {
	"type"    => "=s",
	"default" => "output/sequence.num",
	"parent"  => "runProc",
	"usageText" =>
"This is the file that Weathervane uses to store the sequence number of the next run.\n\tIt must either include the full path to the file\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"distDir"} = {
	"type"    => "=s",
	"default" => "dist",
	"parent"  => "runProc",
	"usageText" =>
"This is the directory for the executables and other artifacts needed to run Weathervane.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"dbScriptDir"} = {
	"type"    => "=s",
	"default" => "dist",
	"parent"  => "appInstance",
	"usageText" =>
"This is the directory that contains the scripts used to configure the database tables.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"dbLoaderDir"} = {
	"type"    => "=s",
	"default" => "dist",
	"parent"  => "dataManager",
	"usageText" =>
"This is the directory that contains the jar file for the DBLoader executable.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"workloadDriverDir"} = {
	"type"    => "=s",
	"default" => "dist",
	"parent"  => "workloadDriver",
	"usageText" =>
"This is the directory that contains the jar file for the workload-driver executable.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"workloadProfileDir"} = {
	"type"    => "=s",
	"default" => "workloadConfiguration",
	"parent"  => "workloadDriver",
	"usageText" =>
"This is the directory that contains the templates for the workload profiles.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"gcviewerDir"} = {
	"type"    => "=s",
	"default" => "",
	"parent"  => "runManager",
	"usageText" =>
"This is the path to the gcViewer executable.  GcViewer is used to\n\tanalyze the Java Garbage-Collection logs.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"resultsFileDir"} = {
	"type"    => "=s",
	"default" => "",
	"parent"  => "runManager",
	"usageText" =>
"This is the directory in which Weathervane stores the csv summary file.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"resultsFileName"} = {
	"type"    => "=s",
	"default" => "weathervaneResults.csv",
	"parent"  => "runManager",
	"usageText" =>
"This is the name of the file in which Weathervane stores a summary of the run results in csv format.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 1,
};
$parameters{"configDir"} = {
	"type"    => "=s",
	"default" => "configFiles",
	"parent"  => "runManager",
	"usageText" =>
"This is the directory under which Weathervane stores\n\t configuration files for the various services.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};
$parameters{"dbLoaderImageDir"} = {
	"type"    => "=s",
	"default" => "images",
	"parent"  => "dataManager",
	"usageText" =>
"This is the directory in which the images used by the dbLoader are stored.\n\tIt must either include the full path to the directory\n\tor be relative to weathervaneHome.",
	"showUsage" => 0,
};

$parameters{"esxDatastorePath"} = {
	"type"      => "=s",
	"default"   => "/tmp",
	"parent"    => "virtualInfrastructure",
	"usageText" => "This must be the path to a directory on the ESXi hosts in which Weathervane can store temporary files.",
	"showUsage" => 0,
};

$parameters{"workloadProfile"} = {
	"type"      => "=s",
	"default"   => "official",
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"auctions"} = {
	"type"      => "=i",
	"default"   => 0,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"usersPerAuctionScaleFactor"} = {
	"type"      => "=f",
	"default"   => 15.0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"usersScaleFactor"} = {
	"type"      => "=f",
	"default"   => 5.0,
	"parent"    => "workload",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"images"} = {
	"type"      => "!",
	"default"   => JSON::true,
	"parent"    => "dataManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"minimumUsers"} = {
	"type"      => "=i",
	"default"   => 60,
	"parent"    => "appInstance",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"proportionTolerance"} = {
	"type"      => "=f",
	"default"   => 0.1,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"statsInterval"} = {
	"type"      => "=i",
	"default"   => 10,
	"parent"    => "runManager",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"driverEnableJprofiler"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workloadDriver",
	"usageText" => "",
	"showUsage" => 0,
};
$parameters{"dbLoaderEnableJprofiler"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "dataManager",
	"usageText" => "",
	"showUsage" => 0,
};

$parameters{"showPeriodicOutput"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "workloadDriver",
	"usageText" => "Controls whether periodic workload stats are echoed to stdout.",
	"showUsage" => 1,
};

$parameters{"fullHelp"} = {
	"type"      => "!",
	"default"   => JSON::false,
	"parent"    => "",
	"usageText" => "Prints usage information for all parameters.",
	"showUsage" => 0,
};

$parameters{"debugLevel"} = {
	"type"      => "=s",
	"default"   => "INFO",
	"parent"    => "runManager",
	"usageText" => "Set the level for logging messages.",
	"showUsage" => 0,
};

1;

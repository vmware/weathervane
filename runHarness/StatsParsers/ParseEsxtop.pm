# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
#!/usr/bin/perl
#
# VMware
# Created by: Hal Rosenberg
# Creation data: 04/09/2008
# Last Modified: 08/18/2008
#
# This package contains a generic routine to parse an esxtop file into structures
# that contain a list of the columns that fall into different categories. Those
# categories include:
#          - All non-VM top-level worlds
#          - All VMs
#          - Physical CPU
#          - Memory
#          - Physical Disk
#          - Network Port
#
# It also contains routines to:
#          - Write the esxtop output into separate csv files by type of data

package ParseEsxtop;

use strict;
use Statistics::Descriptive;
use Tie::IxHash;
use IPC::Shareable qw(:all);

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA       = qw( Exporter);
	@EXPORT_OK = qw( parseEsxtop );
}

# get options
my $doReport          = 1;                          # By default, create report
my $reportFileName    = "parseEsxtop_report.txt";
my $appendReport      = 0;                          # overwrite is default
my $csvFilePrefix     = "parseEsxtop";
my $warmup            = 0;
my $cooldown          = 99999999;
my $vmStats           = '';
my $vmPrefix          = '';
my $printheader       = 1;
my $appendReport      = '';
my $appendCSV         = 1;
my $headerOnly        = '';
my $csvFiles          = '';
my $worldCsvfiles     = '';
my $componentCsvfiles = '';
my $vmSummaryFileName = '';
my $help              = '';

my $infile;

#GetOptions(
#	'report!'            => \$doReport,
#	'reportFile=s'       => \$reportFileName,
#	'appendReport!'      => \$appendReport,
#	'csvFilePrefix=s'    => \$csvFilePrefix,
#	'appendCSV!'         => \$appendCSV,
#	'warmup=i'           => \$warmup,
#	'cooldown=i'         => \$cooldown,
#	'vmstats!'           => \$vmStats,
#	'vmprefix=s'         => \$vmPrefix,
#	'printheader'        => \$printheader,
#	'headerOnly'         => \$headerOnly,
#	'csvfiles!'          => \$csvFiles,
#	'worldcsvfiles!'     => \$worldCsvfiles,
#	'componentcsvfiles!' => \$componentCsvfiles,
#	'help'               => \$help
#);
#
#if ( $cooldown != 99999999 ) {
#	print "The cooldown functionality is not yet implemented\n";
#	exit();
#}
#
#if ($help) {
#	usage();
#	exit;
#}
#
#if ( $#ARGV != 0 ) {
#	usage();
#	exit;
#}
#
#my $infile = $ARGV[0];

sub usage () {

	print "Usage:  parseEsxtop.pl [options] esxtop_file_name\n";
	print " Options:\n";
	print "     --help :                    Print this help and exit.\n";
	print "     --reportFile reportFileName : Choose the name used for the report file. \n";
	print "                                 This can include a directory name\n";
	print "                                 (default = parseEsxtop_report.txt).\n";
	print "     --{no}appendReport :        Append data to report file rather than over-writing\n";
	print "                                 (default = overwrite)\n";
	print "     --csvFilePrefix csvFilePrefix : The name used as a prefix for all of\n";
	print "                                 the csv output files. \n";
	print "                                 This can include a directory name\n";
	print "                                 (default = parseEsxtop).\n";
	print "     --{no}appendCSV :           Append data to the csv files rather than over-writing\n";
	print "                                 (default = append)\n";
	print "     --{no}report :              Create a text summary of the results as well as a csv file.\n";
	print "                                 (default = report).\n";
	print "     --warmup seconds :          Ignore data from the selected number of seconds at the start of the file.\n";
	print "                                 (default = 0).\n";
	print "     --{no}vmstats :             Include stats from all individual VMs in addition to the summary stats\n";
	print "                                 (default = novmstats).\n";
	print "     --vmprefix string :         If present, is used to limit the calculation of VM averages and \n";
	print "                                 output of per-VM data to those with the given prefix.\n";
	print "                                 (default = none).\n";
	print "     --printheader :             Include the header row in the csv output\n";
	print "                                 (default = false).\n";
	print "     --headerOnly :              Only print the header row into the csv file.  No data.\n";
	print "                                 No new-line is put into the csv file after the header.\n";
	print "                                 No report or data csvs are generated\n";
	print "                                 (default = false).\n";
	print "     --{no}csvfiles :            If enabled, the script will output separate csv files containing the full esxtop\n";
	print
	  "                                 data separated into individual files for each selected VM, and each system component,\n";
	print "                                 e.g. Memory, Physical CPU, etc.\n";
	print "                                (default = nocsvfiles).\n";
	print "     --{no}worldcsvfiles :       If enabled, the script will output separate csv files containing the full esxtop\n";
	print "                                 data separated into individual files for each non-VM world\n";
	print "                                (default = noworldcsvfiles).\n";
	print "     --{no}componentcsvfiles :   f enabled, the script will output separate csv files containing the full esxtop\n";
	print "                                 data separated into individual files for each system component,\n";
	print "                                 e.g. Memory, Physical CPU, etc.\n";
	print "                                (default = nocomponentcsvfiles).\n";
	print "Options not yet implemented:\n";
	print "     --cooldown seconds :        Ignore data from the selected number of seconds at the end of the file.\n";
	print "                                 (default = 99999999).\n";

}

# These worlds show up in esxtop output, but are not VMs
my @builtinWorlds = (
	"idle",       "system",           "helper",               "drivers",
	"vmotion",    "console",          "vmkapimod",            "FT",
	"vobd",       "vmware-vmkauthd",  "hostd",                "vpxa",
	"vmsyslogd",  "sensord",          "vprobed",              "busybox",
	"storageRM",  "sh",               "sfcb-ProviderMa",      "vmkdevmgr",
	"ft",         "nssquery",         "vim-cmd",              "init",
	"vmkeventd",  "net-lbt",          "slpd",                 "dcbd",
	"net-cdp",    "vobd",             "vmware-usbarbitrator", "openwsmand",
	"cimslp",     "sfcbd",            "sfcb-sfcb",            "getty",
	"dcui",       "sleep",            "sshd",                 "esxtop",
	"net-lacp",   "logchannellogger", "swapobjd",             "sdrsInjector",
	"rhttpproxy", "nscd",             "smartd",               "ntpd",
	"chardevlogger", "vmkiscsid", "sfcb-HTTP-Daemo", "nfsgssd", "clomd",
	"cmmdsd", "vsanSoapServer", "epd", "osfsd", "python", "dhclient-uw", 
	"ioFilterVPServer", "hostdCgiServer", "vsanTraceReader", "rm", 
	"tail", "awk", "nicmgmtd", "IORETRY_IngressLFHelper", "hyperbus",
	"mpa", "nestdb-server", "netcpa", "nsxa", "nsx-ctxteng", "nsx-da",
	"nsx-exporter", "nsx-sfhc", "nsx-support-bundle-client", 
	"vShield-Endpoint-Mux"
);

# This structure is a hash from a category for which we collect together related
# stats to a list of columns from esxtop output that have stats for the category.
# There are some categories that always exist, so we pre-set them here.  Others (e.g.
# non-VM worlds will be added later as we discover them in the output.
# All categories get column 0 (the timestamp)
my %categoryToColumnList = (
	"Physical Cpu"  => [0],
	"Memory"        => [0],
	"Physical Disk" => [0],
	"Network Port"  => [0]
);

# This structure is a hash from the VM name to a hash which equates each sub-category of stats
# for a VM to a list of relevant columns. It starts empty, and is built up once we find a VM name.
my %vmToColumnList;

# List with columns that have % Used and Physical CPU for all sub-worlds.
my @pctUsedColumns;

# List of hashes.  Each hash has information about one world,
# with the keys being name and id.
my @worlds = ();

# List of all VM names found in esxtop data
my @vms = ();

# Structures for tracking vmhba data
my @vmhbas;
my %hbaToCategoryToColumnHash;

# Structures for tracking vmnic data
my @vmnics;
my %nicToCategoryToColumnHash;

# @datacolumns is a list of lists.  Each sub-list is one column from the esxtop
# file, in order.
my @dataColumns;

my $hostname;
my @headers;
my $numRows;

# Start by parsing the esxtop file.  Results end up in package global
# variables (for now anyway).
#parseEsxtopCmdline($infile);

sub printResults {
	my @headers;
	my @values;

	# Open the output files
	my $reportOutdirection = ">";
	if ($appendReport) {
		$reportOutdirection = ">>";
	}
	my $csvOutdirection = ">";
	if ( $appendCSV || $headerOnly ) {
		$csvOutdirection = ">>";
	}

	my $CSVFILE;
	my $REPORTFILE;
	my $VMSUMMARYFILE;
	open $CSVFILE, "${csvOutdirection}${csvFilePrefix}.csv" or die "Can't open ${csvOutdirection}${csvFilePrefix}.csv: $!";
	if ($doReport) {
		open $REPORTFILE, "${reportOutdirection}${reportFileName}" or die "Can't open ${reportOutdirection}${reportFileName}: $!";
	}

	open $VMSUMMARYFILE, ">>$vmSummaryFileName" or die "Can't open $vmSummaryFileName: $!";
	

	# If we are supposed to print a header line in the csv file, then do it first
	@headers = printHeader( $CSVFILE, $vmStats, $VMSUMMARYFILE, @vms );
	print( $CSVFILE "\n" );

	@values = printStats( $CSVFILE, $REPORTFILE, $doReport, $VMSUMMARYFILE, @vms  );
	if ($csvFiles) {
		writeCSVFiles();
		analyzePctUsedData();
	}
	printCpuSummaryCsvs($csvFilePrefix);

	close CSVFILE;
	if ($doReport) {
		close REPORTFILE;
	}
	close $VMSUMMARYFILE;
	
	tie (my %retVal, 'Tie::IxHash');
	@retVal{@headers} = @values;

	return \%retVal;
}

sub parseEsxtop {
	(
		$infile, $doReport, $reportFileName, $appendReport, $csvFilePrefix, $warmup,
		$cooldown,   $vmStats,  $vmPrefix,       $printheader,  $appendReport,  $appendCSV,
		$headerOnly, $csvFiles, $worldCsvfiles,  $componentCsvfiles, $vmSummaryFileName
	  )
	  = @_;

	# Clear the global variables
	%categoryToColumnList = (
		"Physical Cpu"  => [0],
		"Memory"        => [0],
		"Physical Disk" => [0],
		"Network Port"  => [0]
	);
	undef %vmToColumnList;
	@pctUsedColumns = ();
	@worlds = ();
	@vms = ();
	@vmhbas = ();
	undef %hbaToCategoryToColumnHash;
	@vmnics = ();
	undef %nicToCategoryToColumnHash;
	@dataColumns = ();

	# do the parsing
	parseEsxtopCmdline($infile);
	my $retVal = printResults();
	return $retVal;
}

sub parseEsxtopCmdline {

	my ($inFileName) = @_;
	# TODO - DELETE this comment: ESXTOP is file handler
	open( ESXTOP, "$inFileName" ) || die("Couldn't open esxtop file $inFileName: $!");

	my $inLine = <ESXTOP>;
	chomp($inLine);
	@headers = split /,/, $inLine;
	my $numColumns = @headers;

	# get the hostname
	$hostname = $headers[1];
	$hostname =~ s/"\\\\([^\\]+)\\.*"/$1/; # TODO - DELETE this comment: $1 is hostname

	# TODO: Remove this comment block
	# Create shared memory segment here.
	# Include all variables relevant to this function.

	my $columnNumber = 0;
	foreach my $header (@headers) {

		# TODO: Remove this comment block
		# Try forking here for each header (ie analyzing each header on a diff process)
		# Look at this: https://metacpan.org/pod/Parallel::ForkManager#start-[-$process_identifier-]

		# Remove the quotes and initial \\
		$header =~ s/"\\\\(.+)"/$1/;

		# Remove the hostname from the column header
		$header =~ s/$hostname(.+)/$1/;

		# Get the world name and id as we go.  Later we will take
		# advantage of the fact the the Group Cpu column is the first appearence
		# of a world.
		if ( $header =~ /Group Cpu\((\d+):(.+)(\.\d+)?\)\\Members.*/ ) {
			push @worlds, { name => $2, id => $1 };
			my $worldname = $2;

			# remove .nnnn from world names
			if ( $worldname =~ /(.+)\.\d+/ ) {
				$worldname = $1;
			}
			my @worldMatch = grep {$_ =~ /\Q$worldname/ || ($worldname =~ /\Q$_/)} @builtinWorlds;
			if ( $#worldMatch == -1 ) {
				if ( ( $vmPrefix eq '' ) || ( $worldname =~ /$vmPrefix/ ) ) {
					push @vms, $worldname;

					# Create the structure for tracking stat columns for this VM
					# ToDo: For now we ignore the CPU stats for the sub-worlds.
					$vmToColumnList{$worldname} = {
						"Group Cpu"     => [0],
						"Group Memory"  => [0],
						"Physical Disk" => [0],
						"Network Port"  => [0]
					};
				}
			}
			elsif ($worldCsvfiles) {

				# Add a stats category for this world
				$categoryToColumnList{$worldname} = [0];
			}
		}

		# Find the names of all vmhba's and initialize their structure
		if ( $header =~ /Physical\sDisk\((vmhba\d+)\)\\Adapter\sQ\sDepth/ ) {
			$hbaToCategoryToColumnHash{$1} = {};
			push @vmhbas, $1;
		}

		# Find the names of all vmmic's and initialize their structure
		if ( $header =~ /Network\sPort\(.*:(vmnic\d+)\)\\Link\sUp/ ) {
			$nicToCategoryToColumnHash{$1} = {};
			push @vmnics, $1;
		}

		# Now decide what to which category this column belongs.
		# If it has a VM name in it, then it belongs to that VM.
		# We deal with VMs seperately, because they have sub-categories
		my $foundCategory = 0;
		foreach my $vmname (@vms) {
			if ( $header =~ /$vmname/ ) {

				# header has vmname in it.  Put it in the right category
				#print "Found $header for $vmname\n";
				$foundCategory = 1;
				if ( $header =~ /Group\sCpu/ ) {
					push @{ $vmToColumnList{$vmname}->{"Group Cpu"} }, $columnNumber;
				}
				elsif ( $header =~ /Group\sMemory/ ) {
					push @{ $vmToColumnList{$vmname}->{"Group Memory"} }, $columnNumber;
				}
				elsif ( $header =~ /Virtual\sDisk/ ) {
					push @{ $vmToColumnList{$vmname}->{"Virtual Disk"} }, $columnNumber;
				}
				elsif ( $header =~ /Network\sPort/ ) {
					push @{ $vmToColumnList{$vmname}->{"Network Port"} }, $columnNumber;
				}
				else {

					# For now we just drop the other columns, which are the sub-world CPU columns
				}
				last;
			}
		}

		# Check whether column is for a vmhba.
		foreach my $vmhba (@vmhbas) {

			# We only take the summary stats for each vmhba, not each user of the vmhba
			if ( $header =~ /$vmhba\)\\Writes\/sec/ ) {
				$hbaToCategoryToColumnHash{$vmhba}->{"Writes_sec"} = $columnNumber;
			}
			elsif ( $header =~ /$vmhba\)\\Reads\/sec/ ) {
				$hbaToCategoryToColumnHash{$vmhba}->{"Reads_sec"} = $columnNumber;
			}
			elsif ( $header =~ /$vmhba\)\\MBytes\sRead/ ) {
				$hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Read"} = $columnNumber;
			}
			elsif ( $header =~ /$vmhba\)\\MBytes\sWritten/ ) {
				$hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Written"} = $columnNumber;
			}
			elsif ( $header =~ /$vmhba\)\\Average\sGuest\sMilliSec\/Command/ ) {
				$hbaToCategoryToColumnHash{$vmhba}->{"Guest_Millisec"} = $columnNumber;
			}
		}

		# Check whether column is for a vmnic
		foreach my $vmnic (@vmnics) {

			# We only take the summary stats for each vmnic, not each user of the vmnic
			if ( $header =~ /:$vmnic\)\\Packets\sTransmitted/ ) {
				$nicToCategoryToColumnHash{$vmnic}->{"Transmitted_sec"} = $columnNumber;
			}
			elsif ( $header =~ /:$vmnic\)\\Packets\sReceived/ ) {
				$nicToCategoryToColumnHash{$vmnic}->{"Received_sec"} = $columnNumber;
			}
			elsif ( $header =~ /:$vmnic\)\\MBits\sTransmitted/ ) {
				$nicToCategoryToColumnHash{$vmnic}->{"MBits_Transmitted"} = $columnNumber;
			}
			elsif ( $header =~ /:$vmnic\)\\MBits\sReceived/ ) {
				$nicToCategoryToColumnHash{$vmnic}->{"MBits_Received"} = $columnNumber;
			}
		}

		# If not for a VM, but is for a built-in world or for a catagory we track, then
		# track it here
		if ( $foundCategory == 0 ) {
			foreach my $category ( keys %categoryToColumnList ) {
				if ( $header =~ /$category/ ) {
					push @{ $categoryToColumnList{$category} }, $columnNumber;
					last;
				}
			}
		}

		# If the column is a % Used then track it here so that we can create a csv file
		if ( $header =~ /Group\sCpu\(\d+:.+Used/ ) {
			foreach my $vmname (@vms) {
				if ( $header =~ /$vmname\)/ ) {
					push @pctUsedColumns, $columnNumber;
					last;
				}
			}
		}

		$columnNumber++;
	}

	# TODO: Remove this comment block
	# Possibly call wait here and combine results of all children
	# Look at https://metacpan.org/pod/Parallel::ForkManager#finish-[-$exit_code-[,-$data_structure_reference]-]

	# Might have to look at callbacks for combining data after child exits
		# https://metacpan.org/pod/Parallel::ForkManager#CALLBACKS
		# https://metacpan.org/pod/Parallel::ForkManager#run_on_finish-$code-[,-$pid-]

	# TODO: Remove this comment block
	# Cleanup shared memory here
	

	# Initialize the arrays for the data columns
	for ( my $i = 0 ; $i <= $#headers ; $i++ ) {

		# Reference to an empty list.  The actual values will go in the lists.
		$dataColumns[$i] = [];
	}

	# Rename timestamp column
	$headers[0] = "Time (seconds)";

	# Replace the spaces and slashes in the headers with underscores
	for ( my $i = 0 ; $i < @headers ; $i++ ) {
		$headers[$i] =~ s/ |\\/_/g;
		$headers[$i] =~ s/^_//;
	}

	# Now go through and read in the rest of the file, creating the columns as
	# we go along.  We also get rid of the quotes around the values.
	$numRows = 0;
	my $startTime = -1;
	# Mapping relevant variables to shared memory
	my $ipc_time = tie $startTime, 'IPC::Shareable', 
				{key => 1000, create => 1} or die "Shared memory tie failed.\n";
	my $ipc_dataColumns = tie $ParseEsxtop::dataColumns, 'IPC::Shareable', 
				{key => 1001, create => 1} or die "Shared memory tie failed.\n";
	my $ipc_warmup = tie $ParseEsxtop::warmup, 'IPC::Shareable', 
				{key => 1002, create => 1} or die "Shared memory tie failed.\n";
	my $ipc_numRows = tie $numRows, 'IPC::Shareable', 
				{key => 1003, create => 1} or die "Shared memory tie failed.\n";
	my @pids;
	while ( $inLine = <ESXTOP> ) {
		chomp($inLine);
		my @inLine = split( /,/, $inLine );

		my $pid = fork();
		if(!defined $pid){
			print("Couldn't fork a process.\n");
			exit(-1);
		}elsif ($pid == 0){ # Child
			# ensuring no concurrent access to shared memory
			$ipc_time->shlock();
			$ipc_dataColumns->shlock();
			$ipc_warmup->shlock();
			$ipc_numRows->shlock();

			$inLine[0] =~ s/"(.+)"/$1/;

			# Save the timestamp of the first row
			if ( $startTime == -1 ) {
				$startTime = $inLine[0];
			}

			# For the timestamp column, convert to seconds since start
			my $curTime = convertDate( $inLine[0], $startTime );

			if ( $curTime >= $warmup ) {

				push @{ $dataColumns[0] }, $curTime;

				for ( my $i = 1 ; $i <= $#inLine ; $i++ ) {
					$inLine[$i] =~ s/\"(.+)\"/$1/;
					push @{ $dataColumns[$i] }, $inLine[$i];
				}
				$numRows++;
			}
			# Unlocking shared memory; other processes can access now.
			$ipc_time->shunlock();
			$ipc_dataColumns->shunlock();
			$ipc_warmup->shunlock();
			$ipc_numRows->shunlock();
			exit;
		}else { # Parent
			push @pids, $pid;
		}
	}

	foreach my $pid (@pids) {
		waitpid $pid, 0;
	}

	close(ESXTOP);
}

sub writeCSVFiles {

	# Now create output files for each VM
	if ($vmStats) {

		# Headers for each VM with correct prefix
		foreach my $vmname (@vms) {
			my $filename = "${csvFilePrefix}_${vmname}.csv";

			my @categoryNames = ( "Group Cpu", "Group Memory", "Virtual Disk", "Network Port" );

			open( OUTFILE, ">$filename" ) || die("Can't open file for writing: $!");

			# First print the headers (row 0)
			for ( my $i = 0 ; $i <= $#categoryNames ; $i++ ) {

				# Reference to the list of columns in this category
				my $colListRef = \@{ $vmToColumnList{$vmname}->{ $categoryNames[$i] } };
				map( print( OUTFILE $headers[$_], "," ), @{$colListRef}[ 0 .. $#{$colListRef} ] );
			}
			print( OUTFILE "\n" );

			# Then print the data columns
			for ( my $j = 1 ; $j < $numRows ; $j++ ) {
				for ( my $i = 0 ; $i <= $#categoryNames ; $i++ ) {

					# Reference to the list of columns in this category
					my $colListRef = \@{ $vmToColumnList{$vmname}->{ $categoryNames[$i] } };

					map( print( OUTFILE ${ $dataColumns[$_] }[$j], "," ), @{$colListRef}[ 0 .. $#{$colListRef} ] );
				}
				print OUTFILE "\n";

			}
			close OUTFILE;
		}
	}

	# Now create the output files for the other categories
	if ($componentCsvfiles) {
		foreach my $category ( keys %categoryToColumnList ) {

			# remove spaces for the file name
			my $filename = $category;
			$filename =~ s/ /_/;
			$filename = "${csvFilePrefix}_${filename}";

			open( OUTFILE, ">$filename.csv" ) || die("Can't open file for writing: $!");

			# Reference to the list of columns in this category
			my $colListRef = $categoryToColumnList{$category};

			# First print the headers (row 0)
			map( print( OUTFILE $headers[$_], "," ), @{$colListRef}[ 0 .. $#{$colListRef} - 1 ] );
			print OUTFILE $headers[ ${$colListRef}[ $#{$colListRef} ] ], "\n";    # No comma on last value

			for ( my $j = 1 ; $j < $numRows ; $j++ ) {
				map( print( OUTFILE ${ $dataColumns[$_] }[$j], "," ), @{$colListRef}[ 0 .. $#{$colListRef} - 1 ] );
				print OUTFILE ${ $dataColumns[ ${$colListRef}[ $#{$colListRef} ] ] }[$j], "\n";    # No comma on last value
			}

			close OUTFILE;
		}
	}

}

sub analyzePctUsedData {

	# write csv file for %Used data
	my $filename = "pctUsed";
	$filename = "${csvFilePrefix}_${filename}";
	open( OUTFILE, ">$filename.csv" ) || die("Can't open file for writing: $!");

	# First print the headers (row 0)
	print OUTFILE "sample,";
	map( print( OUTFILE $headers[$_], "," ), @pctUsedColumns[ 0 .. $#pctUsedColumns - 1 ] );
	print OUTFILE $headers[ $pctUsedColumns[$#pctUsedColumns] ], "\n";    # No comma on last value

	for ( my $j = 1 ; $j < $numRows ; $j++ ) {
		print OUTFILE "$j,";
		map( print( OUTFILE ${ $dataColumns[$_] }[$j], "," ), @pctUsedColumns[ 0 .. $#pctUsedColumns - 1 ] );
		print OUTFILE ${ $dataColumns[ $pctUsedColumns[$#pctUsedColumns] ] }[$j], "\n";    # No comma on last value
	}

	close OUTFILE;

	# Go through the

}

# Convert the data column to seconds since start.
sub convertDate {

	# Parameters
	my ( $timestamp, $startTimestamp ) = @_;

	# Variable to accumulate the difference in seconds
	my $curTime = 0;

	# Parse the time
	my ( $date,      $time )      = split( / /, $timestamp );
	my ( $startDate, $startTime ) = split( / /, $startTimestamp );

	# determine the number of days between the start and current timestamp
	my $dayCount = 0;

	# If days are same, don't need to do anything
	if ( $date != $startDate ) {

		# Todo: This doesn't account for leap years
		my @daysInMonth = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

		my ( $month,      $day,      $year )      = split( /\//, $date );
		my ( $startMonth, $startDay, $startYear ) = split( /\//, $startDate );

		# ToDo: Currently don't handle runs that start and end in different years.
		# This allows us to assume that $month always >= $startMonth
		if ( $year != $startYear ) {
			print("Warning: This file goes over a change in years.  The timestamps will be incorrect!\n");
		}

		# The difference in days
		# Add the days in every month touched by the run
		map( $dayCount += $_, @daysInMonth[ ( $startMonth - 1 ) .. ( $month - 1 ) ] );

		# Subtract the days in the start month before and including the start day
		$dayCount -= $startDay;

		# Subtract the days in the end month after the end day
		$dayCount -= $daysInMonth[ $month - 1 ] - $day;
	}

	my ( $hour,      $minutes,      $seconds )      = split(/:/, $time);
	my ( $startHour, $startMinutes, $startSeconds ) = split(/:/, $startTime);

	# Get the time in seconds from the start of the day
	$seconds      = $hour * 60 * 60 + $minutes * 60 + $seconds;
	$startSeconds = $startHour * 60 * 60 + $startMinutes * 60 + $startSeconds;

	if ( $dayCount > 0 ) {

		# Different days.  Need seconds after start time and seconds
		# before current time.
		my $secondsInDay = 24 * 60 * 60;
		$seconds = ( $secondsInDay - $startSeconds ) + $seconds;
	}
	else {
		$seconds = $seconds - $startSeconds;
	}

	# Convert everything to seconds
	$curTime = $dayCount * 24 * 60 * 60 + $seconds;

	# for now, do nothing
	return $curTime;
}

sub printStats {

	my ( $csvFile, $reportFile, $doReport, $VMSUMMARYFILE, @vms ) = @_;
	my @values = ();
	my @returnValues = ();

	# Variable to be used when computing stats
	my $stat;

	# Get the average total CPU
	# Find the column number
	my $totalCPU;
	my $columnNum = 0;
	foreach my $column ( @{ $categoryToColumnList{"Physical Cpu"} } ) {
		if ( $headers[$column] =~ /.*Total.*\%.Util.Time/ ) {
			$columnNum = $column;
			last;
		}
	}
	$stat = Statistics::Descriptive::Full->new();
	$stat->add_data( @{ $dataColumns[$columnNum] } );
	$totalCPU = $stat->mean();

	print $csvFile "$totalCPU";
	push @values, $totalCPU;
	push @returnValues, $totalCPU;

	if ($doReport) {
		print $reportFile "--------------------------------------------------------------------\n";
		print $reportFile "Esxtop Report\nSummary Statistics\n";
		printf( $reportFile "Total average CPU utilization = %.2f\n", $totalCPU );
	}

	# memory Summary Stats
	my $kernelMBytes;
	my $nonkernelMBytes;
	my $freeMBytes;
	foreach my $column ( @{ $categoryToColumnList{"Memory"} } ) {
		if ( $headers[$column] =~ /[^n]Kernel.MBytes/ ) {
			$stat = Statistics::Descriptive::Full->new();
			$stat->add_data( @{ $dataColumns[$column] } );
			$kernelMBytes = $stat->mean();
		}
		if ( $headers[$column] =~ /NonKernel.MBytes/ ) {
			$stat = Statistics::Descriptive::Full->new();
			$stat->add_data( @{ $dataColumns[$column] } );
			$nonkernelMBytes = $stat->mean();
		}
		if ( $headers[$column] =~ /^Memory.Free.MBytes/ ) {
			$stat = Statistics::Descriptive::Full->new();
			$stat->add_data( @{ $dataColumns[$column] } );
			$freeMBytes = $stat->mean();
		}
	}
	print $csvFile ",$kernelMBytes";
	print $csvFile ",$nonkernelMBytes";
	print $csvFile ",$freeMBytes";
	push @values, $kernelMBytes;
	push @values, $nonkernelMBytes;
	push @values, $freeMBytes;

	push @returnValues, $kernelMBytes;
	push @returnValues, $nonkernelMBytes;
	push @returnValues, $freeMBytes;

	if ($doReport) {
		my $freePct = 100 * $freeMBytes /      ( $freeMBytes + $kernelMBytes + $nonkernelMBytes + 272 );
		my $ovhdPct = 100 * $nonkernelMBytes / ( $freeMBytes + $kernelMBytes + $nonkernelMBytes + 272 );
		printf( $reportFile "Average Kernel MBytes = %.2f\n",                              $kernelMBytes );
		printf( $reportFile "Average Non-Kernel MBytes = %.2f (%.1f percent)\n",           $nonkernelMBytes, $ovhdPct );
		printf( $reportFile "Average Free MBytes = %.2f (%.1f percent of total memory)\n", $freeMBytes, $freePct );
	}

	# vmhba Summary Stats
	foreach my $vmhba (@vmhbas) {
		my $column;
		my ( $rd_sec, $wr_sec, $rd_mb, $wr_mb, $gavg );
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Writes_sec"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $hbaToCategoryToColumnHash{$vmhba}->{"Writes_sec"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$wr_sec = $stat->mean();
			print $csvFile ",$wr_sec";
			push @values, $wr_sec;
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Written"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Written"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$wr_mb = $stat->mean();
			print $csvFile ",$wr_mb";
			push @values, $wr_mb;
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Reads_sec"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $hbaToCategoryToColumnHash{$vmhba}->{"Reads_sec"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$rd_sec = $stat->mean();
			print $csvFile ",$rd_sec";
			push @values, $rd_sec;
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Read"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Read"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$rd_mb = $stat->mean();
			print $csvFile ",$rd_mb";
			push @values, $rd_mb;
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Guest_Millisec"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Written"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$gavg = $stat->mean();
			print $csvFile ",$gavg";
			push @values, $gavg;
		}

		if ($doReport) {
			print $reportFile "$vmhba\n";
			printf( $reportFile "\tReads/sec = %.2f\tWrites/sec = %.2f\n",    $rd_sec, $wr_sec );
			printf( $reportFile "\tRead MB/sec = %.2f\tWrite MB/sec= %.2f\n", $rd_mb,  $wr_mb );
			printf( $reportFile "\tGuest ms/cmd= %.2f\n",                     $gavg );
		}

	}

	foreach my $vmnic (@vmnics) {
		my $column;
		my ( $rx_sec, $tx_sec, $rx_mb, $tx_mb ) = ( 0, 0, 0, 0 );
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"Transmitted_sec"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $nicToCategoryToColumnHash{$vmnic}->{"Transmitted_sec"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$tx_sec = $stat->mean();
			print $csvFile ",$tx_sec";
			push @values, $tx_sec;
					}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"Received_sec"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $nicToCategoryToColumnHash{$vmnic}->{"Received_sec"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$rx_sec = $stat->mean();
			print $csvFile ",$rx_sec";
			push @values, $rx_sec;
		}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"MBits_Transmitted"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $nicToCategoryToColumnHash{$vmnic}->{"MBits_Transmitted"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$tx_mb = $stat->mean();
			print $csvFile ",$tx_mb";
			push @values, $tx_mb;
		}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"MBits_Received"} ) {
			$stat   = Statistics::Descriptive::Full->new();
			$column = $nicToCategoryToColumnHash{$vmnic}->{"MBits_Received"};
			$stat->add_data( @{ $dataColumns[$column] } );
			$rx_mb = $stat->mean();
			print $csvFile ",$rx_mb";
			push @values, $rx_mb;
		}

		my $bytesPerTx = 0;
		my $bytesPerRx = 0;
		if ( $tx_sec > 0 ) { $bytesPerTx = ( $tx_mb * 1000000 / 8 ) / $tx_sec; }
		if ( $rx_sec > 0 ) { $bytesPerRx = ( $rx_mb * 1000000 / 8 ) / $rx_sec; }

		if ($doReport) {
			print $reportFile "$vmnic\n";
			printf( $reportFile "\tPackets Tx/sec = %.2f\tPackets Rx/sec = %.2f\n",                 $tx_sec,     $rx_sec );
			printf( $reportFile "\tMbps Tx = %.2f\tMbps Rx = %.2f\n",                               $tx_mb,      $rx_mb );
			printf( $reportFile "\tAvg Tx pckt size = %.2f Bytes\tAvg Rx pckt size = %.2f bytes\n", $bytesPerTx, $bytesPerRx );
		}

	}

	# Stats variables to track averages over all VMs
	my $pctUsed_stat    = Statistics::Descriptive::Full->new();
	my $pctSystem_stat  = Statistics::Descriptive::Full->new();
	my $pctWait_stat    = Statistics::Descriptive::Full->new();
	my $pctIdle_stat    = Statistics::Descriptive::Full->new();
	my $pctReady_stat   = Statistics::Descriptive::Full->new();
	my $pctActive_stat  = Statistics::Descriptive::Full->new();
	my $rd_sec_stat     = Statistics::Descriptive::Full->new();
	my $rd_MB_sec_stat  = Statistics::Descriptive::Full->new();
	my $wr_sec_stat     = Statistics::Descriptive::Full->new();
	my $wr_MB_sec_stat  = Statistics::Descriptive::Full->new();
	my $tx_sec_stat     = Statistics::Descriptive::Full->new();
	my $tx_Mbps_stat    = Statistics::Descriptive::Full->new();
	my $tx_dropped_stat = Statistics::Descriptive::Full->new();
	my $rx_sec_stat     = Statistics::Descriptive::Full->new();
	my $rx_Mbps_stat    = Statistics::Descriptive::Full->new();
	my $rx_dropped_stat = Statistics::Descriptive::Full->new();

	# Now get the stats for each VM
	# We get them even if not printing to get the overall averages
	foreach my $vmName (@vms) {

		# Find the category to column hash for the right vm
		my $categoryToColumnHashRef = $vmToColumnList{$vmName};

		# Get the various stats
		my $pctUsed   = "uninit";
		my $pctSystem = "uninit";
		my $pctWait   = "uninit";
		my $pctIdle   = "uninit";
		my $pctReady  = "uninit";
		foreach my $column ( @{ ${$categoryToColumnHashRef}{"Group Cpu"} } ) {
			if ( $headers[$column] =~ /.*Used.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctUsed = $stat->mean();
				$pctUsed_stat->add_data($pctUsed);
			}
			elsif ( $headers[$column] =~ /.*System.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctSystem = $stat->mean();
				$pctSystem_stat->add_data($pctSystem);
			}
			elsif ( $headers[$column] =~ /.*\%\_Wait.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctWait = $stat->mean();
				$pctWait_stat->add_data($pctWait);
			}
			elsif ( $headers[$column] =~ /.*Idle.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctIdle = $stat->mean();
				$pctIdle_stat->add_data($pctIdle);
			}
			elsif ( $headers[$column] =~ /.*Ready.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctReady = $stat->mean();
				$pctReady_stat->add_data($pctReady);
			}
		}

		my $pctActive = "uninit";
		foreach my $column ( @{ ${$categoryToColumnHashRef}{"Group Memory"} } ) {
			if ( $headers[$column] =~ /.*Active_Estimate.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$pctActive = $stat->mean();
				$pctActive_stat->add_data($pctActive);
			}
		}

		my $rd_sec    = "uninit";
		my $rd_MB_sec = "uninit";
		my $wr_sec    = "uninit";
		my $wr_MB_sec = "uninit";
		foreach my $column ( @{ ${$categoryToColumnHashRef}{"Virtual Disk"} } ) {
			if ( $headers[$column] =~ /.*Reads\/sec.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$rd_sec = $stat->mean();
				$rd_sec_stat->add_data($rd_sec);
			}
			elsif ( $headers[$column] =~ /.*Writes\/sec.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$wr_sec = $stat->mean();
				$wr_sec_stat->add_data($wr_sec);
			}
			elsif ( $headers[$column] =~ /.*MBytes_Read.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$rd_MB_sec = $stat->mean();
				$rd_MB_sec_stat->add_data($rd_MB_sec);
			}
			elsif ( $headers[$column] =~ /.*MBytes_Written.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$wr_MB_sec = $stat->mean();
				$wr_MB_sec_stat->add_data($wr_MB_sec);
			}
		}

		my $tx_sec     = "uninit";
		my $tx_Mbps    = "uninit";
		my $tx_dropped = "uninit";
		my $rx_sec     = "uninit";
		my $rx_Mbps    = "uninit";
		my $rx_dropped = "uninit";
		foreach my $column ( @{ ${$categoryToColumnHashRef}{"Network Port"} } ) {
			if ( $headers[$column] =~ /.*\)\_Packets_Transmitted.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$tx_sec = $stat->mean();
				$tx_sec_stat->add_data($tx_sec);
			}
			elsif ( $headers[$column] =~ /.*\)\_Packets_Received.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$rx_sec = $stat->mean();
				$rx_sec_stat->add_data($rx_sec);
			}
			elsif ( $headers[$column] =~ /.*\)\_MBits_Transmitted.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$tx_Mbps = $stat->mean();
				$tx_Mbps_stat->add_data($tx_Mbps);
			}
			elsif ( $headers[$column] =~ /.*\)\_MBits_Received.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$rx_Mbps = $stat->mean();
				$rx_Mbps_stat->add_data($rx_Mbps);
			}
			elsif ( $headers[$column] =~ /.*\)\_Outbound_Packets_Dropped.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$tx_dropped = $stat->mean();
				$tx_dropped_stat->add_data($tx_dropped);
			}
			elsif ( $headers[$column] =~ /.*\)\_Received_Packets_Dropped.*/ ) {
				$stat = Statistics::Descriptive::Full->new();
				$stat->add_data( @{ $dataColumns[$column] } );
				$rx_dropped = $stat->mean();
				$rx_dropped_stat->add_data($rx_dropped);
			}
		}

		my $realPctWait = $pctWait - $pctIdle;
		my $bytesPerTx  = ( $tx_sec > 0 ) ? ( $tx_Mbps * 1000000 / 8 ) / $tx_sec : 0;
		my $bytesPerRx  = ( $rx_sec > 0 ) ? ( $rx_Mbps * 1000000 / 8 ) / $rx_sec : 0;

		if ($vmStats) {

			if ($doReport) {
				print $reportFile "----------------\n";
				print $reportFile "Statistics for VM $vmName\n";
			}
			print $csvFile ", $pctUsed, $pctSystem, $realPctWait, $pctReady";
			print $csvFile ", $pctActive";
			print $csvFile ", $rd_sec, $wr_sec, $rd_MB_sec, $wr_MB_sec";
			print $csvFile ", $tx_sec, $tx_Mbps, $rx_sec, $rx_Mbps";

			print $VMSUMMARYFILE "$vmName";
			print $VMSUMMARYFILE ",$pctUsed,$pctSystem,$realPctWait,$pctReady";
			print $VMSUMMARYFILE ",$pctActive";
			print $VMSUMMARYFILE ",$rd_sec,$wr_sec,$rd_MB_sec,$wr_MB_sec";
			print $VMSUMMARYFILE ",$tx_sec,$tx_Mbps,$rx_sec,$rx_Mbps\n";

			push @values, ($pctUsed, $pctSystem, $realPctWait, $pctReady);
			push @values, $pctActive;
			push @values, ($rd_sec, $wr_sec, $rd_MB_sec, $wr_MB_sec);
			push @values, ($tx_sec, $tx_Mbps, $rx_sec, $rx_Mbps);

			push @returnValues, ($pctUsed, $pctSystem, $realPctWait, $pctReady);
			push @returnValues, $pctActive;
			push @returnValues, ($rd_sec, $wr_sec, $rd_MB_sec, $wr_MB_sec);
			push @returnValues, ($tx_sec, $tx_Mbps, $rx_sec, $rx_Mbps);

			if ($doReport) {
				printf( $reportFile "CPU Pct Used = %.2f,  \%System = %.2f, \%Wait = %.2f, \%Ready = %.2f\n",
					$pctUsed, $pctSystem, $realPctWait, $pctReady );
				printf( $reportFile "\Memory %Active = %.2f\n", $pctActive );
				print( $reportFile "Disk Stats:\n" );
				printf( $reportFile "\tReads/sec = %.2f\tWrites/sec = %.2f\n",    $rd_sec,    $wr_sec );
				printf( $reportFile "\tRead MB/sec = %.2f\tWrite MB/sec= %.2f\n", $rd_MB_sec, $wr_MB_sec );
				print( $reportFile "Network Stats:\n" );
				printf( $reportFile "\tPackets Tx/sec = %.2f\tPackets Rx/sec = %.2f\n", $tx_sec,  $rx_sec );
				printf( $reportFile "\tMbps Tx = %.2f\tMbps Rx = %.2f\n",               $tx_Mbps, $rx_Mbps );
				printf( $reportFile "\tAvg Tx pckt size = %.2f Bytes\tAvg Rx pckt size = %.2f bytes\n", $bytesPerTx,
					$bytesPerRx );
				printf( $reportFile "\tPct Tx pcks dropped = %.2f\%\tPct Rx pckts dropped = %.2f\%\n", $tx_dropped, $rx_dropped );
			}

		}
	}

	# Print the overall VM averages
	if ($doReport) {
		print $reportFile "----------------\n";
		print $reportFile "Average Per-VM Statistics:\n";
	}

	my $realPctWait = $pctWait_stat->mean() - $pctIdle_stat->mean();
	my $bytesPerTx  = ( $tx_sec_stat->mean() > 0 ) ? ( $tx_Mbps_stat->mean() * 1000000 / 8 ) / $tx_sec_stat->mean() : 0;
	my $bytesPerRx  = ( $rx_sec_stat->mean() > 0 ) ? ( $rx_Mbps_stat->mean() * 1000000 / 8 ) / $rx_sec_stat->mean() : 0;

	print $csvFile ", ", $pctUsed_stat->mean(), ", ", $pctSystem_stat->mean(), ", $realPctWait, ", $pctReady_stat->mean();
	print $csvFile ", ", $pctActive_stat->mean();
	print $csvFile ", ", $rd_sec_stat->mean(), ", ", $wr_sec_stat->mean(), ", ", $rd_MB_sec_stat->mean(), ", ", $wr_MB_sec_stat->mean();
	print $csvFile ", ", $tx_sec_stat->mean(), ", ", $tx_Mbps_stat->mean(), ", ", $rx_sec_stat->mean(), ", ", $rx_Mbps_stat->mean();
	
	push @values,  ($pctUsed_stat->mean(),  $pctSystem_stat->mean(), $realPctWait, $pctReady_stat->mean());
	push @values,  $pctActive_stat->mean();
	push @values,  ($rd_sec_stat->mean(),  $wr_sec_stat->mean(),  $rd_MB_sec_stat->mean(), $wr_MB_sec_stat->mean());
	push @values,  ($tx_sec_stat->mean(),  $tx_Mbps_stat->mean(),  $rx_sec_stat->mean(),  $rx_Mbps_stat->mean());

	if ($doReport) {
		printf( $reportFile "CPU Pct Used = %.2f,  \%System = %.2f, \%Wait = %.2f, \%Ready = %.2f\n",
			$pctUsed_stat->mean(), $pctSystem_stat->mean(), $realPctWait, $pctReady_stat->mean() );
		printf( $reportFile "\Memory %Active = %.2f\n", $pctActive_stat->mean() );
		print( $reportFile "Disk Stats:\n" );
		printf( $reportFile "\tReads/sec = %.2f\tWrites/sec = %.2f\n",    $rd_sec_stat->mean(),    $wr_sec_stat->mean() );
		printf( $reportFile "\tRead MB/sec = %.2f\tWrite MB/sec= %.2f\n", $rd_MB_sec_stat->mean(), $wr_MB_sec_stat->mean() );
		print( $reportFile "Network Stats:\n" );
		printf( $reportFile "\tPackets Tx/sec = %.2f\tPackets Rx/sec = %.2f\n", $tx_sec_stat->mean(), $rx_sec_stat->mean() );
		printf( $reportFile "\tMbps Tx = %.2f\tMbps Rx = %.2f\n", $tx_Mbps_stat->mean(), $rx_Mbps_stat->mean() );
		printf( $reportFile "\tAvg Tx pckt size = %.2f Bytes\tAvg Rx pckt size = %.2f bytes\n", $bytesPerTx, $bytesPerRx );
		printf( $reportFile "\tPct Tx pcks dropped = %.2f\%\tPct Rx pckts dropped = %.2f\%\n",
			$tx_dropped_stat->mean(),
			$rx_dropped_stat->mean()
		);
	}

	print( $csvFile "\n" );

	return @returnValues;
}

# Print the header for the csv file
sub printHeader {
	my ( $csvFile, $vmStats, $VMSUMMARYFILE, @vms ) = @_;

	my @headers = ();
	my @returnHeaders = ();
	# Headers for summary columns
	push @headers, "TotalCPU";
	push @headers, "Kernel MBytes";
	push @headers, "Non-Kernel MBytes";
	push @headers, "Free MBytes";

	push @returnHeaders, "TotalCPU";
	push @returnHeaders, "Kernel MBytes";
	push @returnHeaders, "Non-Kernel MBytes";
	push @returnHeaders, "Free MBytes";

	foreach my $vmhba (@vmhbas) {
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Writes_sec"} ) {
			push @headers, "$vmhba Writes/sec";
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Written"} ) {
			push @headers, "$vmhba MBytes Written/sec";
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Reads_sec"} ) {
			push @headers, "$vmhba Reads/sec";
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"MBytes_Read"} ) {
			push @headers, "$vmhba MBytes Read/sec";
		}
		if ( exists $hbaToCategoryToColumnHash{$vmhba}->{"Guest_Millisec"} ) {
			push @headers, "$vmhba GAVG";
		}
	}

	foreach my $vmnic (@vmnics) {
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"Transmitted_sec"} ) {
			push @headers, "$vmnic Pkts Tx/sec";
		}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"Received_sec"} ) {
			push @headers, "$vmnic Pkts Rx/sec";
		}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"MBits_Transmitted"} ) {
			push @headers, "$vmnic MBits Tx/sec";
		}
		if ( exists $nicToCategoryToColumnHash{$vmnic}->{"MBits_Received"} ) {
			push @headers, "$vmnic MBits Rx/sec";
		}
	}

	if ($vmStats) {

		# Headers for each VM with correct prefix
		foreach my $vm (@vms) {
			push @headers, ( "$vm CPU %Used", "$vm CPU %System", "$vm CPU %Wait", "$vm CPU %Ready" );
			push @headers, ("$vm Mem %Active");
			push @headers, ( "$vm Disk Rd/s", "$vm Disk Wr/s", "$vm Disk MB Rd/s", "$vm Disk MB Wr/s" );
			push @headers, ( "$vm Network Tx/s", "$vm Network Tx Mbps", "$vm Network Rx/s", "$vm Network Rx Mbps" );

			push @returnHeaders, ( "$vm CPU %Used", "$vm CPU %System", "$vm CPU %Wait", "$vm CPU %Ready" );
			push @returnHeaders, ("$vm Mem %Active");
			push @returnHeaders, ( "$vm Disk Rd/s", "$vm Disk Wr/s", "$vm Disk MB Rd/s", "$vm Disk MB Wr/s" );
			push @returnHeaders, ( "$vm Network Tx/s", "$vm Network Tx Mbps", "$vm Network Rx/s", "$vm Network Rx Mbps" );
		}
		
		print $VMSUMMARYFILE "VM Name";
		print $VMSUMMARYFILE ",CPU %Used, CPU %System, CPU %Wait, CPU %Ready";
		print $VMSUMMARYFILE ",Mem %Active";
		print $VMSUMMARYFILE ",Disk Rd/s, Disk Wr/s, Disk MB Rd/s, Disk MB Wr/s";
		print $VMSUMMARYFILE ",Network Tx/s, Network Tx Mbps, Network Rx/s, Network Rx Mbps\n";
		
	}

	# headers for average over all VMs
	push @headers, ( "VM Avg CPU %Used", "VM Avg CPU %System", "VM Avg CPU %Wait", "VM Avg CPU %Ready" );
	push @headers, ("VM Avg Mem %Active");
	push @headers, ( "VM Avg Disk Rd/s", "VM Avg Disk Wr/s", "VM Avg Disk MB Rd/s", "VM Avg Disk MB Wr/s" );
	push @headers, ( "VM Avg Network Tx/s", "VM Avg Network Tx Mbps", "VM Avg Network Rx/s", "VM Avg Network Rx Mbps" );

	for ( my $i = 0 ; $i <= $#headers ; $i++ ) {
		print $csvFile $headers[$i];
		if ( $i != $#headers ) {
			print $csvFile ", ";
		}
	}

	return @returnHeaders;
}

sub printCpuSummaryCsvs {

	my ( $csvFilePrefix ) = @_;

	# Find the column numbers for node CPU Totals 
	my $totalCPU;
	my @columnNums = (0);
	foreach my $column ( @{ $categoryToColumnList{"Physical Cpu"} } ) {
		if ( $headers[$column] =~ /.*Total.*\%/ ) {
			push @columnNums, $column;
		}
	}
			
	my $CSVFILE;
	open $CSVFILE, ">${csvFilePrefix}_hostCpu.csv" or die "Can't open ${csvFilePrefix}_hostCpu.csv: $!";
	# First print the headers (row 0)
	map( print( $CSVFILE $headers[$_], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
	print $CSVFILE $headers[ $columnNums[ $#columnNums ] ], "\n";    # No comma on last value

	for ( my $j = 1 ; $j < $numRows ; $j++ ) {
		map( print( $CSVFILE ${ $dataColumns[$_] }[$j], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
		print $CSVFILE ${ $dataColumns[ $columnNums[ $#columnNums ] ] }[$j], "\n";    # No comma on last value
	}
	close $CSVFILE;	
	
	# Column numbers for VM CPU %Used
	@columnNums = (0);
	foreach my $vmname (@vms) {
		push @columnNums, $vmToColumnList{$vmname}->{ "Group Cpu" }->[2];	
	}
	open $CSVFILE, ">${csvFilePrefix}_vmCpuUsed.csv" or die "Can't open ${csvFilePrefix}_vmCpuUsed.csv: $!";
	# First print the headers (row 0)
	map( print( $CSVFILE $headers[$_], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
	print $CSVFILE $headers[ $columnNums[ $#columnNums ] ], "\n";    # No comma on last value

	for ( my $j = 1 ; $j < $numRows ; $j++ ) {
		map( print( $CSVFILE ${ $dataColumns[$_] }[$j], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
		print $CSVFILE ${ $dataColumns[ $columnNums[ $#columnNums ] ] }[$j], "\n";    # No comma on last value
	}
	close $CSVFILE;	
	
	# Column numbers for VM CPU %Ready
	@columnNums = (0);
	foreach my $vmname (@vms) {
		push @columnNums, $vmToColumnList{$vmname}->{ "Group Cpu" }->[7];	
	}
	open $CSVFILE, ">${csvFilePrefix}_vmCpuReady.csv" or die "Can't open ${csvFilePrefix}_vmCpuReady.csv: $!";
	# First print the headers (row 0)
	map( print( $CSVFILE $headers[$_], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
	print $CSVFILE $headers[ $columnNums[ $#columnNums ] ], "\n";    # No comma on last value

	for ( my $j = 1 ; $j < $numRows ; $j++ ) {
		map( print( $CSVFILE ${ $dataColumns[$_] }[$j], "," ), @columnNums[ 0 .. $#columnNums - 1 ] );
		print $CSVFILE ${ $dataColumns[ $columnNums[ $#columnNums ] ] }[$j], "\n";    # No comma on last value
	}
	close $CSVFILE;	
	
}
1;

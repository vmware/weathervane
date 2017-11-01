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
package MysqlService;

use Moose;
use MooseX::Storage;
use Parameters qw(getParamValue);
use POSIX;
use Log::Log4perl qw(get_logger);

use Services::Service;

use namespace::autoclean;

with Storage( 'format' => 'JSON', 'io' => 'File' );

extends 'Service';

has '+name' => ( default => 'MySQL', );

has '+version' => ( default => '5.6.xxx', );

has '+description' => ( default => 'MySQL', );

override 'initialize' => sub {
	my ( $self ) = @_;
	
	super();
};

sub stop {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StopMySQL-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	my $logger = get_logger("Weathervane::Services::MysqlService");
	$logger->debug("stop MysqlService");

	my $dblog;
	open( $dblog, ">$logName" ) or die "Error opening $logName:$!";

	my $cmdOut;		
	if ( $self->isRunning($dblog) ) {
		print $dblog "DB is running.  Stopping DB\n";
		$cmdOut = `$sshConnectString service mysqld stop 2>&1`;
		if ( $self->isRunning($dblog) ) {
			print $dblog "Couldn't stop MySQL : $cmdOut\n";
			die "Couldn't stop MySQL : $cmdOut\n";
		}
	}

	close $dblog;
}

sub start {
	my ( $self, $logPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/StartMySQL-$hostname.log";
	my $sshConnectString = $self->host->sshConnectString;
	
	$self->portMap->{ $self->getImpl()  } = $self->internalPortMap->{ $self->getImpl()  };
	
	$self->registerPortsWithHost();

	my $dblog;
	open( $dblog, ">$logName" ) or die "Error opening $logName:$!";
	print $dblog "Starting DB\n";
	my $cmdOut = `$sshConnectString service mysqld start 2>&1`;
	if ( !$self->isRunning($dblog)) {
		print $dblog "Couldn't start MySQL : $cmdOut\n";
		die "Couldn't start MySQL : $cmdOut\n";
	}

	$self->host->startNscd();

	close $dblog;
}

sub clearDataBeforeStart {
}

sub clearDataAfterStart {
	my ( $self, $logPath ) = @_;
	my $hostname         = $self->host->hostName;
	my $logName          = "$logPath/MySQL-clearData-$hostname.log";
	my $dbScriptDir = $self->getParamValue('dbScriptDir');
	my $port = $self->portMap->{ $self->getImpl() };
	
	my $applog;
	open( $applog, ">$logName" ) or die "Error opening $logName:$!";
	print $applog "Clearing Data From Mysql\n";

	# Make sure the database exists
	my $cmdout = `mysql -u auction -pauction -h $hostname -P $port < $dbScriptDir/auction_mysql_database.sql 2>&1`;
	print $applog $cmdout;

	# Make sure the tables exist and are empty
	$cmdout = `mysql -u auction -pauction -h $hostname -P $port < $dbScriptDir/auction_mysql_tables.sql 2>&1`;
	print $applog $cmdout;

	# Add the foreign key constraints
	$cmdout = `mysql -u auction -pauction -h $hostname -P $port < $dbScriptDir/auction_mysql_constraints.sql 2>&1`;
	print $applog $cmdout;

	# Add the indices
	$cmdout = `mysql -u auction -pauction -h $hostname -P $port < $dbScriptDir/auction_mysql_indices.sql  2>&1`;
	print $applog $cmdout;
	close $applog;

}

sub isUp {
	my ( $self, $fileout ) = @_;
	
	if ( !$self->isRunning($fileout) ) {
		return 0;
	}
	
	return 1;
	
}

sub isRunning {
	my ( $self, $fileout ) = @_;

	my $sshConnectString = $self->host->sshConnectString;

	my $cmdOut = `$sshConnectString service mysqld status 2>&1`;
	if ($fileout) {
		print $fileout $cmdOut;
	}
	if (( $cmdOut =~ /SUCCESS/ )  || ($cmdOut =~ /\sactive\s+\(/)) {
		return 1;
	}
	else {
		return 0;
	}

}

sub setPortNumbers {
	my ( $self ) = @_;
	
	my $serviceType = $self->getParamValue('serviceType');
	my $impl = $self->getImpl() ;
	my $portMultiplier = $self->appInstance->getNextPortMultiplierByServiceType($serviceType);
	my $portOffset = $self->getParamValue($serviceType . 'PortStep') * $portMultiplier;
	$self->internalPortMap->{ $impl } = $self->getParamValue( 'mysqlPort' ) + $portOffset;
}

sub setExternalPortNumbers {
	my ( $self ) = @_;
	$self->portMap->{ $self->getImpl() } = $self->internalPortMap->{ $self->getImpl()  };
	
}

sub configure {
	my ( $self, $logPath, $users, $suffix ) = @_;
	my $server           = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	my $configDir        = $self->getParamValue('configDir');

	# Only configure if one of the relevant parameters is set
	if ( $self->getParamValue('mysqlInnodbBufferPoolSize') || $self->getParamValue('mysqlInnodbBufferPoolSizePct') 
		|| $self->getParamValue('mysqlMaxConnections') ) {

		open( FILEIN,  "$configDir/mysql/my.cnf" ) or die "Can't open file : $configDir/mysql/my.cnf: $!\n";
		open( FILEOUT, ">/tmp/my$suffix.cnf" )            or die "Can't open file : /tmp/my.cnf: $!\n";
		while ( my $inline = <FILEIN> ) {

			if ( $inline =~ /^\s*innodb_buffer_pool_size\s*=\s*(.*)/ ) {
				my $origValue = $1;

				# If mysqlInnodbBufferPoolSize was set, then use it
				# as the value. Otherwise, if mysqlInnodbBufferPoolSizePct
				# was set, use that percentage of total memory,
				# otherwise use what was in the original file
				if ( $self->getParamValue('mysqlInnodbBufferPoolSize') ) {

					#					print $self->meta->name
					#					  . " In MysqlService::configure setting innodb_buffer_pool_size to "
					#					  . $self->mysqlInnodbBufferPoolSize . "\n";
					print FILEOUT "innodb_buffer_pool_size = " . $self->getParamValue('mysqlInnodbBufferPoolSize') . "\n";

				}
				elsif ( $self->getParamValue('mysqlInnodbBufferPoolSizePct') ) {

					# Find the total amount of memory on the host
					my $out = `$sshConnectString cat /proc/meminfo`;
					$out =~ /MemTotal:\s+(\d+)\s+(\w)/;
					my $totalMem     = $1;
					my $totalMemUnit = $2;
					$totalMemUnit = uc($totalMemUnit);

					my $bufferMem = floor( $totalMem * $self->getParamValue('mysqlInnodbBufferPoolSizePct') );

					if ( $bufferMem > $totalMem ) {
						die "mysqlInnodbBufferPoolSizePct must be less than 1";
					}

				   #					print $self->meta->name
				   #					  . " In MysqlService::configure setting innodb_buffer_pool_size to $bufferMem$totalMemUnit\n";
					print FILEOUT "innodb_buffer_pool_size = $bufferMem$totalMemUnit\n";
					$self->setParamValue('mysqlInnodbBufferPoolSize', $bufferMem . $totalMemUnit );

				}
				else {
					print FILEOUT $inline;
					$self->setParamValue('mysqlInnodbBufferPoolSize', $origValue);
				}
			}
			elsif ( $inline =~ /^\s*port\s*=\s*(\d+)/ ) {
				print FILEOUT "port = " . $self->internalPortMap->{ $self->getImpl() } . "\n";
			}
			elsif ( $inline =~ /^\s*max_connections\s*=\s*(\d+)/ ) {
				my $origValue = $1;
				if ( $self->getParamValue("mysqlMaxConnections") ) {
					print FILEOUT "max_connections = " . $self->getParamValue('mysqlMaxConnections') . "\n";

				}
				else {
					print FILEOUT $inline;
					$self->setParamValue('mysqlMaxConnections',$origValue);
				}
			}
			else {
				print FILEOUT $inline;
			}

		}
		close FILEIN;
		close FILEOUT;

		`$scpConnectString /tmp/my$suffix.cnf root\@$scpHostString:/etc/my.cnf`;

	}

}

sub stopStatsCollection {
	my ($self)           = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	# Get MYSQL status
	open( LOG, ">/tmp/mysqlStats_${hostname}_end.txt" )
	  || die "Error opening /tmp/mysqlStats_${hostname}_end.txt.log:$!";
	my $mysqlStats = `$sshConnectString \"mysql -u auction -pauction -e \'show engine innodb status;\' 2>&1\"`;
	$mysqlStats =~ s/\\n/\n/g;
	print LOG $mysqlStats;
	$mysqlStats = `$sshConnectString \"mysql -u auction -pauction -e \'show engine innodb mutex;\' 2>&1\"`;
	$mysqlStats =~ s/\\n/\n/g;
	print LOG $mysqlStats;
	close LOG;

}

sub startStatsCollection {
	my ( $self, $intervalLengthSec, $numIntervals ) = @_;
	my $hostname         = $self->host->hostName;
	my $sshConnectString = $self->host->sshConnectString;

	my $totalTime = $numIntervals * $intervalLengthSec;
	$intervalLengthSec = $self->getParamValue('mysqlStatsInterval');
	$numIntervals      = floor( $totalTime / $intervalLengthSec );

	# Clear MySQL status
	`$sshConnectString mysqladmin -u auction -pauction flush-status  2>&1`;

	# Get MYSQL status
	open( LOG, ">/tmp/mysqlStats_${hostname}_start.txt" )
	  || die "Error opening /tmp/mysqlStats_${hostname}_start.txt.log:$!";
	my $mysqlStats = `$sshConnectString \"mysql -u auction -pauction -e \'show engine innodb status;\' 2>&1\"`;
	$mysqlStats =~ s/\\n/\n/g;
	print LOG $mysqlStats;
	$mysqlStats = `$sshConnectString \"mysql -u auction -pauction -e \'show engine innodb mutex;\' 2>&1\"`;
	$mysqlStats =~ s/\\n/\n/g;
	print LOG $mysqlStats;
	close LOG;

	# start collecting MySQL extended status
	my $pid = fork();

	if ( $pid == 0 ) {
		my $cmdOut;
		$cmdOut =
`mysqladmin -h $hostname -u auction -pauction --sleep=$intervalLengthSec --count=$numIntervals --relative extended-status  2>&1 >> /tmp/mysql_extended-status-$hostname.txt `;
		exit;
	}

}

sub getStatsFiles {
	my ( $self, $destinationPath ) = @_;
	my $hostname = $self->host->hostName;

	my $out = `cp /tmp/mysqlStats_${hostname}_start.txt $destinationPath/.`;
	$out = `cp /tmp/mysqlStats_${hostname}_end.txt $destinationPath/.`;
	$out = `cp /tmp/mysql_extended-status-$hostname.txt $destinationPath/.`;

}

sub cleanStatsFiles {
	my ($self) = @_;

	my $hostname = $self->host->hostName;

	my $out = `rm /tmp/mysqlStats_$(hostname}_start.txt  2>&1`;
	$out = `rm /tmp/mysql_extended-status_$hostname.txt  2>&1`;

}

sub getLogFiles {
	my ( $self, $destinationPath ) = @_;

	my $hostname         = $self->host->hostName;
	my $dataDir          = $self->getParamValue('mysqlDataDir');
	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;

	my $out = `$scpConnectString root\@$scpHostString:$dataDir/*.err $destinationPath/. 2>&1`;
	$out = `$scpConnectString root\@$scpHostString:$dataDir/*.log $destinationPath/. 2>&1`;
	$out = `$scpConnectString root\@$scpHostString:$dataDir/*.err $destinationPath/. 2>&1`;

}

sub cleanLogFiles {
	my ($self) = @_;

	my $hostname         = $self->host->hostName;
	my $dataDir          = $self->getParamValue('mysqlDataDir');
	my $sshConnectString = $self->host->sshConnectString;

	my $out = `$sshConnectString \"rm -f $dataDir/*.err  2>&1\"`;
	$out = `$sshConnectString \"rm -f $dataDir/*.log 2>&1\"`;
	$out = `$sshConnectString \"rm -f $dataDir/*.err 2>&1\"`;

}

#------------------------------
# Parse the MySQL extended status output
#
#------------------------------
#sub parseMysqlExtendedStatus {
#
#	my ($seqnum) = @_;
#
#	my (
#		$commit,      $delete,              $insert,             $rollback,  $select,
#		$setOption,   $update,              $maxUsedConnections, $questions, $qcacheHits,
#		$slowQueries, $tableLocksImmediate, $tableLocksWaited
#	  )
#	  = ( 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 );
#
#	my $peakConnectionsUsed = 0;
#
#	open( RESULTFILE, "$outputDir/$seqnum/mysql_extended-status.txt" );
#
#	my $reportNum = 0;
#	while ( my $inline = <RESULTFILE> ) {
#
#		# This marks the start of each report
#		if ( $inline =~ /Variable_name/ ) {
#			$reportNum++;
#		}
#
#		if ( $reportNum > 1 ) {
#
#			# The first report includes everything since the server was started.
#			# Most of the results in the first report should therefore be ignored, but
#			# some of them are needed as baselines for variables whose values is relative to
#			# the first value.
#			if ( $inline =~ /Com_commit.*\|\s+(\d+)\s/ ) {
#				$commit += $1;
#			}
#			if ( $inline =~ /Com_delete.*\|\s+(\d+)\s/ ) {
#				$delete += $1;
#			}
#			if ( $inline =~ /Com_insert.*\|\s+(\d+)\s/ ) {
#				$insert += $1;
#			}
#			if ( $inline =~ /Com_rollback.*\|\s+(\d+)\s/ ) {
#				$rollback += $1;
#			}
#			if ( $inline =~ /Com_select.*\|\s+(\d+)\s/ ) {
#				$select += $1;
#			}
#			if ( $inline =~ /Com_set_option.*\|\s+(\d+)\s/ ) {
#				$setOption += $1;
#			}
#			if ( $inline =~ /Com_update.*\|\s+(\d+)\s/ ) {
#				$update += $1;
#			}
#			if ( $inline =~ /Qcache_hits.*\|\s+(\d+)\s/ ) {
#				$qcacheHits += $1;
#			}
#			if ( $inline =~ /Questions.*\|\s+(\d+)\s/ ) {
#				$questions += $1;
#			}
#			if ( $inline =~ /Slow_queries.*\|\s+(\d+)\s/ ) {
#				$slowQueries += $1;
#			}
#			if ( $inline =~ /Table_locks_immediate.*\|\s+(\d+)\s/ ) {
#				$tableLocksImmediate += $1;
#			}
#			if ( $inline =~ /Table_locks_waited.*\|\s+(\d+)\s/ ) {
#				$tableLocksWaited += $1;
#			}
#		}
#
#		if ( $inline =~ /Max_used_connections.*\|\s+(\d+)\s/ ) {
#			$maxUsedConnections += $1;
#			if ( $maxUsedConnections > $peakConnectionsUsed ) {
#
#				# maxUsedConnections can go up and down.  We want the peak.
#				$peakConnectionsUsed = $maxUsedConnections;
#			}
#		}
#
#	}
#
#	close RESULTFILE;
#
#	# Turn these into results per second (except for maxConnectionsUsed)
#	my @results = (
#		$commit,     $delete,      $insert,              $rollback,
#		$select,     $setOption,   $update,              $questions,
#		$qcacheHits, $slowQueries, $tableLocksImmediate, $tableLocksWaited
#	);
#	(
#		$commit,     $delete,      $insert,              $rollback,
#		$select,     $setOption,   $update,              $questions,
#		$qcacheHits, $slowQueries, $tableLocksImmediate, $tableLocksWaited
#	  )
#	  = map( $_ / ( $mysqlStatsInterval * ( $reportNum - 1 ) ), @results );
#
#	return [
#		$commit,      $delete,              $insert,              $rollback,  $select,
#		$setOption,   $update,              $peakConnectionsUsed, $questions, $qcacheHits,
#		$slowQueries, $tableLocksImmediate, $tableLocksWaited
#	];
#
#}

sub parseLogFiles {
	my ( $self, $host, $configPath ) = @_;

}

sub getConfigFiles {
	my ( $self, $destinationPath ) = @_;

	my $scpConnectString = $self->host->scpConnectString;
	my $scpHostString    = $self->host->scpHostString;
	`mkdir -p $destinationPath`;

	my $out = `$scpConnectString root\@$scpHostString:/etc/my.cnf $destinationPath/.`;

}

sub getConfigSummary {
	my ( $self ) = @_;
	tie( my %csv, 'Tie::IxHash' );
	$csv{"mysqlInnodbBufferPoolSize"} = $self->getParamValue('mysqlInnodbBufferPoolSize');
	$csv{"mysqlMaxConnections"}       = $self->getParamValue('mysqlMaxConnections');

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
	
	my $hostname = $self->host->hostName;
	my $impl = $self->getImpl() ;
	my $port             = $self->portMap->{$impl};
	my $maxUsers = `MYSQL_PWD=auction mysql -u auction --host=$hostname --port=$port -s -N --database=auction -e "select maxusers from dbbenchmarkinfo;"`;
	$maxUsers += 0;
	
	return $maxUsers;
}

__PACKAGE__->meta->make_immutable;

1;

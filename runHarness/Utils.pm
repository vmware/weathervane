# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
package Utils;

use Log::Log4perl qw(get_logger :levels);
use strict;

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA = qw( Exporter);
	@EXPORT_OK =
	  qw( createDebugLogger callMethodOnObjectsParallel callMethodsOnObjectParallel
	  callMethodsOnObjectParallel1 callMethodsOnObject1 callMethodOnObjects1 callMethodOnObjects2 callBooleanMethodOnObjects2 
	  callBooleanMethodOnObjectsParallel callBooleanMethodOnObjectsParallel1 callBooleanMethodOnObjectsParallel2 
	  callBooleanMethodOnObjectsParallel3 callBooleanMethodOnObjectsParallel3BatchDelay
	  callMethodOnObjectsParallel1 callMethodOnObjectsParallel2 callMethodOnObjectsParallel3
	  callMethodOnObjectsParamListParallel1 runCmd callBooleanMethodOnObjectsParallel2BatchDelay);
}

sub createDebugLogger {
	my ( $dir, $loggerName ) = @_;

	my $logger = get_logger($loggerName);
	$logger->level($DEBUG);
	my $layout   = Log::Log4perl::Layout::PatternLayout->new("%d %p> %F{1}:%L %M - %m%n");
	my $appender = Log::Log4perl::Appender->new(
		"Log::Dispatch::File",
		name     => "rootConsoleFile",
		filename => "$dir/${loggerName}.log",
		mode     => "append",
	);
	$appender->layout($layout);
	$logger->add_appender($appender);
}

sub callMethodOnObjectsParamListParallel1 {
	my ( $method, $objectsRef, $paramListRef, $param1 ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Util");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		foreach my $param (@$paramListRef) {
			$pid = fork();
			if ( !defined $pid ) {
				$console_logger->error("Couldn't fork a process: $!");
				exit(-1);
			}
			elsif ( $pid == 0 ) {
				
				$logger->debug("callMethodOnObjectsParamListParallel1 calling method $method with params ($param, $param1)");
				$object->$method($param, $param1);
				exit;
			}
			else {
				push @pids, $pid;
			}
		}
		
		foreach $pid (@pids) {
			waitpid $pid, 0;
		}
	}
}


sub callMethodOnObjectsParallel {
	my ( $method, $objectsRef ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$object->$method();
			exit;
		}
		else {
			push @pids, $pid;
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub callMethodOnObjectsParallel1 {
	my ( $method, $objectsRef, $param1 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$object->$method($param1);
			exit;
		}
		else {
			push @pids, $pid;
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub callMethodOnObjectsParallel2 {
	my ( $method, $objectsRef, $param1, $param2 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$object->$method( $param1, $param2 );
			exit;
		}
		else {
			push @pids, $pid;
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub callMethodOnObjectsParallel3 {
	my ( $method, $objectsRef, $param1, $param2, $param3 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$object->$method( $param1, $param2, $param3 );
			exit;
		}
		else {
			push @pids, $pid;
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub callBooleanMethodOnObjectsParallel {
	my ( $method, $objectsRef ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method() );
		}
		else {
			push @pids, $pid;
		}
	}
	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callBooleanMethodOnObjectsParallel1 {
	my ( $method, $objectsRef, $param1 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method($param1) );
		}
		else {
			push @pids, $pid;
		}
	}

	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callBooleanMethodOnObjectsParallel2 {
	my ( $method, $objectsRef, $param1, $param2 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method( $param1, $param2 ) );
		}
		else {
			push @pids, $pid;
		}
	}

	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callBooleanMethodOnObjectsParallel2BatchDelay {
	my ( $method, $objectsRef, $param1, $param2, $batchSize, $delaySec ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Util");
	my @pids;
	my $pid;
	my $objectNum = 0;

	foreach my $object (@$objectsRef) {
		if ($objectNum == $batchSize) {
			$logger->debug("Pausing for $delaySec to allow services to start.\n";)
			sleep($delaySec);
			$objectNum = 0;
		}
		$objectNum++;
		
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method( $param1, $param2 ) );
		}
		else {
			push @pids, $pid;
		}
	}

	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callBooleanMethodOnObjectsParallel3 {
	my ( $method, $objectsRef, $param1, $param2, $param3 ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $object (@$objectsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method( $param1, $param2, $param3 ) );
		}
		else {
			push @pids, $pid;
		}
	}

	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callBooleanMethodOnObjectsParallel3BatchDelay {
	my ( $method, $objectsRef, $param1, $param2, $param3, $batchSize, $delaySec ) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Util");
	my @pids;
	my $pid;
	my $objectNum = 0;

	foreach my $object (@$objectsRef) {
		if ($objectNum == $batchSize) {
			$logger->debug("Pausing for $delaySec to allow services to start.\n";)
			sleep($delaySec);
			$objectNum = 0;
		}
		$objectNum++;

		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			exit( $object->$method( $param1, $param2, $param3 ) );
		}
		else {
			push @pids, $pid;
		}
	}

	my $retval = 1;
	foreach $pid (@pids) {
		waitpid $pid, 0;
		if ( !$? ) {
			$retval = 0;
		}
	}
	return $retval;
}

sub callMethodsOnObjectParallel {
	my ( $methodsRef, $object ) = @_;
	my $console_logger = get_logger("Console");
	my @pids;
	my $pid;

	foreach my $method (@$methodsRef) {
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$object->$method();
			exit;
		}
		else {
			push @pids, $pid;
		}
	}
	foreach $pid (@pids) {
		waitpid $pid, 0;
	}
}

sub callMethodsOnObjectParallel1 {
	my ( $methodsRef, $object, $param1 ) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Util");
	my @pids;
	my $pid;

	foreach my $method (@$methodsRef) {
		$logger->debug("Trying to fork for method $method");
		$pid = fork();
		if ( !defined $pid ) {
			$console_logger->error("Couldn't fork a process: $!");
			exit(-1);
		}
		elsif ( $pid == 0 ) {
			$logger->debug("Calling $method");
			$object->$method($param1);
			exit;
		}
		else {
			$logger->debug("Got pid $pid for method $method");
			push @pids, $pid;
		}
	}
	
	foreach $pid (@pids) {
		waitpid $pid, 0;
		$logger->debug("Finished waitpid for pid $pid");
	}
}
sub callMethodsOnObject1 {
	my ( $methodsRef, $object, $param1 ) = @_;
	my $console_logger = get_logger("Console");
	my $logger = get_logger("Weathervane::Util");

	foreach my $method (@$methodsRef) {
		$object->$method($param1);
	}
}

sub callMethodOnObjects1 {
	my ( $method, $objectsRef, $param1 ) = @_;
	my $console_logger = get_logger("Console");

	foreach my $object (@$objectsRef) {
			$object->$method($param1);
	}
}

sub callMethodOnObjects2 {
	my ( $method, $objectsRef, $param1, $param2 ) = @_;
	my $console_logger = get_logger("Console");

	foreach my $object (@$objectsRef) {
			$object->$method($param1, $param2);
	}
}

sub callBooleanMethodOnObjects2 {
	my ( $method, $objectsRef, $param1, $param2 ) = @_;
	my $console_logger = get_logger("Console");

	my $retval = 1;
	foreach my $object (@$objectsRef) {
			$retval &= $object->$method($param1, $param2);
	}
	return $retval;
}

sub runCmd {
	#returns two values (cmdFailed, cmdOutput)
	# cmdFailed ("" if success, $logOutput(cmd $output and not "") if failed)
	# cmdOutput (cmd $output if success, cmd $output if failed)

	my ($cmd, $printLogOutput) = @_;
	my $logger;
	if (Log::Log4perl->initialized()) {
		$logger = get_logger("Weathervane");
	}

	if (!(defined $printLogOutput)) {
		$printLogOutput = 1;
	}

	# Do some sanity/safety checks before running commands.
	#check for unexpanded variable
	if ( $cmd =~ /\$/ ) {
		#add some special case exceptions
		if ( $cmd =~ /mongo\s+\-\-eval.*\{\s*\$/ ) {
			#mong eval
		} elsif ( $cmd =~ /\"\$\(echo/ ) {
			#kubernetes zookeeper ruok check
		} else {
			die "runCmd error, command possibly contains unexpanded variable: $cmd";
		}
	}
	#check for unexpected paths off /
	if ( $cmd =~ / \// ) {
		#add some special case exceptions
		if ( $cmd =~ / \/tmp\// || $cmd =~ /\/weathervane/ ) {
		} elsif ( $cmd =~ /docker exec \w+ perl \// ) {
		} elsif ( $cmd =~ /docker exec \w+ \/\w+\.sh/ ) {
		} elsif ( $cmd =~ /kubectl exec .* \-\- perl \// ) {
		} elsif ( $cmd =~ /kubectl exec .* \-\- \// ) {
		} elsif ( $cmd =~ /-o \/dev\/null/ ) {
		} else {
			die "runCmd error, command references /: $cmd";
		}
	}

	my $output = `$cmd 2>&1`;
	my $exitStatus = $?;
	my $failed = $exitStatus >> 8;
	my $logOutput = $output;
	if ($failed) {
		if (!(length $output)) {
			$logOutput = "(failure with no output)";
		}
		if ($logger) { $logger->debug("runCmd Failure ($cmd): $logOutput"); }
		return ($logOutput, $output);
	} else {
		if (!(length $output)) {
			$logOutput = "(no output)";
		}
		if (!$printLogOutput) {
			$logOutput = "";
		}
		if ($logger) { $logger->debug("runCmd Success ($cmd): $logOutput"); }
		return ("", $output);
	}
}

1;

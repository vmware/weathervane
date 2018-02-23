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
package Utils;

use Log::Log4perl qw(get_logger :levels);
use strict;

BEGIN {
	use Exporter;
	use vars qw (@ISA @EXPORT_OK);
	@ISA = qw( Exporter);
	@EXPORT_OK =
	  qw( createDebugLogger getIpAddresses getIpAddress callMethodOnObjectsParallel callMethodsOnObjectParallel
	  callMethodsOnObjectParallel1 callMethodsOnObject1 callMethodOnObjects1
	  callBooleanMethodOnObjectsParallel callBooleanMethodOnObjectsParallel1 callBooleanMethodOnObjectsParallel2 
	  callBooleanMethodOnObjectsParallel3
	  callMethodOnObjectsParallel1 callMethodOnObjectsParallel2 callMethodOnObjectsParallel3
	  callMethodOnObjectsParamListParallel1);
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

sub getIpAddresses {
	my ($hostName) = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Util");

	my $hostResult = `getent ahostsv4 $hostName`;
	$logger->debug("getIpAddresses: hostResult for host $hostName is $hostResult");
	if ( !( $hostResult =~ /^(\d+\.\d+\.\d+\.\d+)\s+STREAM/ ) ) {
		$console_logger->error("getIpAddresses: IP Address cannot be found for $hostName");
		exit(-1);
	}

	my @ipAddresses = ();
	my @hostResults = split /\n/, $hostResult;
	foreach my $host (@hostResults) {
		$logger->debug("getIpAddresses: host line = " . $host);
		if ( $host =~ /^(\d+\.\d+\.\d+\.\d+)\s+STREAM/ ) {
			$logger->debug("getIpAddresses: found ip address " . $1);
			push @ipAddresses, $1;
		}
	}
	return \@ipAddresses;
}

sub getIpAddress {
	my ($hostName)     = @_;
	my $console_logger = get_logger("Console");
	my $logger         = get_logger("Weathervane::Util");

	$logger->debug("getIpAddress: Getting IP address for host $hostName");

	my $hostResult = `getent ahostsv4 $hostName`;
	$logger->debug("getIpAddress: hostResult for host $hostName is $hostResult");
	if ( !( $hostResult =~ /^(\d+\.\d+\.\d+\.\d+)\s+STREAM/ ) ) {
		$console_logger->error("IP Address cannot be found for $hostName");
		exit(-1);
	}

	return $1;
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

1;

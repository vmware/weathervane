#!/usr/bin/perl
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

use strict;
use POSIX;

my $clientPort   = $ENV{'ZK_CLIENT_PORT'};
my $id           = $ENV{'ZK_ID'};
my $servers ;

print "configure zookeeper. \n";
if ((exists $ENV{'ZK_SERVERS'}) && (defined $ENV{'ZK_SERVERS'})) {
	$servers = $ENV{'ZK_SERVERS'};
} else {
	# Get the zookeeper servers info from the zookeeperServers.txt file
	open( FILEIN, "/zookeeperServers.txt" )
	  or die "Can't open file /zookeeperServers.txt: $!";
	$servers = <FILEIN>;
	close FILEIN;
}
print "servers = $servers\n";
my @servers      = split /,/, $servers;

if (!$id) {
	my $hostname = `hostname`;
	my @parts = split /-/, $hostname;
	$id = $parts[1] + 1; 
}

open( FILEIN, "/root/zookeeper/conf/zoo.cfg" )
  or die "Can't open file /root/zookeeper/conf/zoo.cfg: $!";
open( FILEOUT, ">/opt/zookeeper/conf/zoo.cfg" )
  or die "Can't open file /opt/zookeeper/conf/zoo.cfg: $!";
while ( my $inline = <FILEIN> ) {

	if ( $inline =~ /^\s*clientPort=/ ) {
		print FILEOUT "clientPort=" . $clientPort . "\n";
	}
	else {
		print FILEOUT $inline;
	}

}

if ( $#servers > 0 ) {

	# Add server info for a replicated config
	print FILEOUT "initLimit=5\n";
	print FILEOUT "syncLimit=2\n";

	foreach my $zookeeperServer (@servers) {
		print FILEOUT "$zookeeperServer\n";
	}

	open( MYIDFILE, ">/mnt/zookeeper/myid" )
	  or die "Can't open file /mnt/zookeeper/myid: $!";
	print MYIDFILE "$id\n";
	close MYIDFILE;

}

close FILEIN;
close FILEOUT;

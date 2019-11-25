#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;
use POSIX;

my $ip = `hostname -i`;
chomp($ip);
open my $cmd, '-|', 'nodetool status';
while (my $line = <$cmd>) {
	print "isUp: nodetool status line: $line\n";
	if ($line =~ /^UN\s+$ip/) {
		open my $cmd2, '-|', "cqlsh $ip -f cqlsh.in";
		while (my $line2 = <$cmd2>) {
			print "isUp: describe keyspaces line: $line2\n";
			if ($line2 =~ /system_schema/) {
				close $cmd;
				close $cmd2;
				print "isUp: node is up\n";
				exit 0;
			}
		}
		close $cmd2;
	}
}
close $cmd;
print "isUp: node did not come up\n";
exit 1;

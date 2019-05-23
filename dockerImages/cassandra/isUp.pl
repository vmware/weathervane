#!/usr/bin/perl

use strict;
use POSIX;

my $ip = `hostname -i`;
chomp($ip);

open my $cmd, '-|', 'nodetool status';
while (my $line = <$cmd>) {
	if ($line =~ /^UN\s+$ip/) {
		sleep 10;
		open my $cmd2, '-|', 'nodetool status';
		while (my $line2 = <$cmd2>) {
			if ($line2 =~ /^UN\s+$ip/) {
				close $cmd;
				close $cmd2;
				exit 0;
			}
		}
		close $cmd2;
	}
}
close $cmd;
exit 1;

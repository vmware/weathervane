#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;

open my $cmd, '-|', 'rabbitmqctl list_vhosts';
while (my $line = <$cmd>) {
	if ($line =~ /^Listing\svhosts/) {
		$line = <$cmd>;
		if ($line =~ /^name/) {
			$line = <$cmd>;
			if ($line =~ /^\//) {
				close $cmd;
				exit 0;
			} 
		}
	}
	
}
close $cmd;
exit 1;

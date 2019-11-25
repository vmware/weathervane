#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
# This script is used to add the weathervane domain to
# The search line of /etc/resolv.conf
open( FILEIN, "/etc/resolv.conf" )
  or die "Can't open file /etc/resolv.conf: $!";

my $foundSearch = 0;
my $searchLine ;
while ( my $inline = <FILEIN> ) {
	if ( $inline =~ /^search/ ) {
		chomp($inline);
		$searchLine = $inline;
		$foundSearch = 1;
	}
}

if (!$foundSearch) {
	`echo  "search weathervane\n" >> /etc/resolv.conf`;
} else {
	`echo  "$searchLine weathervane\n" >> /etc/resolv.conf`;
}



 
#!/usr/bin/perl

use strict;
use POSIX;

my $ip = `hostname -i`;

my $status = `nodetool status | grep $ip`;
if ($status =~ /UN/) {
	exit 0;
} else {
	exit 1;
}
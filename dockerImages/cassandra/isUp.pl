#!/usr/bin/perl

use strict;
use POSIX;

my $hostname = `hostname`;
my $host = `host ${hostname}.cassandra`;
$host =~ /^address\s(.*)$/;
my $ip = $1;

my $status = `nodetool status | grep $ip`;
if ($status =~ /UN/) {
	exit 0;
} else {
	exit 1;
}
#!/usr/bin/perl

use strict;
use POSIX;

my $hostname = `hostname`;
chomp($hostname);

my $host = `host ${hostname}.cassandra`;
chomp($host);
$host =~ /address\s(\d+\.\d+\.\d+\.\d+).*$/;
my $ip = $1;

my $status = `nodetool status | grep $ip`;
if ($status =~ /UN/) {
	exit 0;
} else {
	exit 1;
}
#!/usr/bin/perl

use strict;
my $cmdout = `df -h /mnt/mongoData`;
if ($cmdout =~ /100\%/) {
	exit 1;
} else {
    exit 0;
}

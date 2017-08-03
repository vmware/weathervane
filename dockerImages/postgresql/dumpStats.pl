#!/usr/bin/perl

use strict;

my $port    = $ENV{'POSTGRESPORT'};

# Get interesting views on the pg_stats table
my $out = `psql -p $port -U auction --command='select * from pg_stat_activity;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_stat_bgwriter;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_stat_database;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_stat_database_conflicts;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_stat_user_tables;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_statio_user_tables;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_stat_user_indexes;'`;
print $out;
$out = `psql -p $port -U auction --command='select * from pg_statio_user_indexes;'`;
print $out;

# Reset the stats tables
$out = `psql -p $port -U auction --command='select pg_stat_reset();'`;
print $out;
$out = `psql -p $port -U auction --command="select pg_stat_reset_shared('bgwriter');"`;
print $out;


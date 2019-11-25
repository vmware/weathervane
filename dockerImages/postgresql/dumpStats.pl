#!/usr/bin/perl
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

use strict;

my $port    = $ENV{'POSTGRESPORT'};
my $pgMajor = $ENV{'PG_MAJOR'};

# Get interesting views on the pg_stats table
my $out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_activity;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_bgwriter;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_database;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_database_conflicts;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_user_tables;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_statio_user_tables;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_stat_user_indexes;'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select * from pg_statio_user_indexes;'`;
print $out;

# Reset the stats tables
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command='select pg_stat_reset();'`;
print $out;
$out = `sudo -u postgres /usr/pgsql-${pgMajor}/bin/psql -p $port -U auction --command="select pg_stat_reset_shared('bgwriter');"`;
print $out;


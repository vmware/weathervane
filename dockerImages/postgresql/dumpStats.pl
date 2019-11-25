#!/usr/bin/perl
# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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


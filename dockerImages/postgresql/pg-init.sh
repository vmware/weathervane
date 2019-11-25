#!/bin/bash
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
set -e

rm -rf /tmp/isReady

if [ ! -s "/mnt/dbData/postgresql/PG_VERSION" ]; then
  MODE="firstrun"
else
  MODE="alreadyinitialized"
fi

if [ "$MODE" == 'firstrun' ]; then
  # Make postgres own PGDATA
  mkdir -p /mnt/dbData/postgresql
  mkdir -p /mnt/dbLogs/postgresql
  chown -R postgres:postgres /mnt/dbData/postgresql
  chown -R postgres:postgres /mnt/dbLogs/postgresql
  rm -rf /mnt/dbData/postgresql/*

  # Setup postgres
  echo "Initialize postgres" >&2
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/initdb -D /mnt/dbData/postgresql

  cp /pg_hba.conf /mnt/dbData/postgresql/.

  # Start postgresql
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/pg_ctl -D /mnt/dbData/postgresql -w start

  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create role auction with superuser createdb login password 'auction;'"
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create role root with superuser createdb login password 'auction;'"
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create database auction owner auction;"
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create database root owner root;"

  # Create the database and tables
  . /clearAfterStart.sh
  
  # Stop postgresql
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/pg_ctl -D /mnt/dbData/postgresql -m fast -w stop

  # put data and logs in the places that Weathervane expects
  mv /mnt/dbData/postgresql/pg_xlog/* /mnt/dbLogs/postgresql/.
  rmdir /mnt/dbData/postgresql/pg_xlog
  ln -s /mnt/dbLogs/postgresql /mnt/dbData/postgresql/pg_xlog

fi

# Cleanup
chown -R postgres:postgres /mnt/dbData
chown -R postgres:postgres /mnt/dbLogs
chmod 700 /mnt/dbData/postgresql
rm -f /mnt/dbData/serverlog
rm -f /mnt/dbData/pg_log/*
rm -f /mnt/dbData/postgresql/postmaster.pid
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/pg_resetxlog -f /mnt/dbData/postgresql

echo "Configure postgresql.conf"
perl /configure.pl	

# Start postgresql
echo "Starting PostgreSQL"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/pg_ctl start -D /mnt/dbData/postgresql 

while /usr/pgsql-9.3/bin/pg_isready -h 127.0.0.1 -p 5432 ; [ $? -ne 0 ]; do
    echo "Waiting for PostgreSQL to be ready"
done

# Recreate indices
echo "Recreate indices"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "reindex database auction;"

# Force a vacuum and checkpoint
echo "Force vacuum"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "vacuum analyze;"
echo "Force checkpoint"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "checkpoint;"

touch /tmp/isReady
#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
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
echo "Drop and recreate indices"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_pkeys.sql
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql

# Force a vacuum and checkpoint
echo "Force vacuum"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "vacuum analyze;"
echo "Force checkpoint"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "checkpoint;"

touch /tmp/isReady
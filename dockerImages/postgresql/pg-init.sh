#!/bin/bash
set -e

if [ ! -s "/mnt/dbData/postgresql/PG_VERSION" ]; then
  MODE="firstrun"
else
  MODE="alreadyinitialized"
fi

if [ "$MODE" == 'firstrun' ]; then
  # Make postgres own PGDATA
  chown -R postgres:postgres /mnt/dbData/postgresql
  rm -rf /mnt/dbData/postgresql/*

  # Setup postgres
  echo "Initialize postgres" >&2
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/initdb -D /mnt/dbData/postgresql

  mv /pg_hba.conf /mnt/dbData/postgresql/.

  # Start postgresql
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/pg_ctl -D /mnt/dbData/postgresql -w start

  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create role auction with superuser createdb login password 'auction;'"
  sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -U postgres -c "create database auction owner auction;"

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

# Start postgresql
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/postgres -D /mnt/dbData/postgresql 

# Force a vacuum and checkpoint
psql -p ${POSTGRESPORT} -U auction -d auction -c "vacuum analyze;"
psql -p ${POSTGRESPORT} -U auction -d auction -c "checkpoint;"
#!/bin/bash

echo "Clearing auction database"
psql -p ${POSTGRESPORT} -U auction -d postgres -f /dbScripts/auction_postgresql_database.sql
psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_tables.sql
psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_constraints.sql
psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql
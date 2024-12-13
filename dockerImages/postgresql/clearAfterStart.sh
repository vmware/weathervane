#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

echo "Clearing auction database"
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d postgres -f /dbScripts/auction_postgresql_database.sql
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_tables.sql
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_constraints.sql
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql

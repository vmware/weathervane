#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
set -e

# Reindex
echo "Drop and recreate indices"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql

# Force a vacuum and checkpoint
echo "Force vacuum"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "vacuum analyze;"
echo "Force checkpoint"
sudo -u postgres /usr/pgsql-${PG_MAJOR}/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "checkpoint;"
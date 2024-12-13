#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
set -e

# Reindex
echo "Reindex"
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "reindex database auction;"

# Force a vacuum and checkpoint
echo "Force vacuum"
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "vacuum analyze;"
echo "Force checkpoint"
sudo -u postgres /usr/lib/postgresql/9.6/bin/psql -p ${POSTGRESPORT} -U auction -d auction -c "checkpoint;"

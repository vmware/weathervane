#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

echo "Clearing cassandra database"
cqlsh -f /auction_cassandra_configured.cql $HOSTNAME

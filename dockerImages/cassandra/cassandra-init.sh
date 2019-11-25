#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
set -e

chown -R cassandra:cassandra /data

echo "Configure cassandra.yaml"
perl /configure.pl	

# Start cassandra
echo "Starting cassandra"
cassandra -R

#!/bin/bash
set -e

chown -R cassandra:cassandra /data

echo "Configure cassandra.yaml"
perl /configure.pl	

# Start cassandra
echo "Starting cassandra"
su cassandra -c cassandra

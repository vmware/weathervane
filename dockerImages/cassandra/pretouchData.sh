#!/bin/bash

echo "Warming cassandra database"
cqlsh -f /pretouchData.cql $HOSTNAME > /dev/null

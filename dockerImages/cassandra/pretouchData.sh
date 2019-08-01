#!/bin/bash

echo "Warming cassandra database"
cqlsh -f /pretouchData.cql --request-timeout=3600 $HOSTNAME > /dev/null

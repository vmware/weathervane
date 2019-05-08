#!/bin/bash

echo "Clearing cassandra database"
cqlsh -f /auction_cassandra.cql $HOSTNAME

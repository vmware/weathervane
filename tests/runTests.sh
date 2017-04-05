#!/bin/sh
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.0

# These config files all use nginx/postgresql/shardedMongoDB
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.1
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.2
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.3

/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.4

/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.5
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.6 

/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.10
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.11
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.12
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.13

# Multi-Workload tests
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.18

/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.19 --runProcedure=prepareOnly
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.19 --runProcedure=runOnly

# Docker test cases
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.15
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.16
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.17

# Replicated mongodb
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.7
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.8

# This is a targetUtilization run
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.9

# This is a findMax run
/root/weathervane/weathervane.pl --configFile=/root/weathervane-test/weathervane.config.test.14

# Repeatability runs.  Repeats of previous runs

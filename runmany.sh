#!/bin/sh

# You can put multiple calls of the weathervane.pl script in this file, and 
# then run this file to start a series of runs.  You can either use a separate
# configuration file for each run, or use command-line options to override 
# options set in the config file.  Below are some examples of
# using the script.  You can uncomment them and edit as appropriate,

# This is a basic invocation that only uses options set in the 
# default weathervane.config file
#./weathervane.pl

# These invocations overrids the number of users set in the config file.
# Notice that the output of the run script is redirected to a file named console.log.  
# This is done so that it can be checked for errors after the runs are complete. The
# progress of the run can be followed with `tail -f console.log`
#./weathervane.pl --users=500 
#./weathervane.pl --users=1000  

# The following invocation can be used to run the workload in maximum finding mode.
./weathervane.pl --users=200 --runStrategy=findMax --initialRateStep=100 --minRateStep=50 --runLength=medium --description="initial test"  


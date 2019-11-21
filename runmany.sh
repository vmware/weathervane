#!/bin/sh

# You can put multiple calls of the runWeathervane.pl script in this file, and 
# then run this file to start a series of runs.  You can either use a separate
# configuration file for each run, or use command-line options to override 
# options set in the configuration file.  Below are some examples of
# using the script.  You can uncomment them and edit as appropriate,

# This is a basic invocation that only uses options set in the specified 
# configuration file. To use this you would replace weathervane.config
# with the name of your configuration file.
#./runWeathervane.pl --configFile weathervane.config

# These invocations override the runStrategy and number of users set in the 
# configuration file using command-line parameters. Notice that the --
# is required between the parameters to the runWeathervane.pl script and
# the command-line parameters.
#./runWeathervane.pl --configFile weathervane.config -- --runStrategy=fixed --users=500 
#./runWeathervane.pl --configFile weathervane.config -- --runStrategy=fixed --users=1000 

# The following invocation can be used to run the findMaxSingleRun runStrategy, 
# even if the configuration file specifies the fixed runStrategy.
#./runWeathervane.pl --configFile weathervane.config -- --runStrategy=fixed

# You can add as many additional invocations as desired in this file.  They will 
# run sequentially.
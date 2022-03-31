import os
import sys

return_code = 0

# runWeathervane.pl configFile argument requires an absolute file path to the config file.
# Get current working directory to interpolate the absolute file path.
cwd = os.getcwd()

# On the first run of Weathervane, the user is asked to accept Weathervane terms. On completion,
# the file .accept-weathervane is created. This script creates the file which is required for 
# weathervane to run.
return_code = os.system("touch .accept-weathervane")

# Start one findmax run for each configuration size. Small2 is deprecated but still supported 
# as of Weathervane 2.1.1.
# redeploy flag is required to make sure all new containers are pulled each time as code may have 
# changed since the previous CICD execution.
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.micro -- --redeploy".format(cwd))
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.xsmall -- --redeploy".format(cwd))
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.small2 -- --redeploy".format(cwd))
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.small3 -- --redeploy".format(cwd))

# Return code processing allows the Jenkins CICD pipeline to detect testing pass/fail. If any
# test fails, the entire stage fails.
if return_code > 0:
	sys.exit(1)
else:
	sys.exit(0)
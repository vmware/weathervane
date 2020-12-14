
import os
import sys

return_code = 0

# runWeathervane.pl configFile argument requires an absolute file path to the config file.
# Get current working directory to interpolate the absolute file path.
cwd = os.getcwd()

return_code = os.system("touch .accept-weathervane")
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.micro-dev".format(cwd))
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.xsmall-dev".format(cwd))
return_code += os.system("./runWeathervane.pl --configFile={}/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.small2-dev".format(cwd))

#print("The return code was: %d" % return_code)
if return_code > 0:
	sys.exit(1)
else:
	sys.exit(0)

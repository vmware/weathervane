
import os
import sys

return_code = 0

return_code = os.system("touch .accept-weathervane")
return_code += os.system("./runWeathervane.pl --configFile=/root/weathervane/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.micro")
return_code += os.system("./runWeathervane.pl --configFile=/root/weathervane/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.xsmall")
return_code += os.system("./runWeathervane.pl --configFile=/root/weathervane/testing/e2e/weathervaneConfigFiles/weathervane.config.k8s.small2")

#print("The return code was: %d" % return_code)
if return_code > 0:
	sys.exit(1)
else:
	sys.exit(0)

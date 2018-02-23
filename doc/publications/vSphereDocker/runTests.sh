#!/bin/sh
# This file contains the invocations of weathervane that were used to collect the data used in the 
# whitepaper "Performance Of Enterprise Web Applications In Docker Containers On VMware vSphere 6.5"

./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=1000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=10000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=20000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=25000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=30000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=35000
./weathervane.pl --configFile=weathervane.config.vmNoDocker.2w6a --description="vms,noDocker,2w6a" --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3

./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=1000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=10000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=20000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=25000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=30000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=35000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,2w6a" --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3


./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=1000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=10000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=20000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=25000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=30000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=35000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a --description="baremetal,Docker,2w6a" --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3

./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=1000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=10000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=20000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=25000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=30000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=35000
./weathervane.pl --configFile=weathervane.config.vmDocker.2w6a --description="vms,docker,netHost,2w6a" --dockerNet=host --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3

./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=1000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=10000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=20000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=25000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=30000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=35000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.numaAffinity --description="baremetal,Docker,2w6a,numaAffinity" --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3

./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=1000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=10000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=20000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=25000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=30000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=35000
./weathervane.pl --configFile=weathervane.config.baremetalDocker.2w6a.threadAffinity --description="baremetal,Docker,2w6a,threadAffinity" --users=40000 --initialRateStep=4000 --runStrategy=findMax --repeatsAtMax=3

#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   kill -TERM $pid
   exit 0
}

trap 'sigterm' TERM

perl /updateResolveConf.pl

if [ ! -e "/fifo" ]; then
	mkfifo /fifo || exit
fi
chmod 400 /fifo

if [ $# -gt 0 ]; then
	eval "$* &"
else
	java $JVMOPTS -DwkldNum=$WORKLOADNUM -cp /workloadDriver.jar:/workloadDriverLibs/*:/workloadDriverLibs/ com.vmware.weathervane.workloadDriver.WorkloadDriverApplication --port=$PORT &
fi

pid="$!"

# wait indefinitely
while true;
do
  echo "Waiting for child to exit."
  read < /fifo
  echo "Child Exited"
done

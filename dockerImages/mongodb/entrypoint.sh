#!/bin/bash

sigterm()
{
   echo "signal TERM received. cmd = $cmd, $numArgs = $numArgs"   
   rm -f /fifo
   if [ $numArgs -gt 0 ]; then
  	 eval "$cmd --shutdown"
   else
	/usr/bin/mongod -f /etc/mongod.conf --shutdown
   fi
   exit 0
}

sigusr1()
{
   echo "signal USR1 received. Clearing data and restarting"

}


sigusr2()
{
   echo "signal USR2 received. Performing sanity checks"
   perl /sanityCheck.pl
   if [ $? -eq 0 ]
   then
   	echo "Sanity Checks Passed"
   else
   	echo "Sanity Checks Failed"
   fi
   
}

trap 'sigterm' TERM
trap 'sigusr1' USR1
trap 'sigusr2' USR2

echo "search weathervane" >> /etc/resolv.conf 

echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

cmd=$*
numArgs=$#

if [ $CLEARBEFORESTART -eq 1 ]; then
  find /mnt/mongoData/* -delete
  find /mnt/mongoC1Data/* -delete
  find /mnt/mongoC2Data/* -delete
  find /mnt/mongoC3Data/* -delete
fi

perl /configure.pl

if [ $numArgs -gt 0 ]; then
	eval "$cmd &"
else
	/usr/bin/mongod -f /etc/mongod.conf &
fi

if [ ! -e "/fifo" ]; then
	mkfifo /fifo || exit
fi
chmod 400 /fifo

# wait indefinitely
while true;
do
  echo "Waiting for child to exit."
  read < /fifo
  echo "Child Exited"
done

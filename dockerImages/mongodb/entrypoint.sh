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
   echo "signal USR1 received. "
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "search weathervane" >> /etc/resolv.conf 

echo never > /sys/kernel/mm/transparent_hugepage/enabled
echo never > /sys/kernel/mm/transparent_hugepage/defrag

cmd=$*
numArgs=$#

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

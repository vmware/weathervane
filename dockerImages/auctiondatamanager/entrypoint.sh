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

# wait indefinitely
while true;
do
  echo "Waiting for child to exit."
  read < /fifo
  echo "Child Exited"
done

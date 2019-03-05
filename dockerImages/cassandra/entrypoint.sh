#!/bin/bash

sigterm()
{
   echo "signal TERM received pid = $pid."
   rm -f /fifo
   nodetool decommission
   nodetool stopdaemon
   exit 0
}

trap 'sigterm' TERM

echo "Update resolv.conf"
perl /updateResolveConf.pl

if [ $CLEARBEFORESTART -eq 1 ]; then
  echo "Clearing old Cassandra data"
  find /data/data/* -delete
  find /data/commitlog/* -delete
fi

if [ $# -gt 0 ]; then
	eval "$* &"
else
	echo "starting cassandra"
	setsid /cassandra-init.sh &
fi

pid="$!"

tail -f /var/log/cassandra/* &

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

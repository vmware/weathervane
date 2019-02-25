#!/bin/bash

sigterm()
{
   echo "signal TERM received."
   systemctl stop cassandra
   rm -f /fifo
   exit 0
}

trap 'sigterm' TERM

echo "Update resolv.conf"
perl /updateResolveConf.pl

if [ $CLEARBEFORESTART -eq 1 ]; then
  echo "Clearing old Cassandra data"
fi

perl /configure.pl

if [ $# -gt 0 ]; then
	eval "$* &"
else
	echo "starting cassandra"
	systemctl start cassandra
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

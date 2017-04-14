#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   kill -TERM $pid
   exit 0
}

sigusr1()
{
   echo "signal USR1 received.  pid = $pid. Reloading"
   cd /mnt/zookeeper ; /opt/zookeeper/bin/zkServer.sh restart
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "search weathervane eng.vmware.com" >> /etc/resolv.conf 

if [ $# -gt 0 ]; then
	eval "$* &"
else
    cd /mnt/zookeeper ; /opt/zookeeper/bin/zkServer.sh start
    tail -F -n1 /mnt/zookeeper/zookeeper.out
fi

pid="$!"


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

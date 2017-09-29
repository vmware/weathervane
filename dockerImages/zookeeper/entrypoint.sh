#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   kill -TERM $pid
   exit 0
}

trap 'sigterm' TERM

echo "search weathervane eng.vmware.com" >> /etc/resolv.conf 

perl /configure.pl

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

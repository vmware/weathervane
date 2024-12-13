#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   kill -TERM $pid
   exit 0
}

trap 'sigterm' TERM

perl /updateResolveConf.pl

# Need to wait for zookeeperServers.txt file to exist before continuing
while [ ! -f /zookeeperServers.txt ] && [ -z "$ZK_SERVERS" ]; do
  echo "Waiting for setup completion"
  sleep 5
done

perl /configure.pl

# If zookeeper is clustered, then wait until all nodes are reachable
# before starting zookeeper
perl /waitForNodes.pl

if [ $# -gt 0 ]; then
	eval "$* &"
else
    cd /mnt/zookeeper ; setsid /opt/zookeeper/bin/zkServer.sh start
    tail -F -n1 /opt/zookeeper/logs/zookeeper--server-*.out
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

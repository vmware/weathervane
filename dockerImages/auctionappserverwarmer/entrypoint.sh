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

if [ $# -gt 0 ]; then
	eval "$* &"
else
	setsid java -jar ${WARMER_JVMOPTS} -DTHREADSPERSERVER=${WARMER_THREADS_PER_SERVER} -DITERATIONS=${WARMER_ITERATIONS} /auctionAppServerWarmer.jar 
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

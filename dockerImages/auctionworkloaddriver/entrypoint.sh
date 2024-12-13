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

if [ ! -e "/fifo" ]; then
	mkfifo /fifo || exit
fi
chmod 400 /fifo

if [ $# -gt 0 ]; then
	eval "$* &"
else
	setsid java $JVMOPTS -DwkldNum=$WORKLOADNUM -Djava.library.path=/usr/lib/x86_64-linux-gnu/jni -cp /workloadDriver.jar:/workloadDriverLibs/*:/workloadDriverLibs/ org.springframework.boot.loader.JarLauncher --port=$PORT &
fi

pid="$!"

# wait indefinitely
while true;
do
  echo "Waiting for child to exit."
  read < /fifo
  echo "Child Exited"
done

#!/bin/bash
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   /usr/sbin/nginx -s stop
   exit 0
}

sigusr1()
{
   echo "signal USR1 received.  pid = $pid. Reloading"
   if pgrep -x "nginx" > /dev/null
   then
	   perl /configure.pl
	   /usr/sbin/nginx -s reload
	else
	   perl /configure.pl
	   /usr/sbin/nginx &
	fi
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

rm -rf /var/cache/nginx/*
chown -R nginx:nginx /var/cache/nginx

perl /updateResolveConf.pl

if [ $# -gt 0 ]; then
	eval "$* &"
else
	perl /configure.pl
	setsid /usr/sbin/nginx  &
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

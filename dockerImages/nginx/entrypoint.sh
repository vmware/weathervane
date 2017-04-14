#!/bin/bash

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
	   /usr/sbin/nginx -s reload
	else
	   /usr/sbin/nginx &
	fi
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "search weathervane eng.vmware.com" >> /etc/resolv.conf 

if [ $# -gt 0 ]; then
	eval "$* &"
else
	/usr/sbin/nginx  &
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

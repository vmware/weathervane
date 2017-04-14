#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl stop -D /mnt/dbData/postgresql 
   exit 0
}

sigusr1()
{
   echo "signal USR1 received.  pid = $pid. Reloading"
   kill $pid
   if [ $# -gt 0 ]; then
	  eval "$* &"
   else
	  sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl restart -D /mnt/dbData/postgresql 
   fi
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "search weathervane eng.vmware.com" >> /etc/resolv.conf 

if [ $# -gt 0 ]; then
	eval "$* &"
else
	/pg-init.sh &
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

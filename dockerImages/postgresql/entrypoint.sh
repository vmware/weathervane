#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   sudo -u postgres /usr/pgsql-9.3/bin/pg_ctl stop -D /mnt/dbData/postgresql 
   exit 0
}

trap 'sigterm' TERM

echo "Update resolv.conf"
perl /updateResolveConf.pl

if [ $# -gt 0 ]; then
	eval "$* &"
else
    echo "Configure postgresql.conf"
	perl /configure.pl
	
	echo "start postgresql"
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

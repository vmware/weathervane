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
   echo "signal USR1 received.  Clearing auction database"
   psql -p ${POSTGRESPORT} -U auction -d postgres -f /dbScripts/auction_postgresql_database.sql
   psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_tables.sql
   psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_constraints.sql
   psql -p ${POSTGRESPORT} -U auction -d auction -f /dbScripts/auction_postgresql_indices.sql
}

sigusr2()
{
   echo "signal USR2 received. Dumping postgresql stats to stdout."
	perl /dumpStats.pl
}
trap 'sigterm' TERM
trap 'sigusr1' USR1
trap 'sigusr2' USR2

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

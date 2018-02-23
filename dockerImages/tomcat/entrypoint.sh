#!/bin/bash

sigterm()
{
   echo "signal TERM received."
   rm -f /fifo
   /opt/apache-tomcat/bin/shutdown.sh -force
   cat /opt/apache-tomcat-auction1/logs/*
   rm -f /opt/apache-tomcat-auction1/logs/*
   exit 0
}

sigusr1()
{
    echo "signal USR1 received. start stats collection"
    cp /opt/apache-tomcat-auction1/logs/gc.log /opt/apache-tomcat-auction1/logs/gc_rampup.log
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

perl /updateResolveConf.pl

rm -f /opt/apache-tomcat-auction1/logs/* 
perl /configure.pl

if [ $# -gt 0 ]; then
	eval "$* &"
else
    /opt/apache-tomcat/bin/startup.sh &
fi

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

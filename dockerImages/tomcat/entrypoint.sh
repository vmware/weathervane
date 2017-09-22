#!/bin/bash

sigterm()
{
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   /opt/apache-tomcat/bin/shutdown.sh -force
   cat /opt/apache-tomcat-auction1/logs/*
   rm -f /opt/apache-tomcat-auction1/logs/*
   exit 0
}

sigusr1()
{
    echo "signal USR1 received.  pid = $pid. Reloading"
    /opt/apache-tomcat/bin/shutdown.sh -force
	/opt/apache-tomcat/bin/startup.sh &
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "search weathervane eng.vmware.com" >> /etc/resolv.conf 

rm -f /opt/apache-tomcat-auction1/logs/* 

if [ $# -gt 0 ]; then
	eval "$* &"
else
    /opt/apache-tomcat/bin/startup.sh &
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

#!/bin/bash
# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

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
    setsid /opt/apache-tomcat/bin/startup.sh  &
fi

if [ ! -e "/fifo" ]; then
	mkfifo /fifo || exit
fi
chmod 400 /fifo

sleep 30;
tail -f /opt/apache-tomcat-auction1/logs/* &

# wait indefinitely
while true;
do
  echo "Waiting for child to exit."
  read < /fifo
  echo "Child Exited"
done

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
   echo "signal TERM received. pid = $pid"
   rm -f /fifo
   kill -TERM $pid
   exit 0
}

sigusr1()
{
   echo "signal USR1 received.  pid = $pid. We don't reload RabbitMQ"
}

trap 'sigterm' TERM
trap 'sigusr1' USR1

echo "Add weathervane domain to resolv.conf" 
perl /updateResolveConf.pl

newuid=$((4096 + RANDOM))
olduid=$(id -u rabbitmq)
echo "Assigning random uid $newuid to rabbitmq user with uid $olduid"
usermod -u $newuid rabbitmq
find / -user $olduid  -exec chown -h $newuid {} \;

echo "Set file permissions" 
chown rabbitmq:rabbitmq /var/lib/rabbitmq/.erlang.cookie
chmod 600 /var/lib/rabbitmq/.erlang.cookie
chmod 600 /root/.erlang.cookie

hostname="$(hostname)"

echo "NODENAME=rabbit@${hostname}"
echo "NODENAME=rabbit@${hostname}" > /etc/rabbitmq/rabbitmq-env.conf
printf "total_memory_available_override_value = ${RABBITMQ_MEMORY}\n"
printf "total_memory_available_override_value = ${RABBITMQ_MEMORY}\n" >> /etc/rabbitmq/rabbitmq.conf
printf "vm_memory_high_watermark.relative = 0.8\n"
printf "vm_memory_high_watermark.relative = 0.8\n" >> /etc/rabbitmq/rabbitmq.conf

if [ $# -gt 0 ]; then
	eval "$* &"
else
    echo "Start RabbitMQ: sudo -u rabbitmq RABBITMQ_NODE_PORT=${RABBITMQ_NODE_PORT} RABBITMQ_DIST_PORT=${RABBITMQ_DIST_PORT} rabbitmq-server &"
	setsid sudo -u rabbitmq RABBITMQ_NODE_PORT=${RABBITMQ_NODE_PORT} RABBITMQ_DIST_PORT=${RABBITMQ_DIST_PORT} rabbitmq-server &
	until perl /isUp.pl
	do
		echo "Waiting for RabbitMQ to come up";
		sleep 20;
	done
	echo "RabbitMQ is up"
	rabbitmqctl add_user auction auction
	rabbitmqctl set_user_tags auction administrator
	rabbitmqctl add_vhost auction
	rabbitmqctl set_permissions -p auction auction ".*" ".*" ".*"
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

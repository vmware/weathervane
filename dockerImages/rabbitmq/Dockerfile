FROM 10.159.13.130:5000/centos7ssh:1.0b5
MAINTAINER hrosenbe@vmware.com
	
COPY erlang.cookie /root/.erlang.cookie
COPY erlang.cookie /var/lib/rabbitmq/.erlang.cookie
COPY entrypoint.sh /entrypoint.sh
COPY rabbitmqadmin  /usr/local/bin/rabbitmqadmin

RUN chmod +x /entrypoint.sh && \
	chmod +x /usr/local/bin/rabbitmqadmin && \
	yum install -y https://www.rabbitmq.com/releases/erlang/erlang-17.4-1.el6.x86_64.rpm && \
	yum install -y http://www.rabbitmq.com/releases/rabbitmq-server/v3.5.3/rabbitmq-server-3.5.3-1.noarch.rpm && \
	rabbitmq-plugins enable rabbitmq_management && \
  	yum -y clean all 

ENTRYPOINT ["/entrypoint.sh"]

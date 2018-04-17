FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com
	
COPY erlang.repo /etc/yum.repos.d/erlang.repo
COPY erlang.cookie /root/.erlang.cookie
COPY erlang.cookie /var/lib/rabbitmq/.erlang.cookie
COPY entrypoint.sh /entrypoint.sh
COPY rabbitmqadmin  /usr/local/bin/rabbitmqadmin

RUN chmod +x /entrypoint.sh && \
	chmod +x /usr/local/bin/rabbitmqadmin && \
	chmod 600 /var/lib/rabbitmq/.erlang.cookie && \
    rpm --import https://www.rabbitmq.com/rabbitmq-release-signing-key.asc && \
	yum install -y erlang && \
    yum install -y https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.7.4/rabbitmq-server-3.7.4-1.el7.noarch.rpm && \
	rabbitmq-plugins enable rabbitmq_management && \
  	yum -y clean all 

ENTRYPOINT ["/entrypoint.sh"]

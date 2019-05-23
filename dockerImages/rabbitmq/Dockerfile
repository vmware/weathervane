FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com
	
COPY erlang.repo /etc/yum.repos.d/erlang.repo
COPY erlang.cookie /root/.erlang.cookie
COPY erlang.cookie /var/lib/rabbitmq/.erlang.cookie
COPY entrypoint.sh /entrypoint.sh
COPY rabbitmqadmin  /usr/local/bin/rabbitmqadmin
COPY isUp.pl /isUp.pl    

RUN chmod +x /entrypoint.sh && \
	chmod +x /usr/local/bin/rabbitmqadmin && \
	chmod 600 /var/lib/rabbitmq/.erlang.cookie && \
    rpm --import https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc && \
	yum install -y erlang && \
    yum install -y https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.7.14/rabbitmq-server-3.7.14-1.el7.noarch.rpm && \
	rabbitmq-plugins enable rabbitmq_management && \
  	yum -y clean all 

ENTRYPOINT ["/entrypoint.sh"]

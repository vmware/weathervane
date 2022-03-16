# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY erlang.cookie /root/.erlang.cookie
COPY erlang.cookie /var/lib/rabbitmq/.erlang.cookie
COPY entrypoint.sh /entrypoint.sh
COPY rabbitmqadmin  /usr/local/bin/rabbitmqadmin
COPY isUp.pl /isUp.pl
ARG http_proxy
RUN chmod +x /entrypoint.sh && \
	chmod +x /usr/local/bin/rabbitmqadmin && \
	chmod 600 /var/lib/rabbitmq/.erlang.cookie && \
	rpm --import https://github.com/rabbitmq/signing-keys/releases/download/2.0/rabbitmq-release-signing-key.asc && \
	yum install -y https://github.com/rabbitmq/erlang-rpm/releases/download/v21.3.8.21/erlang-21.3.8.21-1.el7.x86_64.rpm && \
	yum install -y https://github.com/rabbitmq/rabbitmq-server/releases/download/v3.7.17/rabbitmq-server-3.7.17-1.el7.noarch.rpm && \
	rabbitmq-plugins enable rabbitmq_management && \
  	yum -y clean all

ENTRYPOINT ["/entrypoint.sh"]

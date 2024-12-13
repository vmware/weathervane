# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

COPY erlang.cookie /root/.erlang.cookie
COPY erlang.cookie /var/lib/rabbitmq/.erlang.cookie
COPY entrypoint.sh /entrypoint.sh
COPY rabbitmqadmin  /usr/local/bin/rabbitmqadmin
COPY isUp.pl /isUp.pl
ARG http_proxy
RUN \
	apt-get update && \
	chmod +x /entrypoint.sh && \
	chmod +x /usr/local/bin/rabbitmqadmin && \
	chmod 600 /var/lib/rabbitmq/.erlang.cookie && \
	apt-get install -y rabbitmq-server && \
	rabbitmq-plugins enable rabbitmq_management && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/entrypoint.sh"]

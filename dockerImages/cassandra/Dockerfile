# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl    
COPY isUp.pl /isUp.pl    
COPY cqlsh.in /cqlsh.in
COPY clearAfterStart.sh /clearAfterStart.sh   
COPY cassandra-init.sh /cassandra-init.sh    
COPY auction_cassandra.cql /auction_cassandra.cql
COPY cassandra.yaml /cassandra.yaml
COPY jvm-server.options /jvm-server.options
ARG http_proxy

RUN \
	wget -q -O - https://downloads.apache.org/cassandra/KEYS | sudo apt-key add - &&\
	echo "deb https://debian.cassandra.apache.org 40x main" > /etc/apt/sources.list.d/cassandra.list && \
	apt-get update && \
	apt-get install -y openjdk-8-jdk && \
	apt-get install -y cassandra && \
	mkdir -p /data && \
	rm /etc/security/limits.d/cassandra.conf && \
	chmod +x /clearAfterStart.sh && \
	chmod +x /cassandra-init.sh && \
	chmod +x /entrypoint.sh && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*
    
VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]   

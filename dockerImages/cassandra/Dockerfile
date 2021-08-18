# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY cassandra.repo /etc/yum.repos.d/cassandra.repo
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl    
COPY isUp.pl /isUp.pl    
COPY cqlsh.in /cqlsh.in
COPY clearAfterStart.sh /clearAfterStart.sh   
COPY cassandra-init.sh /cassandra-init.sh    
COPY auction_cassandra.cql /auction_cassandra.cql
COPY cassandra.yaml /cassandra.yaml
COPY jvm.options /jvm.options
ARG http_proxy

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum install -y python && \
	yum install -y https://archive.apache.org/dist/cassandra/redhat/311x/cassandra-3.11.10-1.noarch.rpm && \
	yum -y clean all && \
	mkdir -p /data && \
	rm /etc/security/limits.d/cassandra.conf && \
    chmod +x /clearAfterStart.sh && \
    chmod +x /cassandra-init.sh && \
    chmod +x /entrypoint.sh 
    
VOLUME ["/data"]

ENTRYPOINT ["/entrypoint.sh"]   

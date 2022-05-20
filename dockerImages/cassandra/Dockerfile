# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

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

RUN yum install -y http://mirror.centos.org/centos/7/updates/x86_64/Packages/java-1.8.0-openjdk-1.8.0.322.b06-1.el7_9.x86_64.rpm && \
	yum install -y http://mirror.centos.org/centos/7/updates/x86_64/Packages/java-1.8.0-openjdk-devel-1.8.0.322.b06-1.el7_9.x86_64.rpm && \
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

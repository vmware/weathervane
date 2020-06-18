# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com
	
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl
COPY waitForNodes.pl /waitForNodes.pl
COPY zoo.cfg /root/zookeeper/conf/zoo.cfg

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum install -y nc && \
	curl https://archive.apache.org/dist/zookeeper/zookeeper-3.4.14/zookeeper-3.4.14.tar.gz -o zookeeper-3.4.14.tar.gz && \
    tar zxf zookeeper-3.4.14.tar.gz && rm -r zookeeper-3.4.14.tar.gz && \
    mv zookeeper-3.4.14 /opt/zookeeper-3.4.14 && \
	ln -s /opt/zookeeper-3.4.14 /opt/zookeeper && \
	mkdir /mnt/zookeeper && \
    chmod +x /entrypoint.sh

VOLUME /mnt/zookeeper

ENTRYPOINT ["/entrypoint.sh"]

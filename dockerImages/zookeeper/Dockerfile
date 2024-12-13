# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version
	
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl
COPY waitForNodes.pl /waitForNodes.pl
COPY zoo.cfg /root/zookeeper/conf/zoo.cfg
ARG http_proxy

RUN \
	apt-get update && \
	apt-get install -y netcat && \
	apt-get install -y openjdk-8-jdk && \
	if [ -z ${http_proxy+x} ]; then export proxy=''; else export proxy="-x $http_proxy"; fi && \
	curl $proxy https://archive.apache.org/dist/zookeeper/zookeeper-3.8.3/apache-zookeeper-3.8.3-bin.tar.gz -o zookeeper-3.8.3.tar.gz && \
	tar zxf zookeeper-3.8.3.tar.gz && rm -r zookeeper-3.8.3.tar.gz && \
	mv apache-zookeeper-3.8.3-bin /opt/zookeeper-3.8.3 && \
	ln -s /opt/zookeeper-3.8.3 /opt/zookeeper && \
	mkdir /mnt/zookeeper && \
	chmod +x /entrypoint.sh && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

VOLUME /mnt/zookeeper

ENTRYPOINT ["/entrypoint.sh"]

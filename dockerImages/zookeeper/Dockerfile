FROM namespace/centos7ssh:version
MAINTAINER hrosenbe@vmware.com
	
COPY entrypoint.sh /entrypoint.sh
ARG ZOOKEEPER_VERSION=3.4.10

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	curl -s http://www.us.apache.org/dist/zookeeper/stable/zookeeper-${ZOOKEEPER_VERSION}.tar.gz -o zookeeper-${ZOOKEEPER_VERSION}.tar.gz && \
    tar zxf zookeeper-${ZOOKEEPER_VERSION}.tar.gz && rm -r zookeeper-${ZOOKEEPER_VERSION}.tar.gz && \
    mv zookeeper-${ZOOKEEPER_VERSION} /opt/zookeeper-${ZOOKEEPER_VERSION} && \
	ln -s /opt/zookeeper-${ZOOKEEPER_VERSION} /opt/zookeeper && \
	mkdir /mnt/zookeeper && \
    chmod +x /entrypoint.sh

COPY zoo.cfg /opt/zookeeper/conf


ENTRYPOINT ["/entrypoint.sh"]

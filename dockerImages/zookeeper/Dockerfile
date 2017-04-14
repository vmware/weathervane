FROM 10.159.13.130:5000/centos7ssh:1.0b5
MAINTAINER hrosenbe@vmware.com
	
COPY entrypoint.sh /entrypoint.sh

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	curl -s http://www.us.apache.org/dist/zookeeper/stable/zookeeper-3.4.9.tar.gz -o zookeeper-3.4.9.tar.gz && \
    tar zxf zookeeper-3.4.9.tar.gz && rm -r zookeeper-3.4.9.tar.gz && \
    mv zookeeper-3.4.9 /opt/zookeeper-3.4.9 && \
	ln -s /opt/zookeeper-3.4.9 /opt/zookeeper && \
	mkdir /mnt/zookeeper && \
    chmod +x /entrypoint.sh

COPY zoo.cfg /opt/zookeeper/conf


ENTRYPOINT ["/entrypoint.sh"]

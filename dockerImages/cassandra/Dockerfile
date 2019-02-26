FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY cassandra.repo /etc/yum.repos.d/cassandra.repo
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl    
COPY cassandra.yaml /cassandra.yaml

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum install -y python && \
	yum install -y cassandra && \
	yum -y clean all && \
	mkdir -p /data/data && \
	mkdir -p /data/commitlog && \
    chmod +x /entrypoint.sh 
    
VOLUME ["/data"]

EXPOSE 7000 7001 7199 9042

ENTRYPOINT ["/entrypoint.sh"]   

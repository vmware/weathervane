# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY apache-tomcat-bid /opt/apache-tomcat-bid
COPY apache-tomcat-bid /root/apache-tomcat-bid
COPY entrypoint.sh /entrypoint.sh
COPY generateCert.sh /generateCert.sh
COPY configure.pl /configure.pl

ENV CATALINA_BASE /opt/apache-tomcat-bid
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0
ARG http_proxy

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum -y clean all && \
	if [ -z ${http_proxy+x} ]; then export proxy=''; else export proxy="-x $http_proxy"; fi && \
	curl $proxy http://archive.apache.org/dist/tomcat/tomcat-8/v8.5.42/bin/apache-tomcat-8.5.42.tar.gz -o apache-tomcat-8.5.42.tar.gz && \
	tar zxf apache-tomcat-8.5.42.tar.gz && \
	rm -f apache-tomcat-8.5.42.tar.gz && \
	mv apache-tomcat-8.5.42 /opt/. && \
	ln -s /opt/apache-tomcat-8.5.42 /opt/apache-tomcat && \
	cp /opt/apache-tomcat/bin/tomcat-juli.jar /opt/apache-tomcat-bid/bin/ && \
	mkdir /opt/apache-tomcat-bid/work && \
	mkdir /opt/apache-tomcat-bid/temp && \
	mkdir /opt/apache-tomcat-bid/logs && \
    chmod +x /generateCert.sh && \
    chmod +x /entrypoint.sh && \
    mkdir -p /etc/pki/tls

ENTRYPOINT ["/entrypoint.sh"]   

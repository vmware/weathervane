FROM namespace/centos7ssh:version
MAINTAINER hrosenbe@vmware.com

COPY apache-tomcat-auction1 /opt/apache-tomcat-auction1
COPY apache-tomcat-auction1 /root/apache-tomcat-auction1
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl

ENV CATALINA_BASE /opt/apache-tomcat-auction1
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0
ARG TOMCAT_VERSION=16

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum -y clean all && \
	curl -s http://www.us.apache.org/dist/tomcat/tomcat-8/v8.5.${TOMCAT_VERSION}/bin/apache-tomcat-8.5.${TOMCAT_VERSION}.tar.gz -o apache-tomcat-8.5.${TOMCAT_VERSION}.tar.gz && \
	tar zxf apache-tomcat-8.5.${TOMCAT_VERSION}.tar.gz && \
	rm -f apache-tomcat-8.5.${TOMCAT_VERSION}.tar.gz && \
	mv apache-tomcat-8.5.${TOMCAT_VERSION} /opt/. && \
	ln -s /opt/apache-tomcat-8.5.${TOMCAT_VERSION} /opt/apache-tomcat && \
	cp /opt/apache-tomcat/bin/tomcat-juli.jar /opt/apache-tomcat-auction1/bin/ && \
	mkdir /opt/apache-tomcat-auction1/work && \
	mkdir /opt/apache-tomcat-auction1/temp && \
	mkdir /opt/apache-tomcat-auction1/logs && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]   

FROM hrosenbe/weathervane-centos7:1.2.0
MAINTAINER hrosenbe@vmware.com

COPY apache-tomcat-bid /opt/apache-tomcat-bid
COPY apache-tomcat-bid /root/apache-tomcat-bid
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl
COPY jprofiler8 /opt/jprofiler8

ENV CATALINA_BASE /opt/apache-tomcat-bid
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
	cp /opt/apache-tomcat/bin/tomcat-juli.jar /opt/apache-tomcat-bid/bin/ && \
	mkdir /opt/apache-tomcat-bid/work && \
	mkdir /opt/apache-tomcat-bid/temp && \
	mkdir /opt/apache-tomcat-bid/logs && \
    chmod +x /entrypoint.sh 

ENTRYPOINT ["/entrypoint.sh"]   

FROM 10.159.13.130:5000/centos7ssh:1.0b5
MAINTAINER hrosenbe@vmware.com

COPY apache-tomcat-auction1 /opt/apache-tomcat-auction1
COPY entrypoint.sh /entrypoint.sh

ENV CATALINA_BASE /opt/apache-tomcat-auction1
ENV JAVA_HOME /usr/lib/jvm/java-1.8.0

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum -y clean all && \
	curl -s http://www.us.apache.org/dist/tomcat/tomcat-8/v8.5.11/bin/apache-tomcat-8.5.11.tar.gz -o apache-tomcat-8.5.11.tar.gz && \
	tar zxf apache-tomcat-8.5.11.tar.gz && \
	rm -f apache-tomcat-8.5.11.tar.gz && \
	mv apache-tomcat-8.5.11 /opt/. && \
	ln -s /opt/apache-tomcat-8.5.11 /opt/apache-tomcat && \
	cp /opt/apache-tomcat/bin/tomcat-juli.jar /opt/apache-tomcat-auction1/bin/ && \
	mkdir /opt/apache-tomcat-auction1/work && \
	mkdir /opt/apache-tomcat-auction1/temp && \
	mkdir /opt/apache-tomcat-auction1/logs && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]   
	
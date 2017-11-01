FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY dbLoader.jar /dbLoader.jar
COPY dbLoaderLibs /dbLoaderLibs
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" LOADDATA=1 PREPDATA=0 MAXUSERS=1000 USERS=1000

ENTRYPOINT ["/entrypoint.sh"]

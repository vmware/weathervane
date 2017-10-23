FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY auctionConfigManager.jar /auctionConfigManager.jar
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" WORKLOADNUM=1 APPINSTANCENUM=1 PORT=8888

ENTRYPOINT ["/entrypoint.sh"]

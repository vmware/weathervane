FROM hrosenbe/weathervane-centos7:1.2.0
MAINTAINER hrosenbe@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY auctionAppServerWarmer.jar /auctionAppServerWarmer.jar
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx250m -Xms250m -XX:+AlwaysPreTouch"

ENTRYPOINT ["/entrypoint.sh"]
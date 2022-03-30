# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY auctionAppServerWarmer.jar /auctionAppServerWarmer.jar

ENV WARMER_THREADS_PER_SERVER 1
ENV WARMER_ITERATIONS 500
ENV WARMER_JVM_OPTS "-Xmx250m -Xms250 -XX:+AlwaysPreTouch -XX:+PreserveFramePointer  -Dspring.profiles.active=postgresql,ehcache,imagesInMongo,singleRabbit "
ARG http_proxy

RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]

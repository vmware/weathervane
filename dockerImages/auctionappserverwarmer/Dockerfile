# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

COPY entrypoint.sh /entrypoint.sh
COPY auctionAppServerWarmer.jar /auctionAppServerWarmer.jar

ENV WARMER_THREADS_PER_SERVER 1
ENV WARMER_ITERATIONS 500
ENV WARMER_JVM_OPTS "-Xmx250m -Xms250 -XX:+AlwaysPreTouch -XX:+PreserveFramePointer  -Dspring.profiles.active=postgresql,ehcache,imagesInMongo,singleRabbit "
ARG http_proxy

RUN \
	apt-get update && \
	apt-get install -y openjdk-8-jdk && \
	chmod +x /entrypoint.sh && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/entrypoint.sh"]

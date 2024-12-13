# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

COPY entrypoint.sh /entrypoint.sh
COPY workloadDriver.jar /workloadDriver.jar
COPY workloadDriverLibs /workloadDriverLibs
ARG http_proxy
	
RUN \
	apt-get update && \
	apt-get install -y httpie && \
	apt-get install -y openjdk-8-jdk && \
	apt-get install -y libnetty-tcnative-java && \
	chmod +x /entrypoint.sh && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENV JVMOPTS="-Xmx2g -Xms2g -XX:+AlwaysPreTouch" PORT=7500 WORKLOADNUM=1

ENTRYPOINT ["/entrypoint.sh"]

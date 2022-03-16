# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY workloadDriver.jar /workloadDriver.jar
COPY workloadDriverLibs /workloadDriverLibs
ARG http_proxy
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
	yum install -y apr && \
	yum install -y apr-devel && \
	yum install -y apr-util && \
	yum install -y apr-util-devel && \
    yum -y clean all && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx2g -Xms2g -XX:+AlwaysPreTouch" PORT=7500 WORKLOADNUM=1

ENTRYPOINT ["/entrypoint.sh"]

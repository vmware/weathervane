# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY dbLoader.jar /dbLoader.jar
COPY dbLoaderLibs /dbLoaderLibs
COPY isDataLoaded.pl /isDataLoaded.pl
COPY loadData.pl /loadData.pl
COPY prepareData.pl /prepareData.pl
COPY prepareDataAfterLoad.pl /prepareDataAfterLoad.pl
COPY images /images
COPY items.json /items.json
ARG http_proxy
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    yum -y clean all && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" LOADDATA=1 PREPDATA=0 MAXUSERS=1000 USERS=1000 USERSPERAUCTIONSCALEFACTOR="15.0"
ENV SPRINGPROFILESACTIVE="postgresql,ehcache,imagesInCassandra,singleRabbit"
ENV CASSANDRA_CONTACTPOINTS=cassandra-0.cassandra CASSANDRA_PORT=9042 DBHOSTNAME=IsoW1I1Db1 DBPORT=5432

ENTRYPOINT ["/entrypoint.sh"]

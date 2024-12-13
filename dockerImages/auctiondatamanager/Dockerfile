# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

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
	
RUN \
	apt-get update && \
	apt-get install -y openjdk-8-jdk && \
	chmod +x /entrypoint.sh && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" LOADDATA=1 PREPDATA=0 MAXUSERS=1000 USERS=1000 USERSPERAUCTIONSCALEFACTOR="15.0"
ENV SPRINGPROFILESACTIVE="postgresql,ehcache,imagesInCassandra,singleRabbit"
ENV CASSANDRA_CONTACTPOINTS=cassandra-0.cassandra CASSANDRA_PORT=9042 DBHOSTNAME=IsoW1I1Db1 DBPORT=5432

ENTRYPOINT ["/entrypoint.sh"]

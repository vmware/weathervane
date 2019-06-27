FROM hrosenbe/weathervane-centos7:2.0.0
MAINTAINER hrosenbe@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY dbLoader.jar /dbLoader.jar
COPY dbLoaderLibs /dbLoaderLibs
COPY isDataLoaded.pl /isDataLoaded.pl
COPY loadData.pl /loadData.pl
COPY prepareData.pl /prepareData.pl
COPY pretouchData.pl /pretouchData.pl
COPY images /images
COPY items.json /items.json
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    yum -y clean all && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" LOADDATA=1 PREPDATA=0 MAXUSERS=1000 USERS=1000 USERSPERAUCTIONSCALEFACTOR="15.0"
ENV SPRINGPROFILESACTIVE="postgresql,ehcache,imagesInCassandra,singleRabbit"
ENV CASSANDRA_CONTACTPOINTS=cassandra-0.cassandra CASSANDRA_PORT=9042 DBHOSTNAME=IsoW1I1Db1 DBPORT=5432

ENTRYPOINT ["/entrypoint.sh"]

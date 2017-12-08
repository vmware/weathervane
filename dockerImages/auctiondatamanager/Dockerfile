FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY mongodb.repo /etc/yum.repos.d/mongo.repo
COPY entrypoint.sh /entrypoint.sh
COPY dbLoader.jar /dbLoader.jar
COPY dbLoaderLibs /dbLoaderLibs
COPY isDataLoaded.pl /isDataLoaded.pl
COPY loadData.pl /loadData.pl
COPY prepareData.pl /prepareData.pl
COPY pretouchData.pl /pretouchData.pl
COPY cleanData.pl /cleanData.pl
COPY images /images
COPY items.json /items.json
	
RUN yum install -y java-1.8.0-openjdk && \
	yum install -y java-1.8.0-openjdk-devel && \
    yum -y clean all && \
    chmod +x /entrypoint.sh

ENV JVMOPTS="-Xmx500m -Xms500m -XX:+AlwaysPreTouch" LOADDATA=1 PREPDATA=0 MAXUSERS=1000 USERS=1000 MAXDURATION=7200 USERSPERAUCTIONSCALEFACTOR="15.0"
ENV NUMNOSQLSHARDS=0 NUMNOSQLREPLICAS=0 SPRINGPROFILESACTIVE="postgresql,ehcache,imagesInMongo,singleMongo,singleRabbit"
ENV MONGODBHOSTNAME=IsoW1I1Nosql1 MONGODBPORT=27017 MONGODBREPLICASET="AuctionNosql1:27017,AuctionNosql2:27017"
ENV DBHOSTNAME=IsoW1I1Db1 DBPORT=5432

ENTRYPOINT ["/entrypoint.sh"]

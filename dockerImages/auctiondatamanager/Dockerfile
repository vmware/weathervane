# Copyright (c) 2017 VMware, Inc. All Rights Reserved.
# 
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
# THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
FROM hrosenbe/weathervane-centos7:2.0.0
MAINTAINER hrosenbe@vmware.com

COPY entrypoint.sh /entrypoint.sh
COPY dbLoader.jar /dbLoader.jar
COPY dbLoaderLibs /dbLoaderLibs
COPY isDataLoaded.pl /isDataLoaded.pl
COPY loadData.pl /loadData.pl
COPY prepareData.pl /prepareData.pl
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

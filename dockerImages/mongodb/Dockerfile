FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY mongodb.repo /etc/yum.repos.d/mongo.repo
COPY mongo*.conf /root/
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl
COPY sanityCheck.pl /sanityCheck.pl

RUN mkdir /mnt/mongoData && \
	mkdir /mnt/mongoBackup && \
	mkdir /mnt/mongoC1Data && \
	mkdir /mnt/mongoC2Data && \
	mkdir /mnt/mongoC3Data && \
	yum -y install mongodb-org && \
    yum -y clean all && \
    chmod +x /entrypoint.sh
    
ENTRYPOINT ["/entrypoint.sh"]  
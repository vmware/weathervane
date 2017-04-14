FROM 10.159.13.130:5000/centos7ssh:1.0b5
MAINTAINER hrosenbe@vmware.com

COPY mongodb.repo /etc/yum.repos.d/mongo.repo
COPY mongo*.conf /etc/
COPY entrypoint.sh /entrypoint.sh

RUN mkdir /mnt/mongoData && \
	mkdir /mnt/mongoBackup && \
	mkdir /mnt/mongoC1Data && \
	mkdir /mnt/mongoC2Data && \
	mkdir /mnt/mongoC3Data && \
	yum -y install mongodb-org && \
    yum -y clean all && \
    chmod +x /entrypoint.sh
    
ENTRYPOINT ["/entrypoint.sh"]  
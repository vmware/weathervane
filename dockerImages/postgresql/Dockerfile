FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

ENV PG_MAJOR 9.3
ENV PG_MAJOR_PKG 93
ENV PGDATA /var/lib/pgsql/${PG_MAJOR}/data

COPY dbScripts /dbScripts
COPY pg-init.sh /pg-init.sh
COPY pg_hba.conf /pg_hba.conf
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl
COPY dumpStats.pl /dumpStats.pl
COPY postgresql.conf /postgresql.conf
COPY clearAfterStart.sh /clearAfterStart.sh

RUN mkdir -p /mnt/dbLogs/postgresql && \
	mkdir -p /mnt/dbData/postgresql && \
	echo \"exclude=postgresql*\" >> /etc/yum.repos.d/CentOS-Base.repo && \
	yum install -y http://yum.postgresql.org/${PG_MAJOR}/redhat/rhel-7-x86_64/pgdg-redhat${PG_MAJOR_PKG}-${PG_MAJOR}-3.noarch.rpm && \
	yum install -y postgresql${PG_MAJOR_PKG} && \
	yum install -y postgresql${PG_MAJOR_PKG}-server && \
	chmod 777 /pg-init.sh && \
	chmod 777 /entrypoint.sh && \
	chmod 777 /clearAfterStart.sh && \
  	yum -y clean all 
  	
	
ENTRYPOINT ["/entrypoint.sh"]  
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

ENV PG_MAJOR 9.3
ENV PG_MAJOR_PKG 93
ENV PGDATA /var/lib/pgsql/${PG_MAJOR}/data
ARG http_proxy

COPY dbScripts /dbScripts
COPY pg-init.sh /pg-init.sh
COPY pg_hba.conf /pg_hba.conf
COPY entrypoint.sh /entrypoint.sh
COPY cleanup.sh /cleanup.sh
COPY configure.pl /configure.pl
COPY dumpStats.pl /dumpStats.pl
COPY postgresql.conf /postgresql.conf
COPY clearAfterStart.sh /clearAfterStart.sh
COPY pgdg-93-centos.repo /etc/yum/repos.d/pgdg-93-centos.repo
COPY RPM-GPG-KEY-PGDG-93 /etc/pki/rpm-gpg/RPM-GPG-KEY-PGDG-93

RUN mkdir -p /mnt && \
	echo \"exclude=postgresql*\" >> /etc/yum.repos.d/CentOS-Base.repo && \
	yum install -y postgresql${PG_MAJOR_PKG} && \
	yum install -y postgresql${PG_MAJOR_PKG}-server && \
	chmod 777 /pg-init.sh && \
	chmod 777 /entrypoint.sh && \
	chmod 777 /cleanup.sh && \
	chmod 777 /clearAfterStart.sh && \
  	yum -y clean all 


ENTRYPOINT ["/entrypoint.sh"]  
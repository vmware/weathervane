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
FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

ENV PG_MAJOR 9.3
ENV PG_MAJOR_PKG 93
ENV PGDATA /var/lib/pgsql/${PG_MAJOR}/data

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
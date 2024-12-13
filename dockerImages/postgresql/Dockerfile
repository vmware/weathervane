# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

ARG http_proxy
ARG DEBIAN_FRONTEND=noninteractive

COPY dbScripts /dbScripts
COPY pg-init.sh /pg-init.sh
COPY pg_hba.conf /pg_hba.conf
COPY entrypoint.sh /entrypoint.sh
COPY cleanup.sh /cleanup.sh
COPY configure.pl /configure.pl
COPY dumpStats.pl /dumpStats.pl
COPY postgresql.conf /postgresql.conf
COPY clearAfterStart.sh /clearAfterStart.sh

RUN \
	apt-get update && \
	mkdir -p /mnt && \
	apt-get install -y lsb-release && \
	curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc|sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/postgresql.gpg && \
	echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" |sudo tee  /etc/apt/sources.list.d/pgdg.list && \
	apt-get update && \
	apt-get install -y postgresql-9.6 && \
	chmod 777 /pg-init.sh && \
	chmod 777 /entrypoint.sh && \
	chmod 777 /cleanup.sh && \
	chmod 777 /clearAfterStart.sh && \
	localedef -i en_US -c -f UTF-8 -A /usr/share/locale/locale.alias en_US.UTF-8 && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["/entrypoint.sh"]

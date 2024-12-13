# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM ubuntu:22.04

COPY sysctl.conf /etc/sysctl.conf
COPY updateResolveConf.pl /updateResolveConf.pl
ARG http_proxy

RUN \
	apt-get update && \
	apt-get install -y wget && \
	apt-get install -y curl && \
	apt-get install -y sudo && \
	apt-get install -y iproute2 && \
	apt-get install -y bind9-dnsutils && \
	apt-get install -y openssh-client && \
	apt-get install -y gnupg && \
	chmod +x /updateResolveConf.pl &&\
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

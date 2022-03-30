# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM centos:7.6.1810
MAINTAINER Hal Rosenberg <weathervane-dev@vmware.com>

COPY sysctl.conf /etc/sysctl.conf
COPY updateResolveConf.pl /updateResolveConf.pl
ARG http_proxy

RUN \
  chmod +x /updateResolveConf.pl && \
  yum -y install wget && \
  yum -y install epel-release && \
  yum -y install httpie && \
  yum -y install sudo && \
  yum -y install iproute && \
  yum -y install perl && \
  yum -y install emacs && \
  yum -y install bind-utils && \
  yum -y install openssh-clients && \
  yum -y install openssl && \
  yum -y clean all 

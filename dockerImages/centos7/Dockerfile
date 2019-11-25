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
FROM centos:7.6.1810
MAINTAINER Hal Rosenberg <hrosenbe@vmware.com>

COPY sysctl.conf /etc/sysctl.conf
COPY updateResolveConf.pl /updateResolveConf.pl
COPY ssh /root/.ssh

RUN \
  chmod +x /updateResolveConf.pl && \
  yum -y install wget && \
  yum -y install epel-release && \
  yum -y install python2-httpie && \
  yum -y install sudo && \
  yum -y install iproute && \
  yum -y install perl && \
  yum -y install emacs && \
  yum -y install bind-utils && \
  yum -y install openssh-clients && \
  yum -y clean all && \
  chmod 600 /root/.ssh/* && \
  mkdir -p /etc/pki/tls/certs && \
  mkdir -p /etc/pki/tls/private 
 
COPY tls/certs/weathervane.crt /etc/pki/tls/certs/weathervane.crt
COPY tls/private/weathervane.key /etc/pki/tls/private/weathervane.key
COPY tls/private/weathervane.pem /etc/pki/tls/private/weathervane.pem
COPY tls/openssl.cnf /etc/pki/tls/openssl.cnf
COPY tls/weathervane.jks /etc/pki/tls/weathervane.jks


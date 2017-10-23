# centos 7 
FROM centos:7.3.1611
MAINTAINER Hal Rosenberg <hrosenbe@vmware.com>

COPY sysctl.conf /etc/sysctl.conf
COPY updateResolveConf.pl /updateResolveConf.pl

RUN \
  chmod +x /updateResolveConf.pl && \
  yum -y install sudo && \
  yum -y install iproute && \
  yum -y install perl && \
  yum -y clean all && \
  mkdir -p /root/.ssh && \
  mkdir -p /etc/pki/tls/certs && \
  mkdir -p /etc/pki/tls/private 
  
COPY tls/certs/weathervane.crt /etc/pki/tls/certs/weathervane.crt
COPY tls/private/weathervane.key /etc/pki/tls/private/weathervane.key
COPY tls/private/weathervane.pem /etc/pki/tls/private/weathervane.pem
COPY tls/openssl.cnf /etc/pki/tls/openssl.cnf
COPY tls/weathervane.jks /etc/pki/tls/weathervane.jks


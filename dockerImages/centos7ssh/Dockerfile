# centos 7 with ssh
FROM centos:7
MAINTAINER Hal Rosenberg <hrosenbe@vmware.com>

COPY sysctl.conf /etc/sysctl.conf
COPY limits.conf /etc/security/limits.conf
COPY common-session /etc/pam.d/common-session
COPY sudoers /etc/sudoers
COPY updateResolveConf.pl /updateResolveConf.pl

RUN \
  chmod +x /updateResolveConf.pl && \
  yum -y install openssh-clients && \
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
COPY id_rsa /root/.ssh/id_rsa
COPY id_rsa.pub /root/.ssh/id_rsa.pub
COPY authorized_keys /root/.ssh/authorized_keys

RUN chmod -R 700 /root/.ssh 


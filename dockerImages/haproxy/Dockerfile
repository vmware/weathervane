FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

RUN \
  yum install -y haproxy && \
  yum install -y mod_ssl && \
  yum -y clean all 

ENV HAPROXY_CONFIG /etc/haproxy/haproxy.cfg

COPY haproxy.cfg /root/haproxy/haproxy.cfg
COPY haproxy.cfg.terminateTLS /root/haproxy/haproxy.cfg.terminateTLS
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]  
FROM 10.159.13.130:5000/centos7ssh:1.0b5
MAINTAINER hrosenbe@vmware.com

RUN \
  yum install -y haproxy && \
  yum install -y mod_ssl && \
  yum -y clean all 

ENV HAPROXY_CONFIG /etc/haproxy/haproxy.cfg

COPY haproxy.cfg /etc/haproxy/haproxy.cfg
COPY entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]  
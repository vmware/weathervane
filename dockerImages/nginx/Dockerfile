# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY nginx.repo /etc/yum.repos.d/nginx.repo
ARG http_proxy

RUN 	yum install -y nginx && \
	yum -y clean all 

COPY html /usr/share/nginx/html
COPY nginx /etc/nginx
COPY nginx /root/nginx
COPY generateCert.sh /generateCert.sh
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    chmod +x /generateCert.sh && \
    chmod +x /entrypoint.sh && \
    mkdir -p /etc/pki/tls/certs && \
    mkdir -p /etc/pki/tls/private 

ENTRYPOINT ["/entrypoint.sh"]  
# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

ARG http_proxy

RUN \
	apt-get update && \
	apt-get install -y nginx && \
	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

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
    mkdir -p /etc/pki/tls/private && \
    groupadd nginx && \
    useradd -g nginx nginx && \
    mkdir -p /var/cache/nginx

ENTRYPOINT ["/entrypoint.sh"]

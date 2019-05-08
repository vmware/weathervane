FROM hrosenbe/weathervane-centos7:2.0.0
MAINTAINER hrosenbe@vmware.com

COPY nginx.repo /etc/yum.repos.d/nginx.repo

RUN 	yum install -y nginx && \
	yum -y clean all 

COPY html /usr/share/nginx/html
COPY nginx /etc/nginx
COPY nginx /root/nginx
COPY entrypoint.sh /entrypoint.sh
COPY configure.pl /configure.pl

# forward request and error logs to docker log collector
RUN ln -sf /dev/stdout /var/log/nginx/access.log && \
    ln -sf /dev/stderr /var/log/nginx/error.log && \
    chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]  
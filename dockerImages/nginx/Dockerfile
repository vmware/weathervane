FROM namespace/centos7ssh:version
MAINTAINER hrosenbe@vmware.com

RUN yum install -y http://nginx.org/packages/centos/7/noarch/RPMS/nginx-release-centos-7-0.el7.ngx.noarch.rpm && \
	yum install -y nginx && \
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
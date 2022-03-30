# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-centos7:version
MAINTAINER weathervane-dev@vmware.com

COPY kubernetes.repo /etc/yum.repos.d/kubernetes.repo
COPY weathervane.pl /root/weathervane/weathervane.pl
COPY runHarness /root/weathervane/runHarness
COPY workloadConfiguration /root/weathervane/workloadConfiguration
COPY configFiles /root/weathervane/configFiles
COPY Notice.txt /root/weathervane/Notice.txt
COPY version.txt /root/weathervane/version.txt

ENV  JAVA_HOME /usr/lib/jvm/java-1.8.0	
ARG http_proxy

RUN yum install -y perl-App-cpanminus && \
	yum install -y wget && \
	yum install -y curl && \
	yum install -y lynx && \
	yum install -y gcc && \
	yum install -y openssh-clients && \
	yum install -y docker-client && \
	yum install -y gettext && \
	yum install -y kubectl && \
	chmod +x /root/weathervane/weathervane.pl && \
	cpanm -n YAML && \
	cpanm -n Config::Simple && \
	cpanm -n String::Util && \
	cpanm -n Statistics::Descriptive && \
	cpanm -n Moose && \
	cpanm -n MooseX::Storage && \
	cpanm -n Tie::IxHash && \
	cpanm -n MooseX::ClassAttribute && \
	cpanm -n MooseX::Types && \
	cpanm -n JSON && \
	cpanm -n Switch && \
	cpanm -n Log::Log4perl && \
	cpanm -n Log::Dispatch::File && \
	cpanm -n LWP 

ENTRYPOINT ["perl", "/root/weathervane/weathervane.pl"]

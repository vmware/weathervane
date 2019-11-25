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
FROM hrosenbe/weathervane-centos7:2.0.0
MAINTAINER hrosenbe@vmware.com

COPY kubernetes.repo /etc/yum.repos.d/kubernetes.repo
COPY weathervane.pl /root/weathervane/weathervane.pl
COPY runHarness /root/weathervane/runHarness
COPY workloadConfiguration /root/weathervane/workloadConfiguration
COPY configFiles /root/weathervane/configFiles
COPY Notice.txt /root/weathervane/Notice.txt
COPY version.txt /root/weathervane/version.txt

ENV  JAVA_HOME /usr/lib/jvm/java-1.8.0	

RUN yum install -y perl-App-cpanminus && \
	yum install -y wget && \
	yum install -y curl && \
	yum install -y lynx && \
	yum install -y gcc && \
	yum install -y openssh-clients && \
	yum install -y docker-client && \
	yum install -y gettext && \
	yum install -y kubectl && \
	chmod -R 600 /root/.ssh && \
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

FROM namespace/weathervane-centos7:version
MAINTAINER hrosenbe@vmware.com

COPY runHarness /root/weathervane/runHarness
COPY dist /root/weathervane/dist
COPY workloadConfiguration /root/weathervane/workloadConfiguration
COPY configFiles /root/weathervane/configFiles
COPY ssh /root/.ssh
COPY Notice.txt /root/weathervane/Notice.txt
COPY version.txt /root/weathervane/version.txt
COPY mongodb.repo /etc/yum.repos.d/mongodb.repo

ENV  JAVA_HOME /usr/lib/jvm/java-1.8.0	

RUN yum install -y perl-App-cpanminus && \
	yum install -y wget && \
	yum install -y curl && \
	yum install -y lynx && \
	yum install -y gcc && \
	yum install -y openssh-clients && \
	yum install -y docker-client && \
	yum install -y mongodb-org-shell && \
	yum localinstall -y http://yum.postgresql.org/9.3/redhat/rhel-7-x86_64/pgdg-centos93-9.3-3.noarch.rpm && \
	yum install -y postgresql93 && \
	yum install -y gettext && \
	curl -s http://sebastien.godard.pagesperso-orange.fr/sysstat-11.1.4.tar.gz -o /tmp/sysstat-11.1.4.tar.gz && \
	tar zxf /tmp/sysstat-11.1.4.tar.gz -C /tmp && \
	cd /tmp/sysstat-11.1.4;./configure 2>&1;make 2>&1;make install && \
	rm -rf /tmp/sysstat-11.1.4 && \
	chmod -R 600 /root/.ssh && \
	cpanm YAML && \
	cpanm Config::Simple && \
	cpanm String::Util && \
	cpanm Statistics::Descriptive && \
	cpanm Moose && \
	cpanm MooseX::Storage && \
	cpanm Tie::IxHash && \
	cpanm MooseX::ClassAttribute && \
	cpanm MooseX::Types && \
	cpanm JSON && \
	cpanm Switch && \
	cpanm Log::Log4perl && \
	cpanm Log::Dispatch::File && \
	cpanm LWP 


ENTRYPOINT ["perl", "/root/weathervane/runHarness/weathervane.pl"]

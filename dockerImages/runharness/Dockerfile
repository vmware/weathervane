FROM hrosenbe/weathervane-centos7:2.0.0
MAINTAINER hrosenbe@vmware.com

COPY kubernetes.repo /etc/yum.repos.d/kubernetes.repo
COPY weathervane.pl /root/weathervane/weathervane.pl
COPY runHarness /root/weathervane/runHarness
COPY workloadConfiguration /root/weathervane/workloadConfiguration
COPY configFiles /root/weathervane/configFiles
COPY ssh /root/.ssh
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
	cpanm -n --mirror http://cpan.cpantesters.org YAML && \
	cpanm -n --mirror http://cpan.cpantesters.org Config::Simple && \
	cpanm -n --mirror http://cpan.cpantesters.org String::Util && \
	cpanm -n --mirror http://cpan.cpantesters.org Statistics::Descriptive && \
	cpanm -n --mirror http://cpan.cpantesters.org Moose && \
	cpanm -n --mirror http://cpan.cpantesters.org MooseX::Storage && \
	cpanm -n --mirror http://cpan.cpantesters.org Tie::IxHash && \
	cpanm -n --mirror http://cpan.cpantesters.org MooseX::ClassAttribute && \
	cpanm -n --mirror http://cpan.cpantesters.org MooseX::Types && \
	cpanm -n --mirror http://cpan.cpantesters.org JSON && \
	cpanm -n --mirror http://cpan.cpantesters.org Switch && \
	cpanm -n --mirror http://cpan.cpantesters.org Log::Log4perl && \
	cpanm -n --mirror http://cpan.cpantesters.org Log::Dispatch::File && \
	cpanm -n --mirror http://cpan.cpantesters.org LWP 


ENTRYPOINT ["perl", "/root/weathervane/weathervane.pl"]

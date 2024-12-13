# Copyright 2017-2019 VMware, Inc.
# SPDX-License-Identifier: BSD-2-Clause
FROM namespace/weathervane-baseos:version

COPY weathervane.pl /root/weathervane/weathervane.pl
COPY runHarness /root/weathervane/runHarness
COPY workloadConfiguration /root/weathervane/workloadConfiguration
COPY configFiles /root/weathervane/configFiles
COPY Notice.txt /root/weathervane/Notice.txt
COPY version.txt /root/weathervane/version.txt

ENV  JAVA_HOME /usr/lib/jvm/java-1.8.0	
ARG http_proxy

RUN \
	apt-get update && \
	apt-get -y install cpanminus && \
	apt-get -y install lynx && \
	apt-get -y install gcc && \
	apt-get -y install gettext && \

	apt-get -y install lsb-release && \
	curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor > /usr/share/keyrings/docker-archive-keyring.gpg && \
	echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && \

	curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.31/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
	chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
	echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.31/deb/ /" | sudo tee /etc/apt/sources.list.d/kubernetes.list && \
	chmod 644 /etc/apt/sources.list.d/kubernetes.list && \

	apt-get update && \
	apt-get -y install --no-install-recommends docker-ce docker-ce-cli containerd.io && \
	apt-get -y install kubectl && \

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
	cpanm -n LWP && \

	apt-get autoremove -y && \
	apt-get clean && \
	rm -rf /var/lib/apt/lists/*

ENTRYPOINT ["perl", "/root/weathervane/weathervane.pl"]

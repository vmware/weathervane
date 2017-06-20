/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
package com.vmware.weathervane.workloadDriver.common.model.target;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.factory.UserFactory;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

@JsonTypeName(value = "http")
public class HttpTarget extends Target {
	private static final Logger logger = LoggerFactory.getLogger(HttpTarget.class);

	private String hostname;
	private Boolean sslEnabled = true;
	private Integer httpPort = 80;
	private String httpScheme = "http";
	private Integer httpsPort = 443;
	private String httpsScheme = "https";

	@Override
	public void initialize(String workloadName,	long maxUsers, Integer nodeNumber, Integer numNodes, 
			UserFactory userFactory, StatsCollector statsCollector) {
		super.initialize(workloadName, maxUsers, nodeNumber, numNodes, userFactory, statsCollector);
	}

	public String getHostname() {
		return hostname;
	}
	public void setHostname(String hostname) {
		this.hostname = hostname;
	}
	public Boolean getSslEnabled() {
		return sslEnabled;
	}
	public void setSslEnabled(Boolean sslEnabled) {
		this.sslEnabled = sslEnabled;
	}

	public Integer getHttpPort() {
		return httpPort;
	}

	public void setHttpPort(Integer httpPort) {
		this.httpPort = httpPort;
	}

	public String getHttpScheme() {
		return httpScheme;
	}

	public void setHttpScheme(String httpScheme) {
		this.httpScheme = httpScheme;
	}

	public Integer getHttpsPort() {
		return httpsPort;
	}

	public void setHttpsPort(Integer httpsPort) {
		this.httpsPort = httpsPort;
	}

	public String getHttpsScheme() {
		return httpsScheme;
	}

	public void setHttpsScheme(String httpsScheme) {
		this.httpsScheme = httpsScheme;
	}
	
	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("HttpTarget: ");
		theStringBuilder.append("; workloadName: " + getWorkloadName()); 
		theStringBuilder.append("; hostname: " + hostname); 
		theStringBuilder.append("; sslEnabled: " + sslEnabled); 
		theStringBuilder.append("; httpPort: " + httpPort); 
		theStringBuilder.append("; httpScheme: " + httpScheme); 
		theStringBuilder.append("; httpsPort: " + httpsPort); 
		theStringBuilder.append("; httpsScheme: " + httpsScheme); 
 		
		return theStringBuilder.toString();
	}
}

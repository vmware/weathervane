/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.target;

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
	public void initialize(String workloadName,	long maxUsers, Integer nodeNumber, Integer numNodes, Integer targetNum, Integer numTargets, 
			UserFactory userFactory, StatsCollector statsCollector) {
		super.initialize(workloadName, maxUsers, nodeNumber, numNodes, targetNum, numTargets, userFactory, statsCollector);
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

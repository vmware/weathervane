/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "ramp")
public class RampLoadInterval extends LoadInterval {
	private Long startUsers = null;
	private Long endUsers = null;
	private Long timeStep = 15L;
	
	public Long getStartUsers() {
		return startUsers;
	}


	public void setStartUsers(Long startUsers) {
		this.startUsers = startUsers;
	}


	public Long getEndUsers() {
		return endUsers;
	}


	public void setEndUsers(Long endUsers) {
		this.endUsers = endUsers;
	}


	public Long getTimeStep() {
		return timeStep;
	}


	public void setTimeStep(Long timeStep) {
		this.timeStep = timeStep;
	}


	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("RampLoadInterval: ");
		theStringBuilder.append("name: " + getName()); 
		theStringBuilder.append("; duration: " + getDuration()); 
		theStringBuilder.append("; startUsers: " + startUsers); 
		theStringBuilder.append("; endUsers: " + endUsers); 
		theStringBuilder.append("; timeStep: " + timeStep); 
		
		return theStringBuilder.toString();
	}

}

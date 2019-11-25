/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "uniform")
public class UniformLoadInterval extends LoadInterval {
	private long users;
	
	@JsonIgnore
	private boolean endOfStatsInterval = false;
	
	public UniformLoadInterval() {
		
	}
	
	public UniformLoadInterval(UniformLoadInterval that) {
		this.users = that.users;
		this.setDuration(that.getDuration());
	}

	public UniformLoadInterval(long users, long duration) {
		this.users = users;
		this.setDuration(duration);
	}
	
	public long getUsers() {
		return users;
	}
	public void setUsers(long users) {
		this.users = users;
	}
	
	public boolean isEndOfStatsInterval() {
		return endOfStatsInterval;
	}

	public void setEndOfStatsInterval(boolean endOfStatsInterval) {
		this.endOfStatsInterval = endOfStatsInterval;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("UniformLoadInterval: ");
		theStringBuilder.append("; duration: " + getDuration()); 
		theStringBuilder.append("; users: " + users); 
		
		return theStringBuilder.toString();
	}

}

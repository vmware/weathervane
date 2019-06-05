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
package com.vmware.weathervane.workloadDriver.common.core;

import java.util.List;

import com.vmware.weathervane.workloadDriver.common.core.loadPath.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

public class WorkloadStatus {

	private String name;

	private Workload.WorkloadState state;

	private RampLoadInterval curInterval;
	
	private String maxPassIntervalName;
	
	private long maxPassUsers;

	private boolean passed;

	private List<StatsSummaryRollup> intervalStatsSummaries;
	
	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}


	public Workload.WorkloadState getState() {
		return state;
	}


	public void setState(Workload.WorkloadState state) {
		this.state = state;
	}


	public String getMaxPassIntervalName() {
		return maxPassIntervalName;
	}

	public void setMaxPassIntervalName(String maxPassIntervalName) {
		this.maxPassIntervalName = maxPassIntervalName;
	}

	public long getMaxPassUsers() {
		return maxPassUsers;
	}


	public void setMaxPassUsers(long maxPassUsers) {
		this.maxPassUsers = maxPassUsers;
	}


	public boolean isPassed() {
		return passed;
	}


	public void setPassed(boolean passed) {
		this.passed = passed;
	}

	public List<StatsSummaryRollup> getIntervalStatsSummaries() {
		return intervalStatsSummaries;
	}

	public void setIntervalStatsSummaries(List<StatsSummaryRollup> intervalStatsSummaries) {
		this.intervalStatsSummaries = intervalStatsSummaries;
	}

	public RampLoadInterval getCurInterval() {
		return curInterval;
	}

	public void setCurInterval(RampLoadInterval curInterval) {
		this.curInterval = curInterval;
	}

}

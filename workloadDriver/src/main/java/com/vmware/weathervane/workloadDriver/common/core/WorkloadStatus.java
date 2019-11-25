/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core;

import java.util.List;

import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

public class WorkloadStatus {

	private String name;

	private Workload.WorkloadState state;

	private RampLoadInterval curInterval;
	
	private String maxPassIntervalName;
	
	private String loadPathName;
	
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

	public String getLoadPathName() {
		return loadPathName;
	}

	public void setLoadPathName(String loadPathName) {
		this.loadPathName = loadPathName;
	}

}

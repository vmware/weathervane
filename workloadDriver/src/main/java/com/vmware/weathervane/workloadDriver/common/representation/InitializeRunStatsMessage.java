/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

import java.util.List;
import java.util.Map;

public class InitializeRunStatsMessage {

	private String runName;
	private List<String> hosts;
	private String statsOutputDirName;
	private Map<String, Integer> workloadNameToNumTargetsMap;
	private Boolean isPerTargetStats;
	
	public List<String> getHosts() {
		return hosts;
	}

	public void setHosts(List<String> hosts) {
		this.hosts = hosts;
	}
	
	public String getStatsOutputDirName() {
		return statsOutputDirName;
	}

	public void setStatsOutputDirName(String statsOutputDirName) {
		this.statsOutputDirName = statsOutputDirName;
	}

	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("InitializeRunStatsMessage: hosts = ");
		for (String name : hosts) {
			retVal.append(name + ", ");
		}
		retVal.append(", runName = " + runName);
		retVal.append(", statsOutputDirName = " + statsOutputDirName);
		for (String workloadName : workloadNameToNumTargetsMap.keySet()) {
			retVal.append(", workload " + workloadName + " has " + workloadNameToNumTargetsMap.get(workloadName)
			+ " targets");
		}
		return retVal.toString();
	}

	public String getRunName() {
		return runName;
	}

	public void setRunName(String runName) {
		this.runName = runName;
	}

	public Map<String, Integer> getWorkloadNameToNumTargetsMap() {
		return workloadNameToNumTargetsMap;
	}

	public void setWorkloadNameToNumTargetsMap(Map<String, Integer> workloadNameToNumTargetsMap) {
		this.workloadNameToNumTargetsMap = workloadNameToNumTargetsMap;
	}

	public Boolean getIsPerTargetStats() {
		return isPerTargetStats;
	}

	public void setIsPerTargetStats(Boolean isPerTargetStats) {
		this.isPerTargetStats = isPerTargetStats;
	}
	
}

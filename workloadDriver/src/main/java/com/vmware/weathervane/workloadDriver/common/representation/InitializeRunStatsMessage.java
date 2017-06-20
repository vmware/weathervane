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
package com.vmware.weathervane.workloadDriver.common.representation;

import java.util.List;
import java.util.Map;

public class InitializeRunStatsMessage {

	private String runName;
	private List<String> hosts;
	private String statsOutputDirName;
	private Map<String, Integer> workloadNameToNumTargetsMap;
	
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
	
}

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

public class InitializeWorkloadStatsMessage {

	private String workloadName;
	private List<String> targetNames;
	private List<String> statsIntervalSpecNames;

	public String getWorkloadName() {
		return workloadName;
	}

	public void setWorkloadName(String workloadName) {
		this.workloadName = workloadName;
	}

	public List<String> getTargetNames() {
		return targetNames;
	}

	public void setTargetNames(List<String> targetNames) {
		this.targetNames = targetNames;
	}
	
	public List<String> getStatsIntervalSpecNames() {
		return statsIntervalSpecNames;
	}

	public void setStatsIntervalSpecNames(List<String> statsIntervalSpecNames) {
		this.statsIntervalSpecNames = statsIntervalSpecNames;
	}

	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("InitializeWorkloadStatsMessage: workload = " + workloadName
				+ ", targets = ");
		for (String targetName : targetNames) {
			retVal.append(targetName + ", ");
		}
		
		return retVal.toString();
	}
	
}

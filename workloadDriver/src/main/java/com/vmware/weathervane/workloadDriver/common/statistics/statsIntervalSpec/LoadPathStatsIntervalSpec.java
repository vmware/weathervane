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
package com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.model.loadPath.LoadInterval;
import com.vmware.weathervane.workloadDriver.common.model.loadPath.LoadPath;

@JsonTypeName(value = "loadpath")
public class LoadPathStatsIntervalSpec extends StatsIntervalSpec {
	private String loadPathName = null;

	@JsonIgnore
	private LoadPath loadPath;
	
	@JsonIgnore
	@Override
	protected long getNextInterval() {
		LoadInterval interval = loadPath.getNextStatsInterval(getName());
		setCurIntervalName(interval.getName());

		
		return interval.getDuration();
	}

	public String getLoadPathName() {
		return loadPathName;
	}

	public void setLoadPathName(String loadPathName) {
		this.loadPathName = loadPathName;
	}

	public LoadPath getLoadPath() {
		return loadPath;
	}

	public void setLoadPath(LoadPath loadPath) {
		this.loadPath = loadPath;
	}
	
	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("FixedStatsIntervalSpec: name = " + getName());
		retVal.append(", printSummary = " + getPrintSummary());
		retVal.append(", printIntervals = " + getPrintIntervals());
		retVal.append(", loadPathName = " + loadPathName);
		
		return retVal.toString();
	}

}

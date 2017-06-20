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

import java.util.List;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "fixed")
public class FixedStatsIntervalSpec extends StatsIntervalSpec {
	private List<StatsInterval> intervals = null;

	@JsonIgnore
	private int nextIntervalNum = 0;
	
	public List<StatsInterval> getIntervals() {
		return intervals;
	}

	public void setIntervals(List<StatsInterval> intervals) {
		this.intervals = intervals;
	}

	@JsonIgnore
	@Override
	protected StatsInterval getNextInterval() {
		if (intervals == null) {
			return null;
		}
		
		StatsInterval returnInterval = null;
		if (nextIntervalNum <= (intervals.size() - 1)) {
			returnInterval = intervals.get(nextIntervalNum);
		}
		
		nextIntervalNum++;
		
		return returnInterval;
	}
	
	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("FixedStatsIntervalSpec: name = " + getName());
		retVal.append(", printSummary = " + getPrintSummary());
		retVal.append(", printIntervals = " + getPrintIntervals());
		retVal.append(", numIntervals = " + intervals.size());
		
		return retVal.toString();
	}
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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

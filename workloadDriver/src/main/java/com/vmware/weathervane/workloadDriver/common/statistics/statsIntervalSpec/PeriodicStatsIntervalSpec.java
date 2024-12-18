/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "periodic")
public class PeriodicStatsIntervalSpec extends StatsIntervalSpec {
	private static final Logger logger = LoggerFactory.getLogger(PeriodicStatsIntervalSpec.class);

	private Long period = null;

	@JsonIgnore
	private long intervalCount = 1;
	
	public Long getPeriod() {
		return period;
	}

	public void setPeriod(Long period) {
		this.period = period;
	}

	@JsonIgnore
	@Override
	protected StatsInterval getNextInterval() {
		StatsInterval nextInterval = new StatsInterval();
		nextInterval.setDuration(period);
		nextInterval.setName(Long.toString(intervalCount));
		intervalCount++;
		logger.debug("getNextInterval returning interval with duration = " + nextInterval.getDuration() + ", name = " + nextInterval.getName());
		return nextInterval;
	}
	
	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("FixedStatsIntervalSpec: name = " + getName());
		retVal.append(", printSummary = " + getPrintSummary());
		retVal.append(", printIntervals = " + getPrintIntervals());
		retVal.append(", period = " + period);
		
		return retVal.toString();
	}
}

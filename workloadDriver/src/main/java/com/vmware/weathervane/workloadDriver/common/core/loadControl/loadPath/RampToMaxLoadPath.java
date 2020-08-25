/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

import java.util.List;
import java.util.concurrent.ScheduledExecutorService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.UniformLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;

@JsonTypeName(value = "ramptomax")
public class RampToMaxLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(RampToMaxLoadPath.class);

	private long startUsers;
	private long maxUsers;
	private long stepSize;
	private long intervalDuration;
	private long rampIntervalDuration = 180;
	
	@JsonIgnore
	private boolean statsIntervalComplete = false;
		
	@JsonIgnore
	private UniformLoadInterval curStatsInterval = new UniformLoadInterval();

	@Override
	public void initialize(String runName, String workloadName, Workload workload, LoadPathController loadPathController,
			List<String> hosts, String statsHostName,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, loadPathController,
				hosts, statsHostName, restTemplate, executorService);

	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {

		logger.debug("getNextInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();

		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	@JsonIgnore
	@Override
	public boolean isStatsIntervalComplete() {
		return statsIntervalComplete;
	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getCurStatsInterval() {
		return curStatsInterval;
	}

	@Override
	public RampLoadInterval getCurStatusInterval() {
		return curStatusInterval;
	}

	public long getStartUsers() {
		return startUsers;
	}

	public void setStartUsers(long startUsers) {
		this.startUsers = startUsers;
	}

	public long getMaxUsers() {
		return maxUsers;
	}

	public void setMaxUsers(long maxUsers) {
		this.maxUsers = maxUsers;
	}

	public long getStepSize() {
		return stepSize;
	}

	public void setStepSize(long stepSize) {
		this.stepSize = stepSize;
	}

	public long getIntervalDuration() {
		return intervalDuration;
	}

	public void setIntervalDuration(long intervalDuration) {
		this.intervalDuration = intervalDuration;
	}

	public long getRampIntervalDuration() {
		return rampIntervalDuration;
	}

	public void setRampIntervalDuration(long rampIntervalDuration) {
		this.rampIntervalDuration = rampIntervalDuration;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}

}

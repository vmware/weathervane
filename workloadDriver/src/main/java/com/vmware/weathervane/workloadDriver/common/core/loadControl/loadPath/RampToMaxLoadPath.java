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
			List<String> hosts, String statsHostName, int portNumber,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, loadPathController,
				hosts, statsHostName, portNumber, restTemplate, executorService);

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
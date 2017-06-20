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
package com.vmware.weathervane.workloadDriver.common.model.loadPath;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "fixed")
public class FixedLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FixedLoadPath.class);

	private long users;

	private long rampUp;
	private long steadyState;
	private long rampDown;

	private long timeStep = 15L;

	@JsonIgnore
	private List<UniformLoadInterval> uniformIntervals = null;

	@JsonIgnore
	private int nextIntervalIndex = 0;

	@JsonIgnore
	private int nextStatsIntervalIndex = 0;

	@Override
	public void initialize(String runName, String workloadName, List<String> hosts, int portNumber,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, hosts, portNumber, restTemplate, executorService);

		uniformIntervals = new ArrayList<UniformLoadInterval>();

		/*
		 * Create a list of uniform intervals from time periods
		 */
		long numIntervals = (long) Math.ceil(rampUp / (timeStep * 1.0));
		long startUsers = (long) Math.ceil(Math.abs(users) / ((numIntervals - 1) * 1.0));
		uniformIntervals.addAll(generateRampIntervals("rampUp", rampUp, timeStep, startUsers, users));
		
		UniformLoadInterval steadyInterval = new UniformLoadInterval();
		steadyInterval.setDuration(steadyState);
		steadyInterval.setUsers(users);
		steadyInterval.setName("steadyState");
		uniformIntervals.add(steadyInterval);
		
		numIntervals = (long) Math.ceil(rampDown / (timeStep * 1.0));
		uniformIntervals.addAll(generateRampIntervals("rampDown", rampDown, timeStep, users, 0));		

	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {

		logger.debug("getNextInterval, nextIntervalIndex = " + nextIntervalIndex);
		if ((uniformIntervals == null) || (uniformIntervals.size() == 0)) {
			logger.debug("getNextInterval returning null");
			return null;
		}

		/*
		 * wrap at end of intervals
		 */
		if (nextIntervalIndex >= uniformIntervals.size()) {
			nextIntervalIndex = 0;
		}

		UniformLoadInterval nextInterval = uniformIntervals.get(nextIntervalIndex);
		nextIntervalIndex++;

		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	@JsonIgnore
	@Override
	public LoadInterval getNextStatsInterval() {
		logger.debug("getNextStatsInterval, nextStatsIntervalIndex = " + nextStatsIntervalIndex);
		UniformLoadInterval nextStatsInterval = new UniformLoadInterval();

		if (nextStatsIntervalIndex == 0) {
			nextStatsInterval.setName("rampUp");
			nextStatsInterval.setDuration(rampUp);
			nextStatsInterval.setUsers(users);
		} else if (nextStatsIntervalIndex == 1) {
			nextStatsInterval.setName("steadyState");
			nextStatsInterval.setDuration(steadyState);
			nextStatsInterval.setUsers(users);
		} else  {
			nextStatsInterval.setName("rampDown");
			nextStatsInterval.setDuration(rampDown);
			nextStatsInterval.setUsers(users);
		} 

		nextStatsIntervalIndex++;

		logger.debug("getNextStatsInterval returning interval: " + nextStatsInterval);
		return nextStatsInterval;
	}


	public long getUsers() {
		return users;
	}

	public void setUsers(long users) {
		this.users = users;
	}

	public long getRampUp() {
		return rampUp;
	}

	public void setRampUp(long rampUp) {
		this.rampUp = rampUp;
	}

	public long getSteadyState() {
		return steadyState;
	}

	public void setSteadyState(long steadyState) {
		this.steadyState = steadyState;
	}

	public long getRampDown() {
		return rampDown;
	}

	public void setRampDown(long rampDown) {
		this.rampDown = rampDown;
	}

	public long getTimeStep() {
		return timeStep;
	}

	public void setTimeStep(long timeStep) {
		this.timeStep = timeStep;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}

}

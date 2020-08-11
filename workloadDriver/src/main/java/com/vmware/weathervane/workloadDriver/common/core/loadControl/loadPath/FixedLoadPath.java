/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.UniformLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "fixed")
public class FixedLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FixedLoadPath.class);

	private long users;

	private long rampUp = 240;
	private long warmUp = 300;
	private long numQosPeriods = 3;
	private long qosPeriodSec = 300;
	private long rampDown = 120;
	private boolean runForever = false;
	private boolean exitOnFirstFailure = false;
	
	private long timeStep = 10L;

	/*
	 * Phases in a findMax run: 
	 * - RAMPUP: Ramp up to users in timeStep intervals
	 * - QOS: Use intervals of qosPeriodSec.  if any fail then the run fails.
	 * - RAMPDOWN: End of run period used to avoid getting shut-down effects in QOS 
	 * - POSTRUN: Periods of qosPeriodSec after RAMPDOWN which are returned if other workloads are still running.
	 */
	private enum Phase {
		RAMPUP, WARMUP, QOS, RAMPDOWN, POSTRUN
	};

	@JsonIgnore
	private Phase curPhase = Phase.RAMPUP;

	@JsonIgnore
	private LinkedList<UniformLoadInterval> rampupIntervals = null;
	
	@JsonIgnore
	private long curPhaseInterval = 0;
	
	@JsonIgnore
	private boolean passedQos = true;

	@JsonIgnore
	private String firstFailIntervalName = null;
	
	@JsonIgnore
	private boolean statsIntervalComplete = false;
		
	@JsonIgnore
	private UniformLoadInterval curStatsInterval;

	@Override
	public void initialize(String runName, String workloadName, Workload workload, LoadPathController loadPathController,
			List<String> hosts, String statsHostName, int portNumber,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, loadPathController,
				hosts, statsHostName, portNumber, restTemplate, executorService);

		/*
		 * Create a list of uniform intervals for rampup. 
		 */
		rampupIntervals = new LinkedList<UniformLoadInterval>();
		long numIntervals = (long) Math.ceil(rampUp / (timeStep * 1.0));
		long startUsers = (long) Math.ceil(Math.abs(users) / ((numIntervals - 1) * 1.0));
		rampupIntervals.addAll(generateRampIntervals("rampUp", rampUp, timeStep, startUsers, users));
		
		curStatusInterval.setName("RampUp");
		curStatusInterval.setDuration(rampUp);
		curStatusInterval.setStartUsers(0L);
		curStatusInterval.setEndUsers(users);
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
	
	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {
		statsIntervalComplete = false;

		UniformLoadInterval nextInterval = null;
		if (Phase.RAMPUP.equals(curPhase)) {
			if (rampupIntervals.isEmpty()) {
				curPhase  = Phase.WARMUP;
				curPhaseInterval = 0;
				nextInterval = getNextInterval();
			} else {
				nextInterval = rampupIntervals.pop();
				if (rampupIntervals.isEmpty()) {
					statsIntervalComplete = true;
					curStatsInterval = new UniformLoadInterval();
					curStatsInterval.setName("RampUp");
					curStatsInterval.setDuration(rampUp);
					curStatsInterval.setUsers(users);
				}
			}
		} else if (Phase.WARMUP.equals(curPhase)) {
			if (curPhaseInterval == 0 ) {
				nextInterval = new UniformLoadInterval();
				nextInterval.setName("WARMUP-" + curPhaseInterval);
				nextInterval.setDuration(warmUp);
				nextInterval.setUsers(users);

				statsIntervalComplete = true;
				curStatusInterval.setName("WARMUP-" + curPhaseInterval);
				curStatusInterval.setDuration(warmUp);
				curStatusInterval.setStartUsers(users);
				curStatusInterval.setEndUsers(users);
				curStatsInterval = nextInterval;
				
				curPhaseInterval++;
			} else {
				curPhase  = Phase.QOS;
				curPhaseInterval = 0;
				nextInterval = getNextInterval();
			}
		} else if (Phase.QOS.equals(curPhase)) {
			boolean prevIntervalPassed = true;
			if (curPhaseInterval != 0) {
				/*
				 * This is the not first interval. Need to know whether the previous interval
				 * passed. Get the statsSummaryRollup for the previous interval
				 */
				StatsSummaryRollup rollup = fetchStatsSummaryRollup("QOS-" + curPhaseInterval);
				if (rollup != null) {
					getIntervalStatsSummaries().add(rollup);
					prevIntervalPassed = rollup.isIntervalPassed();
					if (!prevIntervalPassed) {
						// Run failed. 
						passedQos = false;
						if (firstFailIntervalName == null) {
							firstFailIntervalName = "QOS-" + curPhaseInterval;
						}
						if (isExitOnFirstFailure()) {
							curPhase = Phase.RAMPDOWN;
							curPhaseInterval = 0;
							return getNextInterval();
						}
					} 
				} else {
					logger.warn("Failed to get rollup for interval QOS-" + curPhaseInterval);
				}
			}
			
			if (!runForever && (curPhaseInterval >= getNumQosPeriods())) {
				// If runForever, never enter rampDown
				// Last QOS period completed.  Move to rampDown
				curPhase = Phase.RAMPDOWN;
				curPhaseInterval = 0;
				nextInterval = getNextInterval();
			} else {
				curPhaseInterval++;
				nextInterval = new UniformLoadInterval();
				nextInterval.setName("QOS-" + curPhaseInterval);
				nextInterval.setDuration(getQosPeriodSec());
				nextInterval.setUsers(users);

				curStatusInterval.setName("QOS-" + curPhaseInterval);
				curStatusInterval.setDuration(qosPeriodSec);
				curStatusInterval.setStartUsers(users);
				curStatusInterval.setEndUsers(users);

				statsIntervalComplete = true;
				curStatsInterval = nextInterval;
			}	
		} else if (Phase.RAMPDOWN.equals(curPhase)) {
			nextInterval = new UniformLoadInterval();
			nextInterval.setName("rampDown");
			nextInterval.setDuration(rampDown);
			nextInterval.setUsers(users);

			statsIntervalComplete = true;
			curStatsInterval = new UniformLoadInterval();
			curStatsInterval.setName("RampDown");
			curStatsInterval.setDuration(rampDown);
			curStatsInterval.setUsers(users);

			curStatusInterval.setName("RampDown");
			curStatusInterval.setDuration(rampDown);
			curStatusInterval.setStartUsers(users);
			curStatusInterval.setEndUsers(users);

			curPhaseInterval = 0;
			curPhase = Phase.POSTRUN;
		} else if (Phase.POSTRUN.equals(curPhase)) {
			if (curPhaseInterval == 0) {
				// Run finished
				WorkloadStatus status = new WorkloadStatus();
				status.setIntervalStatsSummaries(getIntervalStatsSummaries());
				status.setMaxPassUsers(users);
				if (passedQos) {
					status.setMaxPassIntervalName("QOS-1");
				} else {
					status.setMaxPassIntervalName(firstFailIntervalName);					
				}
				status.setPassed(passedQos);
				status.setLoadPathName(this.getName());
				workload.loadPathComplete(status);
			}
			curPhaseInterval++;
			nextInterval = new UniformLoadInterval();
			nextInterval.setName("PostRun-" + curPhaseInterval);
			nextInterval.setDuration(getQosPeriodSec());
			nextInterval.setUsers(users);

			curStatusInterval.setName("PostRun-" + curPhaseInterval);
			curStatusInterval.setDuration(qosPeriodSec);
			curStatusInterval.setStartUsers(users);
			curStatusInterval.setEndUsers(users);
		} 
		
		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	@Override
	public RampLoadInterval getCurStatusInterval() {
		return curStatusInterval;
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

	public long getRampDown() {
		return rampDown;
	}

	public void setRampDown(long rampDown) {
		this.rampDown = rampDown;
	}

	public long getWarmUp() {
		return warmUp;
	}

	public void setWarmUp(long warmUp) {
		this.warmUp = warmUp;
	}

	public long getTimeStep() {
		return timeStep;
	}

	public void setTimeStep(long timeStep) {
		this.timeStep = timeStep;
	}

	public void setNumQosPeriods(long numQosPeriods) {
		this.numQosPeriods = numQosPeriods;
	}

	public long getNumQosPeriods() {
		return numQosPeriods;
	}

	public void setQosPeriodSec(long qosPeriodSec) {
		this.qosPeriodSec = qosPeriodSec;
	}

	public long getQosPeriodSec() {
		return qosPeriodSec;
	}

	public boolean isExitOnFirstFailure() {
		return exitOnFirstFailure;
	}

	public void setExitOnFirstFailure(boolean exitOnFirstFailure) {
		this.exitOnFirstFailure = exitOnFirstFailure;
	}

	public boolean isRunForever() {
		return runForever;
	}

	public void setRunForever(boolean runForever) {
		this.runForever = runForever;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}
}

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
package com.vmware.weathervane.workloadDriver.common.core.loadPath;

import java.util.LinkedList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "fixed")
public class FixedLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FixedLoadPath.class);

	private long users;

	private long rampUp;
	private long numQosPeriods = 3;
	private long qosPeriodSec = 300;
	private long rampDown;

	private long timeStep = 10L;

	/*
	 * Phases in a findMax run: 
	 * - RAMPUP: Ramp up to users in timeStep intervals
	 * - QOS: Use intervals of qosPeriodSec.  if any fail then the run fails.
	 * - RAMPDOWN: End of run period used to avoid getting shut-down effects in QOS 
	 * - POSTPASS: Periods of qosPeriodSec after RAMPDOWN which are returned if other workloads are still running.
	 * - POSTFAIL: Periods of qosPeriodSec after RAMPDOWN which are returned if other workloads are still running.
	 */
	private enum Phase {
		RAMPUP, QOS, RAMPDOWN, POSTPASS, POSTFAIL
	};

	@JsonIgnore
	private Phase curPhase = Phase.RAMPUP;

	@JsonIgnore
	private LinkedList<UniformLoadInterval> rampupIntervals = null;
	
	@JsonIgnore
	private long curPhaseInterval = 0;

	/*
	 * Use a semaphore to prevent returning stats interval until we have determined
	 * the next load interval
	 */
	@JsonIgnore
	private final Semaphore statsIntervalAvailable = new Semaphore(0, true);
	
	@JsonIgnore
	private UniformLoadInterval curStatsInterval;

	@Override
	public void initialize(String runName, String workloadName, Workload workload, List<String> hosts, String statsHostName, int portNumber,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, hosts, statsHostName, portNumber, restTemplate, executorService);

		/*
		 * Create a list of uniform intervals from time periods
		 */
		rampupIntervals = new LinkedList<UniformLoadInterval>();
		long numIntervals = (long) Math.ceil(rampUp / (timeStep * 1.0));
		long startUsers = (long) Math.ceil(Math.abs(users) / ((numIntervals - 1) * 1.0));
		rampupIntervals.addAll(generateRampIntervals("rampUp", rampUp, timeStep, startUsers, users));
		
		curStatsInterval = new UniformLoadInterval();
		curStatsInterval.setName("rampUp");
		curStatsInterval.setDuration(rampUp);
		curStatsInterval.setUsers(users);
		statsIntervalAvailable.release();

		curStatusInterval.setName("rampUp");
		curStatusInterval.setDuration(rampUp);
		curStatusInterval.setStartUsers(0L);
		curStatusInterval.setEndUsers(users);
	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {

		UniformLoadInterval nextInterval = null;
		if (Phase.RAMPUP.equals(curPhase)) {
			if (rampupIntervals.isEmpty()) {
				curPhase  = Phase.QOS;
				curPhaseInterval = 0;
				nextInterval = getNextInterval();
			} else {
				nextInterval = rampupIntervals.pop();
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
					prevIntervalPassed = rollup.isIntervalPassed();
					getIntervalStatsSummaries().add(rollup);
				} else {
					logger.warn("Failed to get rollup for interval QOS-" + curPhaseInterval);
				}
			}
			if (!prevIntervalPassed) {
				// Run failed. 
				WorkloadStatus status = new WorkloadStatus();
				status.setIntervalStatsSummaries(getIntervalStatsSummaries());
				status.setMaxPassUsers(users);
				status.setMaxPassIntervalName("QOS-" + curPhaseInterval);
				status.setPassed(prevIntervalPassed);
				workload.loadPathComplete(status);
				curPhaseInterval = 0;
				curPhase = Phase.POSTFAIL;
				nextInterval = getNextInterval();
			} else if (curPhaseInterval >= getNumQosPeriods()) {
				// Last QOS period passed.  Move to rampDown
				curPhase = Phase.RAMPDOWN;
				curPhaseInterval = 0;
				curStatsInterval.setName("rampDown");
				curStatsInterval.setDuration(rampDown);
				curStatsInterval.setUsers(users);
				statsIntervalAvailable.release();
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

				curStatsInterval = nextInterval;
				statsIntervalAvailable.release();						
			}	
		} else if (Phase.RAMPDOWN.equals(curPhase)) {
			nextInterval = new UniformLoadInterval();
			nextInterval.setName("rampDown");
			nextInterval.setDuration(rampDown);
			nextInterval.setUsers(users);

			curStatusInterval.setName("RampDown");
			curStatusInterval.setDuration(rampDown);
			curStatusInterval.setStartUsers(users);
			curStatusInterval.setEndUsers(users);

			curPhaseInterval = 0;
			curPhase = Phase.POSTPASS;
		} else if (Phase.POSTPASS.equals(curPhase)) {
			if (curPhaseInterval == 0) {
				// Run passed. 
				WorkloadStatus status = new WorkloadStatus();
				status.setIntervalStatsSummaries(getIntervalStatsSummaries());
				status.setMaxPassUsers(users);
				status.setMaxPassIntervalName("QOS");
				status.setPassed(true);
				workload.loadPathComplete(status);
			}
			curPhaseInterval++;
			nextInterval = new UniformLoadInterval();
			nextInterval.setName("postPass-" + curPhaseInterval);
			nextInterval.setDuration(getQosPeriodSec());
			nextInterval.setUsers(users);

			curStatusInterval.setName("PostPass-" + curPhaseInterval);
			curStatusInterval.setDuration(qosPeriodSec);
			curStatusInterval.setStartUsers(users);
			curStatusInterval.setEndUsers(users);
		} else if (Phase.POSTFAIL.equals(curPhase)) {
			if (curPhaseInterval == 0) {
				// Run failed. 
				WorkloadStatus status = new WorkloadStatus();
				status.setIntervalStatsSummaries(getIntervalStatsSummaries());
				status.setMaxPassUsers(users);
				status.setMaxPassIntervalName("QOS");
				status.setPassed(false);
				workload.loadPathComplete(status);
			}
			curPhaseInterval++;
			nextInterval = new UniformLoadInterval();
			nextInterval.setName("postFail-" + curPhaseInterval);
			nextInterval.setDuration(getQosPeriodSec());
			nextInterval.setUsers(users);

			curStatusInterval.setName("PostFail-" + curPhaseInterval);
			curStatusInterval.setDuration(qosPeriodSec);
			curStatusInterval.setStartUsers(users);
			curStatusInterval.setEndUsers(users);
		}
		
		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	@JsonIgnore
	@Override
	public LoadInterval getNextStatsInterval() {
		logger.debug("getNextStatsInterval");

		statsIntervalAvailable.acquireUninterruptibly();
		logger.debug("getNextStatsInterval returning interval: " + curStatsInterval);
		return curStatsInterval;
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

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}
}

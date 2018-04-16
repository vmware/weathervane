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

import java.util.ArrayDeque;
import java.util.Deque;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.model.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "findmax")
public class FindMaxLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FindMaxLoadPath.class);

	private long maxUsers = 10000;

	/*
	 * Phases in a findMax run: - INITIALRAMP: Use short intervals to ramp up until
	 * response-times begin to fail - APPROXIMATE: Use medium intervals to get an
	 * estimate of the range in which the maximum falls. - NARROWIN: Use long
	 * intervals to narrow in on a final passing level - RAMPDOWN: Final ramp-down
	 * with small intervals to finish out run
	 */
	private enum Phase {
		INITIALRAMP, APPROXIMATE, NARROWIN, RAMPDOWN
	};

	@JsonIgnore
	private Phase curPhase = Phase.INITIALRAMP;

	/*
	 * Each interval in a in a findMax run has two sub-intervals: - WARMUP: Period
	 * used to let the users log in and get to a steady state - DECISION: Period
	 * used to decide whether the interval passes the QOS requirements of the phase.
	 */
	private enum SubInterval {
		RAMP, WARMUP, DECISION
	};

	@JsonIgnore
	private SubInterval nextSubInterval = SubInterval.WARMUP;

	@JsonIgnore
	private long curUsers = 0;

	@JsonIgnore
	private long intervalNum = 0;

	@JsonIgnore
	private UniformLoadInterval curInterval = null;

	@JsonIgnore
	Deque<UniformLoadInterval> rampIntervals = new ArrayDeque<UniformLoadInterval>();

	@JsonIgnore
	private long minFailUsers = Long.MAX_VALUE;
	@JsonIgnore
	private long maxPassUsers = 0;
	@JsonIgnore
	private String maxPassIntervalName = null;

	// The initial step is 1/20 of maxUsers
	@JsonIgnore
	private long curRateStep = maxUsers / 20;
	@JsonIgnore
	private final long initialRampRateStep = 250;
	@JsonIgnore
	private final long approximateMinRateStep = maxUsers / 50;
	@JsonIgnore
	private final long narrowinMinRateStep = maxUsers / 200;

	@JsonIgnore
	private final long shortWarmupIntervalDurationSec = 10;
	@JsonIgnore
	private final long shortIntervalDurationSec = 10;

	@JsonIgnore
	private final long mediumRampIntervalDurationSec = 180;
	@JsonIgnore
	private final long mediumWarmupIntervalDurationSec = 120;
	@JsonIgnore
	private final long mediumIntervalDurationSec = 300;

	@JsonIgnore
	private final long longRampIntervalDurationSec = 300;
	@JsonIgnore
	private final long longWarmupIntervalDurationSec = 120;
	@JsonIgnore
	private final long longIntervalDurationSec = 600;

	/*
	 * Use a semaphore to prevent returning stats interval until we have determined
	 * the next load interval
	 */
	@JsonIgnore
	private final Semaphore statsIntervalAvailable = new Semaphore(0, true);

	@Override
	public void initialize(String runName, String workloadName, Workload workload, List<String> hosts,
			String statsHostName, int portNumber, RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, hosts, statsHostName, portNumber, restTemplate,
				executorService);

	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {

		logger.debug("getNextInterval ");
		UniformLoadInterval nextInterval = null;
		switch (curPhase) {
		case INITIALRAMP:
			nextInterval = getNextInitialRampInterval();
			break;
		case APPROXIMATE:
			nextInterval = getNextApproximateInterval();
			break;
		case NARROWIN:
			nextInterval = getNextNarrowInInterval();
			break;
		case RAMPDOWN:
			nextInterval = getNextRampDownInterval();
			break;
		}

		curInterval = nextInterval;
		statsIntervalAvailable.release();
		return nextInterval;
	}

	@JsonIgnore
	private UniformLoadInterval getNextInitialRampInterval() {
		logger.debug("getNextInitialRampInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();
		if (nextSubInterval.equals(SubInterval.WARMUP) || nextSubInterval.equals(SubInterval.RAMP)) {
			// WARMUP starts a new interval
			intervalNum++;
			logger.debug("getNextInitialRampInterval warmup subinterval for interval " + intervalNum);

			/*
			 * Do the warmup interval for the current interval. If this is not the first
			 * interval then we need to select the number of users based on the results of
			 * the previous interval
			 */
			boolean prevIntervalPassed = true;
			if (intervalNum != 1) {
				String curIntervalName = curInterval.getName();

				/*
				 * This is the not first interval. Need to know whether the previous interval
				 * passed. Get the statsSummaryRollup for the previous interval
				 */
				StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);

				// For initial ramp, only interested in response-time
				if (rollup != null) {
					/*
					 * InitialRamp intervals pass if operations pass response-time QOS. The mix QoS
					 * is not used in initialRamp
					 */
					prevIntervalPassed = rollup.isIntervalPassedRT();
					getIntervalStatsSummaries().add(rollup);
				}
				logger.debug("getNextInitialRampInterval: Interval " + intervalNum + " prevIntervalPassed = "
						+ prevIntervalPassed);
			}

			/*
			 * If we have reached max users, or the previous interval failed, then to go to
			 * the APPROXIMATE phase
			 */
			if (!prevIntervalPassed || ((curUsers + curRateStep) > maxUsers)) {
				intervalNum = 0;
				curPhase = Phase.NARROWIN;
				// No ramp on first APPROXIMATE interval
				nextSubInterval = SubInterval.WARMUP;
				logger.debug("getNextInitialRampInterval: Moving to APPROXIMATE phase.  curUsers = " + curUsers
						+ ", curRateStep = " + curRateStep);
				return getNextNarrowInInterval();
			}

			curUsers += initialRampRateStep;
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(shortWarmupIntervalDurationSec);
			nextInterval.setName("InitialRamp-Warmup-" + intervalNum);
			nextSubInterval = SubInterval.DECISION;
		} else {
			logger.debug("getNextInitialRampInterval decision subinterval for interval " + intervalNum);
			/*
			 * Do the sub-interval used for decisions. This is run at the same number of
			 * users for the previous interval, but with the non-warmup duration
			 */
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(shortIntervalDurationSec);
			nextInterval.setName("InitialRamp-" + intervalNum);
			nextSubInterval = SubInterval.WARMUP;
		}

		logger.debug("getNextInitialRampInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	/*
	 * Narrow in on max passing until at 2*minRateStep
	 */
	@JsonIgnore
	private UniformLoadInterval getNextApproximateInterval() {
		logger.debug("getNextApproximateInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();
		if (nextSubInterval.equals(SubInterval.RAMP)) {
			long prevCurUsers = curUsers;
			
			intervalNum++;

			logger.debug("getNextApproximateInterval ramp subinterval for interval " + intervalNum);

			boolean prevIntervalPassed = false;
			String curIntervalName = curInterval.getName();
			/*
			 * This is the not first interval. Need to know whether the previous interval
			 * passed. Get the statsSummaryRollup for the previous interval
			 */
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassed();
				getIntervalStatsSummaries().add(rollup);
			}

			logger.debug("getNextApproximateInterval: Interval " + intervalNum + " prevIntervalPassed = "
					+ prevIntervalPassed);

			if (prevIntervalPassed && (curUsers == maxUsers)) {
				/*
				 * Already passing at maxUsers. The actual maximum must be higher than we can
				 * run, so just end the run.
				 */
				logger.debug(
						"getNextApproximateInterval. At max users, so can't advance.  Ending workload and returning curInterval: "
								+ curInterval);
				loadPathComplete();
				return curInterval;
			} else if (prevIntervalPassed && ((curUsers + curRateStep) > maxUsers)) {
				/*
				 * Can't step up beyond maxUsers, so just go to maxUsers. Reduce the curStep to
				 * halfway between curUsers and maxUsers
				 */
				logger.debug("getNextApproximateInterval: Next interval would have passed maxUsers, using maxUsers");
				curRateStep = (maxUsers - curUsers) / 2;
				curUsers = maxUsers;
			} else if (prevIntervalPassed) {
				if (curUsers > maxPassUsers) {
					maxPassUsers = curUsers;
					maxPassIntervalName = curInterval.getName();
				}

				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				long nextRateStep = curRateStep;
				while ((curUsers + nextRateStep) >= minFailUsers) {
					nextRateStep /= 2;
					if (nextRateStep < approximateMinRateStep) {
						nextRateStep = approximateMinRateStep;
						break;
					}
				}

				if ((curUsers + nextRateStep) >= minFailUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Go to the next phase.
					 */
					logger.debug(
							"getNextApproximateInterval: Can't get closer to maximum with minRateStep, going to next phase");
					intervalNum = 0;
					curPhase = Phase.NARROWIN;
					nextSubInterval = SubInterval.WARMUP;
					curRateStep /= 2;
					return getNextNarrowInInterval();
				}

				curRateStep = nextRateStep;
				curUsers += curRateStep;
			} else {
				// prevIntervalFailed
				if (curUsers < minFailUsers) {
					minFailUsers = curUsers;
				}

				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				long nextRateStep = curRateStep;
				while ((curUsers - nextRateStep) <= maxPassUsers) {
					nextRateStep /= 2;
					if (nextRateStep < approximateMinRateStep) {
						nextRateStep = approximateMinRateStep;
						break;
					}
				}

				if ((curUsers - nextRateStep) <= maxPassUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Go to the next phase.
					 */
					logger.debug(
							"getNextApproximateInterval: Can't get closer to maximum with minRateStep, going to next phase");
					intervalNum = 0;
					curPhase = Phase.NARROWIN;
					nextSubInterval = SubInterval.WARMUP;
					curRateStep /= 2;
					return getNextNarrowInInterval();
				}

				curRateStep = nextRateStep;
				curUsers -= curRateStep;

			}

			/*
			 * Generate the intervals to ramp-up to the next curUsers
			 */
			rampIntervals.addAll(generateRampIntervals("APPROXIMATE-Ramp-" + intervalNum + "-", mediumRampIntervalDurationSec, 15, prevCurUsers, curUsers));
			nextSubInterval = SubInterval.WARMUP;
			nextInterval = rampIntervals.pop();
		} else if (nextSubInterval.equals(SubInterval.WARMUP)) {

			if (intervalNum == 0) {
				/* 
				 * The first interval of APPROXIMATE is a warmup, not ramp
				 */
				intervalNum++;
				
				/*
				 * Reset the pass/fail bounds so that we can narrow in with longer runs.
				 */
				minFailUsers = Long.MAX_VALUE;
				maxPassUsers = 0;
				maxPassIntervalName = null;

				/*
				 * First interval of APPROXIMATE should just be a longer run at the same level
				 * that INITIALRAMP ended on.
				 */
				nextInterval.setUsers(curUsers);
				nextInterval.setName("APPROXIMATE-Warmup-" + intervalNum);
				nextInterval.setDuration(mediumWarmupIntervalDurationSec);
				nextSubInterval = SubInterval.DECISION;
				logger.debug("getNextApproximateInterval first interval. returning interval: " + nextInterval);
				return nextInterval;
			}

			if (!rampIntervals.isEmpty()) {
				logger.debug("getNextApproximateInterval returning next ramp subinterval for interval " + intervalNum);
				nextInterval = rampIntervals.pop();				
			} else {
				logger.debug("getNextApproximateInterval warmup subinterval for interval " + intervalNum);
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(mediumWarmupIntervalDurationSec);
				nextInterval.setName("APPROXIMATE-Warmup-" + intervalNum);
				nextSubInterval = SubInterval.DECISION;
			}
		
		} else {
			logger.debug("getNextApproximateInterval decision subinterval for interval " + intervalNum);
			/*
			 * Do the sub-interval used for decisions. This is run at the same number of
			 * users for the previous interval, but with the non-warmup duration
			 */
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(mediumIntervalDurationSec);
			nextInterval.setName("APPROXIMATE-" + intervalNum);
			nextSubInterval = SubInterval.RAMP;
		}

		logger.debug("getNextApproximateInterval. returning interval: " + nextInterval);
		return nextInterval;
	}

	/*
	 * Narrow in on max passing until at minRateStep
	 */
	@JsonIgnore
	private UniformLoadInterval getNextNarrowInInterval() {
		logger.debug("getNextNarrowInInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();
		if (nextSubInterval.equals(SubInterval.RAMP)) {
			long prevCurUsers = curUsers;

			// RAMP starts a new interval
			intervalNum++;
			logger.debug("getNextNarrowInInterval ramp subinterval for interval " + intervalNum);

			/*
			 * Need to know whether the previous interval
			 * passed. Get the statsSummaryRollup for the previous interval
			 */
			String curIntervalName = curInterval.getName();
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
			boolean prevIntervalPassed = false;
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassed();
				getIntervalStatsSummaries().add(rollup);
			}
			logger.debug(
					"getNextNarrowInInterval: Interval " + intervalNum + " prevIntervalPassed = " + prevIntervalPassed);

			if (prevIntervalPassed && (curUsers == maxUsers)) {
				/*
				 * Already passing at maxUsers. The actual maximum must be higher than we can
				 * run, so just end the run.
				 */
				logger.debug(
						"getNextNarrowInInterval. At max users, so can't advance.  Ending workload and returning curInterval: "
								+ curInterval);
				loadPathComplete();
				return curInterval;
			} else if (prevIntervalPassed && ((curUsers + curRateStep) > maxUsers)) {
				/*
				 * Can't step up beyond maxUsers, so just go to maxUsers. Reduce the curStep to
				 * halfway between curUsers and maxUsers
				 */
				curRateStep = (maxUsers - curUsers) / 2;
				curUsers = maxUsers;
				logger.debug("getNextNarrowInInterval: Next interval would have passed maxUsers, using maxUsers");
			} else if (prevIntervalPassed) {
				if (curUsers > maxPassUsers) {
					maxPassUsers = curUsers;
					maxPassIntervalName = curInterval.getName();
				}

				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				long nextRateStep = curRateStep;
				while ((curUsers + nextRateStep) >= minFailUsers) {
					nextRateStep /= 2;
					if (nextRateStep < narrowinMinRateStep) {
						nextRateStep = narrowinMinRateStep;
						break;
					}
				}

				if ((curUsers + nextRateStep) >= minFailUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Have found the maximum
					 */
					logger.debug(
							"getNextNarrowInInterval: Can't get closer to maximum. Found maximum at " + maxPassUsers);
					loadPathComplete();
					return curInterval;
				}

				curRateStep = nextRateStep;
				curUsers += curRateStep;
			} else {
				// prevIntervalFailed
				if (curUsers < minFailUsers) {
					minFailUsers = curUsers;
				}

				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				long nextRateStep = curRateStep;
				while ((curUsers - nextRateStep) <= maxPassUsers) {
					nextRateStep /= 2;
					if (nextRateStep < narrowinMinRateStep) {
						nextRateStep = narrowinMinRateStep;
						break;
					}
				}

				if ((curUsers - nextRateStep) <= maxPassUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Have found the maximum
					 */
					logger.debug("getNextNarrowInInterval: Can't get closer to maximum. Found maximum at "
							+ maxPassUsers);
					loadPathComplete();
					return curInterval;
				}

				curRateStep = nextRateStep;
				curUsers -= curRateStep;

			}


			/*
			 * Generate the intervals to ramp-up to the next curUsers
			 */
			rampIntervals.addAll(generateRampIntervals("NARROWIN-Ramp-" + intervalNum + "-", longRampIntervalDurationSec, 15, prevCurUsers, curUsers));
			nextSubInterval = SubInterval.WARMUP;
			nextInterval = rampIntervals.pop();

		} else  if (nextSubInterval.equals(SubInterval.WARMUP)) {
			
			if (intervalNum == 0) {
				/* 
				 * The first interval of NARROWIN is a warmup, not ramp
				 */
				intervalNum++;
				
				/*
				 * Reset the pass/fail bounds so that we can narrow in with longer runs.
				 */
				minFailUsers = Long.MAX_VALUE;
				maxPassUsers = 0;
				maxPassIntervalName = null;

				/*
				 * First interval of NARROWIN should just be a longer run at the same level that
				 * APPROXIMATE ended on.
				 */
				nextSubInterval = SubInterval.DECISION;
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(longWarmupIntervalDurationSec);
				nextInterval.setName("NARROWIN-Warmup-" + intervalNum);
				logger.debug("getNextNarrowInInterval first interval. returning interval: " + nextInterval);
				return nextInterval;
			}
			
			if (!rampIntervals.isEmpty()) {
				logger.debug("getNextNarrowInInterval returning next ramp subinterval for interval " + intervalNum);
				nextInterval = rampIntervals.pop();				
			} else {
				/*
				 * Do the sub-interval used for decisions. This is run at the same number of
				 * users for the previous interval, but with the non-warmup duration
				 */
				logger.debug("getNextNarrowInInterval warmup subinterval for interval " + intervalNum);
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(longIntervalDurationSec);
				nextInterval.setName("NARROWIN-Warmup-" + intervalNum);
				nextSubInterval = SubInterval.DECISION;
			}
		} else {
			logger.debug("getNextNarrowInInterval decision subinterval for interval " + intervalNum);
			/*
			 * Do the sub-interval used for decisions. This is run at the same number of
			 * users for the previous interval, but with the non-warmup duration
			 */
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(longIntervalDurationSec);
			nextInterval.setName("NARROWIN-" + intervalNum);
			nextSubInterval = SubInterval.RAMP;
		}

		logger.debug("getNextNarrowInInterval. returning interval: " + nextInterval);
		return nextInterval;
	}

	@JsonIgnore
	private UniformLoadInterval getNextRampDownInterval() {
		logger.debug("getNextRampDownInterval ");
		logger.debug("getNextRampDownInterval returning interval: " + curInterval);

		return curInterval;
	}

	private void loadPathComplete() {
		boolean passed = false;
		if (maxPassUsers > 0) {
			/*
			 * Pass up the maximum number of users that passed a steady interval.
			 */
			passed = true;
		}

		WorkloadStatus status = new WorkloadStatus();
		status.setIntervalStatsSummaries(getIntervalStatsSummaries());
		status.setMaxPassUsers(maxPassUsers);
		status.setMaxPassIntervalName(maxPassIntervalName);
		status.setPassed(passed);
		workload.loadPathComplete(status);
	}

	@JsonIgnore
	@Override
	public LoadInterval getNextStatsInterval() {
		logger.debug("getNextStatsInterval");

		statsIntervalAvailable.acquireUninterruptibly();

		logger.debug("getNextStatsInterval returning interval: " + curInterval);
		return curInterval;
	}

	public long getMaxUsers() {
		return maxUsers;
	}

	public void setMaxUsers(long maxUsers) {
		this.maxUsers = maxUsers;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}

}

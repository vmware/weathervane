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
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "findmax")
public class FindMaxLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FindMaxLoadPath.class);

	private long maxUsers;

	/*
	 * Phases in a findMax run: - INITIALRAMP: Use short intervals to ramp up until
	 * response-times begin to fail - FINDFIRSTMAX: Use medium intervals to get an
	 * estimate of the range in which the maximum falls. - VERIFYMAX: Use long
	 * intervals to narrow in on a final passing level 
	 */
	private enum Phase {
		INITIALRAMP, FINDFIRSTMAX, VERIFYMAX
	};

	@JsonIgnore
	private Phase curPhase = Phase.INITIALRAMP;

	/*
	 * Each interval in a in a findMax run has up to three sub-intervals: 
	 * - RAMP: Transition period between intervals to avoid large jumps in the 
	 *   number of users. 
	 * - WARMUP: Period used to let the users log in and get to a steady state
	 * - DECISION: Period used to decide whether the interval passes the 
	 *   QOS requirements of the phase.
	 */
	private enum SubInterval {
		RAMP, WARMUP, DECISION, VERIFYFIRST, VERIFYSUBSEQUENT
	};

	@JsonIgnore
	private SubInterval nextSubInterval = SubInterval.DECISION;

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

	@JsonIgnore
	private long initialRampRateStep = 1000;

	@JsonIgnore
	private long curRateStep;
	@JsonIgnore
	private long minRateStep;

	@JsonIgnore
	private int numVerifyMaxRepeatsPassed = 0;
	 
	@JsonIgnore
	private int numSucessiveIntervalsPassed = 0;
	@JsonIgnore
	private int numSucessiveIntervalsFailed = 0;
	
	@JsonIgnore
	private final long initialRampIntervalSec = 60;

	@JsonIgnore
	private final long findFirstMaxRampIntervalSec = 120;
	@JsonIgnore
	private final long findFirstMaxWarmupIntervalSec = 180;
	@JsonIgnore
	private final long findFirstMaxIntervalSec = 300;

	@JsonIgnore
	private final long verifyMaxRampIntervalSec = 120;
	@JsonIgnore
	private final long verifyMaxWarmupIntervalSec = 180;
	@JsonIgnore
	private final long verifyMaxIntervalSec = 300;
	@JsonIgnore
	private final int numRequiredVerifyMaxRepeats = 2;
	
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
		
		this.maxUsers = workload.getMaxUsers();
		this.initialRampRateStep = maxUsers / 10;
		
		/*
		 * Set up the curStatsInterval
		 */
		curStatusInterval.setName("InitialRamp-0");
		curStatusInterval.setDuration(initialRampIntervalSec);
		curStatusInterval.setStartUsers(0L);
		curStatusInterval.setEndUsers(0L);
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
		case FINDFIRSTMAX:
			nextInterval = getNextFindFirstMaxInterval();
			break;
		case VERIFYMAX:
			nextInterval = getNextVerifyMaxInterval();
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
		intervalNum++;
		logger.debug("getNextInitialRampInterval interval " + intervalNum);

		/*
		 * If this is not the first interval then we need to select the number of users
		 * based on the results of the previous interval.
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
				 * We always pass the first interval as well to avoid warmup issues
				 */
				if (intervalNum != 2) {
					/*
					 * InitialRamp intervals pass if operations pass response-time QOS. The mix QoS
					 * is not used in initialRamp
					 */
					prevIntervalPassed = rollup.isIntervalPassedRT();
				}
				getIntervalStatsSummaries().add(rollup);
			}
			logger.debug("getNextInitialRampInterval: Interval " + intervalNum + " prevIntervalPassed = "
					+ prevIntervalPassed);
		}

		/*
		 * If we have reached max users, or the previous interval failed, then to go to
		 * the FINDFIRSTMAX phase
		 */
		if (!prevIntervalPassed || ((curUsers + initialRampRateStep) > maxUsers)) {

			return moveToFindFirstMax();
		}
		
		curUsers += initialRampRateStep;
		long nextIntervalDuration = initialRampIntervalSec;
		/*
		 *  If number of users is less than 1000, then double the
		 *  interval duration to lessen the effect of outliers
		 *  due to the small number of users.
		 */
		if (curUsers < 1000) {
			nextIntervalDuration *= 2;
		}
		
		nextInterval.setUsers(curUsers);
		nextInterval.setDuration(nextIntervalDuration);
		nextInterval.setName("InitialRamp-" + intervalNum);

		curStatusInterval.setName(nextInterval.getName());
		curStatusInterval.setStartUsers(curUsers);
		curStatusInterval.setEndUsers(curUsers);

		logger.debug("getNextInitialRampInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	private UniformLoadInterval moveToFindFirstMax() {
		/*
		 * When moving to FINDFIRSTMAX, the initial rateStep is 1/10 of curUsers, and the
		 * minRateStep is 1/20 of curUsers
		 */
		curRateStep = curUsers / 10;
		minRateStep = curUsers / 100;
		curUsers -= curRateStep;
		if (curUsers <= 0) {
			curRateStep /= 2;
			curUsers += curRateStep;
		}

		intervalNum = 0;
		curPhase = Phase.FINDFIRSTMAX;

		// No ramp on first APPROXIMATE interval
		nextSubInterval = SubInterval.WARMUP;
		logger.debug("getNextInitialRampInterval: Moving to FINDFIRSTMAX phase.  curUsers = " + curUsers
				+ ", curRateStep = " + curRateStep);
		return getNextFindFirstMaxInterval();
	}

	/*
	 * Narrow in on max passing. Once we have found the initial maximum (which has passed
	 * QoS once), we move on to verifyMax.
	 */
	@JsonIgnore
	private UniformLoadInterval getNextFindFirstMaxInterval() {
		logger.debug("getNextFindFirstMaxInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();
		if (nextSubInterval.equals(SubInterval.RAMP)) {
			long prevCurUsers = curUsers;
			
			intervalNum++;

			logger.debug("getNextFindFirstMaxInterval ramp subinterval for interval " + intervalNum);

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

			logger.debug("getNextFindFirstMaxInterval: Interval " + intervalNum + " prevIntervalPassed = "
					+ prevIntervalPassed);

			if (prevIntervalPassed && (curUsers == maxUsers)) {
				/*
				 * Already passing at maxUsers. The actual maximum must be higher than we can
				 * run, so just end the run. Set maxPassUsers to 0 so that the run isn't considered passing.
				 */
				logger.debug(
						"getNextFindFirstMaxInterval. At max users, so can't advance.  Ending workload and returning curInterval: "
								+ curInterval);
				maxPassUsers = 0;
				loadPathComplete();
				return curInterval;
			} else if (prevIntervalPassed && ((curUsers + curRateStep) > maxUsers)) {
				/*
				 * Can't step up beyond maxUsers, so just go to maxUsers. Reduce the curStep to
				 * halfway between curUsers and maxUsers
				 */
				logger.debug("getNextFindFirstMaxInterval: Next interval would have passed maxUsers, using maxUsers");
				curRateStep = (maxUsers - curUsers) / 2;
				curUsers = maxUsers;
			} else if (prevIntervalPassed) {
				if (curUsers > maxPassUsers) {
					maxPassUsers = curUsers;
					maxPassIntervalName = curInterval.getName();
				}

				long nextRateStep = curRateStep;
				
				numSucessiveIntervalsPassed++;
				if (numSucessiveIntervalsPassed >= 2) {
					/*
					 * Have passed twice in a row, increase the rate step to possibly 
					 * shorten run
					 */
					nextRateStep *= 2;
					
					numSucessiveIntervalsPassed = 0;
				}

				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				while ((curUsers + nextRateStep) >= minFailUsers) {
					nextRateStep /= 2;
					if (nextRateStep < minRateStep) {
						nextRateStep = minRateStep;
						break;
					}
				}

				if ((curUsers + nextRateStep) >= minFailUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Go to the next phase.
					 */
					logger.debug(
							"getNextFindFirstMaxInterval: Can't get closer to maximum with minRateStep, going to next phase");
					return moveToVerifyMax();
				}

				curRateStep = nextRateStep;
				curUsers += curRateStep;
			} else {
				// prevIntervalFailed
				if (curUsers < minFailUsers) {
					minFailUsers = curUsers;
				}

				long nextRateStep = curRateStep;
				
				numSucessiveIntervalsPassed--;
				if (numSucessiveIntervalsPassed <= -2) {
					/*
					 * Have failed twice in a row, increase the rate step to possibly 
					 * shorten run
					 */
					nextRateStep *= 2;
					
					numSucessiveIntervalsPassed = 0;
				}
				
				/*
				 * The next interval needs to be less than minFailUsers. May need to shrink the
				 * step size in order to do this.
				 */
				while ((curUsers - nextRateStep) <= maxPassUsers) {
					nextRateStep /= 2;
					if (nextRateStep < minRateStep) {
						nextRateStep = minRateStep;
						break;
					}
				}

				if ((curUsers - nextRateStep) <= maxPassUsers) {
					/*
					 * Can't get closer to maximum with the minRateStep. Go to the next phase.
					 */
					logger.debug(
							"getNextFindFirstMaxInterval: Can't get closer to maximum with minRateStep, going to next phase");
					return moveToVerifyMax();
				}

				curRateStep = nextRateStep;
				curUsers -= curRateStep;

			}

			/*
			 * Generate the intervals to ramp-up to the next curUsers
			 */
			rampIntervals.addAll(generateRampIntervals("FINDFIRSTMAX-Ramp-" + intervalNum + "-", findFirstMaxRampIntervalSec, 15, prevCurUsers, curUsers));
			nextSubInterval = SubInterval.WARMUP;
			nextInterval = rampIntervals.pop();
			
			curStatusInterval.setName("FINDFIRSTMAX-Ramp-" + intervalNum);
			curStatusInterval.setStartUsers(prevCurUsers);
			curStatusInterval.setEndUsers(curUsers);
			curStatusInterval.setDuration(findFirstMaxRampIntervalSec);
		} else if (nextSubInterval.equals(SubInterval.WARMUP)) {

			if (intervalNum == 0) {
				/* 
				 * The first interval of FINDFIRSTMAX is a warmup, not ramp
				 */
				intervalNum++;
				
				/*
				 * Reset the pass/fail bounds so that we can narrow in with longer runs.
				 */
				minFailUsers = Long.MAX_VALUE;
				maxPassUsers = 0;
				maxPassIntervalName = null;

				/*
				 * First interval of FINDFIRSTMAX should just be a longer run at the same level
				 * that INITIALRAMP ended on.
				 */
				nextInterval.setUsers(curUsers);
				nextInterval.setName("FINDFIRSTMAX-Warmup-" + intervalNum);
				nextInterval.setDuration(findFirstMaxWarmupIntervalSec);
				
				curStatusInterval.setName(nextInterval.getName());
				curStatusInterval.setStartUsers(curUsers);
				curStatusInterval.setEndUsers(curUsers);
				curStatusInterval.setDuration(findFirstMaxWarmupIntervalSec);
				
				nextSubInterval = SubInterval.DECISION;
				logger.debug("getNextFindFirstMaxInterval first interval. returning interval: " + nextInterval);
				return nextInterval;
			}

			if (!rampIntervals.isEmpty()) {
				logger.debug("getNextFindFirstMaxInterval returning next ramp subinterval for interval " + intervalNum);
				nextInterval = rampIntervals.pop();				
			} else {
				logger.debug("getNextFindFirstMaxInterval warmup subinterval for interval " + intervalNum);
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(findFirstMaxWarmupIntervalSec);
				nextInterval.setName("FINDFIRSTMAX-Warmup-" + intervalNum);

				curStatusInterval.setName(nextInterval.getName());
				curStatusInterval.setStartUsers(curUsers);
				curStatusInterval.setEndUsers(curUsers);
				curStatusInterval.setDuration(findFirstMaxWarmupIntervalSec);
				
				nextSubInterval = SubInterval.DECISION;
			}
		
		} else {
			logger.debug("getNextFindFirstMaxInterval decision subinterval for interval " + intervalNum);
			/*
			 * Do the sub-interval used for decisions. This is run at the same number of
			 * users for the previous interval, but with the non-warmup duration
			 */
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(findFirstMaxIntervalSec);
			nextInterval.setName("FINDFIRSTMAX-" + intervalNum);

			curStatusInterval.setName(nextInterval.getName());
			curStatusInterval.setStartUsers(curUsers);
			curStatusInterval.setEndUsers(curUsers);
			curStatusInterval.setDuration(findFirstMaxIntervalSec);
			
			nextSubInterval = SubInterval.RAMP;
		}

		logger.debug("getNextFindFirstMaxInterval. returning interval: " + nextInterval);
		return nextInterval;
	}

	private UniformLoadInterval moveToVerifyMax() {
		/*
		 * When moving to VERIFYMAX, the initial rateStep is 1/20 of maxPassUsers, 
		 * and the minRateStep is 1/100 of maxPassUsers
		 */
		curRateStep = maxPassUsers / 20;
		minRateStep = maxPassUsers / 100;
		curUsers = maxPassUsers;

		intervalNum = 0;
		numSucessiveIntervalsPassed = 0;
		curPhase = Phase.VERIFYMAX;
		nextSubInterval = SubInterval.RAMP;
		return getNextVerifyMaxInterval();
	}

	/*
	 * Narrow in on max passing until at minRateStep
	 */
	@JsonIgnore
	private UniformLoadInterval getNextVerifyMaxInterval() {
		logger.debug("getNextVerifyMaxInterval ");

		UniformLoadInterval nextInterval = new UniformLoadInterval();
		if (nextSubInterval.equals(SubInterval.RAMP)) {
			/*
			 * Ramping to the currentValue of maxPassUsers.  On the first try at 
			 * verifyMax, this will be the maximum found in findFirstMax.  If that 
			 * fails, then it will be the new value chosen after a decision period 
			 * of VerifyMax fails.
			 */
			long prevCurUsers = curUsers;
			curUsers = maxPassUsers;
			
			// RAMP starts a new interval
			intervalNum++;
			logger.debug("getNextVerifyMaxInterval ramp subinterval for interval " + intervalNum);

			/*
			 * Generate the intervals to ramp-up to the next curUsers
			 */
			rampIntervals.addAll(generateRampIntervals("VERIFYMAX-Ramp-" + intervalNum + "-", verifyMaxRampIntervalSec, 15, prevCurUsers, curUsers));
			nextSubInterval = SubInterval.WARMUP;
			nextInterval = rampIntervals.pop();
			
			curStatusInterval.setName("VERIFYMAX-Ramp-" + intervalNum);
			curStatusInterval.setStartUsers(prevCurUsers);
			curStatusInterval.setEndUsers(curUsers);
			curStatusInterval.setDuration(verifyMaxRampIntervalSec);

		} else  if (nextSubInterval.equals(SubInterval.WARMUP)) {			
			if (!rampIntervals.isEmpty()) {
				logger.debug("getNextVerifyMaxInterval returning next ramp subinterval for interval " + intervalNum);
				nextInterval = rampIntervals.pop();				
			} else {
				logger.debug("getNextVerifyMaxInterval warmup subinterval for interval " + intervalNum);
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(verifyMaxWarmupIntervalSec);
				nextInterval.setName("VERIFYMAX-Warmup-" + intervalNum);

				curStatusInterval.setName(nextInterval.getName());
				curStatusInterval.setStartUsers(curUsers);
				curStatusInterval.setEndUsers(curUsers);
				curStatusInterval.setDuration(verifyMaxWarmupIntervalSec);

				nextSubInterval = SubInterval.VERIFYFIRST;
			}
		} else if (nextSubInterval.equals(SubInterval.VERIFYFIRST)) {	
			logger.debug("getNextVerifyMaxInterval VERIFYFIRST subinterval for interval " + intervalNum);
			/*
			 * This is the first time that we are entering the decision periods
			 * for this value of curUsers.  Run a sub-interval at curUsers.
			 */
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(verifyMaxIntervalSec);
			nextInterval.setName("VERIFYMAX-VERIFYFIRST-" + intervalNum);
			nextSubInterval = SubInterval.VERIFYSUBSEQUENT;

			curStatusInterval.setName(nextInterval.getName());
			curStatusInterval.setStartUsers(curUsers);
			curStatusInterval.setEndUsers(curUsers);
			curStatusInterval.setDuration(verifyMaxIntervalSec);
		} else if (nextSubInterval.equals(SubInterval.VERIFYSUBSEQUENT)) {
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
					"getNextVerifyMaxInterval: Interval " + intervalNum + " prevIntervalPassed = " + prevIntervalPassed);

			if (prevIntervalPassed) {
				/*
				 * Passed at the current value of maxPassUsers.  If we have passed the 
				 * required number of times, then the load path is complete.  Otherwise we 
				 * need to run another decision interval.
				 */
				numVerifyMaxRepeatsPassed++;
				if (numVerifyMaxRepeatsPassed == numRequiredVerifyMaxRepeats) {
					loadPathComplete();
				} else {
					// Test again at this interval
					nextInterval.setUsers(curUsers);
					nextInterval.setDuration(verifyMaxIntervalSec);
					nextInterval.setName("VERIFYMAX-VERIFYSUBSEQUENT-PASSED" +
							numVerifyMaxRepeatsPassed + "-" + intervalNum);

					curStatusInterval.setName(nextInterval.getName());
					curStatusInterval.setStartUsers(curUsers);
					curStatusInterval.setEndUsers(curUsers);
					curStatusInterval.setDuration(verifyMaxIntervalSec);

					nextSubInterval = SubInterval.VERIFYSUBSEQUENT;					
				}
			} else {
				/*
				 * Reduce the number of users by minRateStep and try again.
				 */
				numSucessiveIntervalsFailed++;
				if (numSucessiveIntervalsFailed >= 2) {
					numSucessiveIntervalsFailed = 0;
					minRateStep *= 2;
				}
				maxPassUsers -= minRateStep;
				if (maxPassUsers <= 0) {
					maxPassUsers = 0;
					loadPathComplete();
				}
				numVerifyMaxRepeatsPassed = 0;
				nextSubInterval = SubInterval.RAMP;
				return getNextVerifyMaxInterval();
			}
			
		}

		logger.debug("getNextVerifyMaxInterval. returning interval: " + nextInterval);
		return nextInterval;
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

	@Override
	public RampLoadInterval getCurStatusInterval() {
		return curStatusInterval;
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

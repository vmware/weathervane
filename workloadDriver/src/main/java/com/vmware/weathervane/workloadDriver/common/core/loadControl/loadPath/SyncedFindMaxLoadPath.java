/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

import java.util.ArrayDeque;
import java.util.Deque;
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

@JsonTypeName(value = "syncedfindmax")
public class SyncedFindMaxLoadPath extends SyncedLoadPath {
	private static final Logger logger = LoggerFactory.getLogger(SyncedFindMaxLoadPath.class);

	private long maxUsers;
	private long minUsers;
	private long maxPassHint = 0;

	private long numQosPeriods = 3;
	private long qosPeriodSec = 300;
	private double findMaxStopPct = 0.01;
	private long initialRampRateStep = 1000;

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
		RAMP, WARMUP, STEADY, DECISION
	};

	@JsonIgnore
	private SubInterval nextSubInterval = SubInterval.DECISION;

	@JsonIgnore
	private long curUsers = 0;

	@JsonIgnore
	private long phaseIntervalNum = 0;

	@JsonIgnore
	private UniformLoadInterval curInterval = null;

	@JsonIgnore
	Deque<UniformLoadInterval> rampIntervals = new ArrayDeque<UniformLoadInterval>();

	@JsonIgnore
	private long minFailUsers = Long.MAX_VALUE;
	@JsonIgnore
	private long maxPassUsers = 0;
	@JsonIgnore
	private String maxPassIntervalName = "";

	@JsonIgnore
	private long curRateStep;
	
	@JsonIgnore
	private long curPhaseRepeats;
	
	@JsonIgnore
	private boolean loadPathComplete = false;

	@JsonIgnore
	private int numRepeatsPassed = 0;
	 
	@JsonIgnore
	private int numSucessiveIntervalsPassed = 0;
	
	@JsonIgnore
	private int numSucessiveIntervalsFailed = 0;
	
	@JsonIgnore
	private final long initialRampIntervalSec = 60;

	@JsonIgnore
	private final long rampIntervalSec = 120;
	@JsonIgnore
	private final long warmupIntervalSec = 180;

	@JsonIgnore
	private boolean statsIntervalComplete = false;
		
	@JsonIgnore
	private UniformLoadInterval curStatsInterval = new UniformLoadInterval();

	@Override
	public void initialize(String runName, String workloadName, Workload workload, LoadPathController loadPathController,
			List<String> hosts, String statsHostName, RestTemplate restTemplate,
			ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, loadPathController, hosts, statsHostName, restTemplate,
				executorService);
		logger.debug("initialize " + this.getName() + ": minUsers = {}, maxUsers = {}", getMinUsers(), maxUsers);

		this.maxUsers = workload.getMaxUsers();
		
		curInterval= new UniformLoadInterval();
		curInterval.setUsers(getInitialRampRateStep());
		curInterval.setName("prerun");
		curInterval.setDuration(initialRampIntervalSec);
		
		/*
		 * Set up the curStatusInterval
		 */
		curStatusInterval.setName("InitialRamp-0");
		curStatusInterval.setDuration(initialRampIntervalSec);
		curStatusInterval.setStartUsers(0L);
		curStatusInterval.setEndUsers(0L);
	}

	@Override
	protected IntervalCompleteResult intervalComplete() {
		logger.info("intervalComplete: " + this.getName());
		statsIntervalComplete = false;
		if (Phase.INITIALRAMP.equals(curPhase)) {
			return initialRampIntervalComplete();			
		} else {
			return otherIntervalComplete();
		}
	}
	
	@JsonIgnore
	@Override
	public UniformLoadInterval getNextIntervalSynced(boolean passed) {
		logger.info("getNextIntervalSynced: " + this.getName());
		statsIntervalComplete = false;
		if (Phase.INITIALRAMP.equals(curPhase)) {
			curInterval = getNextInitialRampInterval(passed);			
		} else {
			curInterval = nextInterval(passed);
		}
		return curInterval;
	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {
		/* 
		 * This method is not used
		 */
		logger.warn("getNextInterval: " + this.getName());
		return curInterval;
	}

	@JsonIgnore
	private IntervalCompleteResult initialRampIntervalComplete() {
		logger.debug("initialRampIntervalComplete loadPath {}, intervalNum {}",
				this.getName(), phaseIntervalNum);
		IntervalCompleteResult result = new IntervalCompleteResult();
		result.setIntervalName(curInterval.getName());
		result.setDecisionInterval(true);
		/*
		 * If this is not the first interval then we need to select the number of users
		 * based on the results of the previous interval.
		 */
		boolean prevIntervalPassed = true;
		if (phaseIntervalNum > 1) {
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
				if (phaseIntervalNum != 2) {
					/*
					 * InitialRamp intervals pass if 99% of all operations pass response-time QOS. The mix QoS
					 * is not used in initialRamp
					 */
					prevIntervalPassed = (rollup.getPctPassing() >= 0.999);
				}
				getIntervalStatsSummaries().add(rollup);
			}
		} 		
		if (((getMaxPassHint() > 0) && (curUsers == getMaxPassHint())) || 
				((getMaxPassHint() == 0) && !prevIntervalPassed) || 
				((curUsers + getInitialRampRateStep()) > maxUsers)) {
			result.setPassed(false);
		} else {
			result.setPassed(true);			
		}
		
		logger.info("initialRampIntervalComplete " + this.getName() 
			+ ": Interval " + phaseIntervalNum + " prevIntervalPassed = "
			+ prevIntervalPassed);
		return result;
	}

	@JsonIgnore
	private UniformLoadInterval getNextInitialRampInterval(boolean prevIntervalPassed) {

		UniformLoadInterval nextInterval = curInterval;
		phaseIntervalNum++;
		logger.debug("getNextInitialRampInterval " + this.getName() + ": interval " + phaseIntervalNum);

		/*
		 * If the previous interval failed, then to go to
		 * the FINDFIRSTMAX phase
		 */
		if (!prevIntervalPassed) {
			moveToNextPhase();
			return nextInterval(prevIntervalPassed);
		}
		
		curUsers += getInitialRampRateStep();
		if ((getMaxPassHint() > 0) && (curUsers > getMaxPassHint())) {
			curUsers = getMaxPassHint();
		}
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
		nextInterval.setName("InitialRamp-" + curUsers);

		curStatusInterval.setName(nextInterval.getName());
		curStatusInterval.setStartUsers(curUsers);
		curStatusInterval.setEndUsers(curUsers);
		curStatusInterval.setDuration(nextIntervalDuration);
		
		statsIntervalComplete = true;
		curStatsInterval.setName(nextInterval.getName());
		curStatsInterval.setUsers(curUsers);
		curStatsInterval.setDuration(nextIntervalDuration);

		logger.debug("getNextInitialRampInterval " + this.getName() + ": returning interval: " + nextInterval);
		return nextInterval;
	}

	@JsonIgnore
	private IntervalCompleteResult otherIntervalComplete() {
		IntervalCompleteResult result = new IntervalCompleteResult();
		result.setIntervalName(curInterval.getName());
		if (loadPathComplete || !SubInterval.DECISION.equals(nextSubInterval)) {
			result.setDecisionInterval(false);
			result.setPassed(true);
		} else {
			logger.debug("nextInterval {}: In Decision for interval {}", getName(), curInterval.getName());
			/*
			 * Based on pass/fail of previous run, maxPass, minFail, maxUsers, and minUsers,
			 * we need to decide on next value for curPhase, curUsers, and curRateStep
			 */
			String curIntervalName = curInterval.getName();
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
			boolean prevIntervalPassed = false;
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassed();
				getIntervalStatsSummaries().add(rollup);
			}
			logger.debug("otherIntervalComplete " + this.getName() + ": Interval " + phaseIntervalNum
					+ " prevIntervalPassed = " + prevIntervalPassed);
			result.setDecisionInterval(true);
			result.setPassed(prevIntervalPassed);
		} 
		return result;
	}

	@JsonIgnore
	private UniformLoadInterval nextInterval(boolean prevIntervalPassed) {
		phaseIntervalNum++;
		if (loadPathComplete) {
			curInterval.setName("PostRun-" + phaseIntervalNum);
			return curInterval;
		}
		
		if (!rampIntervals.isEmpty()) {
			logger.debug("nextInterval {}: returning next ramp subinterval for interval {}", getName(), phaseIntervalNum);
			return rampIntervals.pop();				
		} else {
			if (SubInterval.RAMP.equals(nextSubInterval)) {
				/*
				 * In ramp but rampIntervals is empty.  Move to WARMUP
				 */
				logger.debug("nextInterval for {}: moving from RAMP to WARMUP", getName());
				nextSubInterval = SubInterval.WARMUP;
				return nextInterval(true);
			} else if (SubInterval.DECISION.equals(nextSubInterval)) {
				logger.debug("nextInterval {}: In Decision for interval {}, passed = {}", 
						getName(), curInterval.getName(), prevIntervalPassed);

				if (prevIntervalPassed) {
					logger.debug("nextInterval {}, phase = {}: Passed interval at curUsers = {}", getName(), curPhase, curUsers);
					numRepeatsPassed++;
					if (numRepeatsPassed == curPhaseRepeats) {
						numRepeatsPassed = 0;
						if (curUsers > maxPassUsers) {
							logger.debug("nextInterval {}, phase = {}: found new maxPassUsers = {}", getName(), curPhase, curUsers);
							maxPassUsers = curUsers;
							maxPassIntervalName = curInterval.getName();
						}			
						if (curUsers == maxUsers) {
							/*
							 * Already passing at maxUsers. The actual maximum must be higher than we can
							 * run, so just end the run.
							 */
							logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase + ": " 
											+ "At max users, so can't advance.  Ending workload and returning curInterval: "
											+ curInterval);
							loadPathComplete(false);
							return nextInterval(true);
						}
						if ((minFailUsers - maxPassUsers) < (minFailUsers * getFindMaxStopPct())) {
							logger.debug(
									"nextInterval " + this.getName() + ", curPhase " + curPhase 
									+ ": maxPass and minFail are within {} percent, going to next phase", getFindMaxStopPct());
							moveToNextPhase();
							return nextInterval(true);
						} else {
							long nextRateStep = curRateStep;
							numSucessiveIntervalsFailed = 0;
							numSucessiveIntervalsPassed++;
							if (numSucessiveIntervalsPassed >= 3) {
								/*
								 * Have passed three times in a row, increase the rate step to possibly 
								 * shorten run
								 */
								logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase 
										+ ": Passed twice in a row.  Increasing nextRateStep");
								numSucessiveIntervalsPassed = 0;
								nextRateStep *= 1.25;
							}

							/*
							 * The next interval needs to be less than minFailUsers. May need to shrink the
							 * step size in order to do this.
							 */
							if ((curUsers + nextRateStep) >= minFailUsers) {
								logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase + ": "  
									+ "Reducing nextRateStep to halfway between maxPass and minFail");
								nextRateStep = (long) Math.ceil((minFailUsers - maxPassUsers) * 0.5);
							}

							long prevCurUsers = curUsers;
							curRateStep = nextRateStep;
							curUsers += curRateStep;

							long logCurUsers = curUsers;
							curUsers = niceRound(curUsers, maxPassUsers, minFailUsers);
							if (logCurUsers != curUsers) {
								logger.debug("nextInterval " + this.getName() + ": rounding curUsers from "
										+ logCurUsers + " to "+ curUsers + " during increase");
							}

							/*
							 * Generate the intervals to ramp-up to the next curUsers
							 */
							nextSubInterval = SubInterval.RAMP;
							rampIntervals.addAll(generateRampIntervals(curPhase + "-RampTo-" + curUsers + "-", rampIntervalSec, 15, prevCurUsers, curUsers));

							curStatusInterval.setName(curPhase + "-RampTo-" + curUsers);
							curStatusInterval.setStartUsers(prevCurUsers);
							curStatusInterval.setEndUsers(curUsers);
							curStatusInterval.setDuration(rampIntervalSec);
							return nextInterval(true);
						}
					} else {
						// Run STEADY again with curUsers
						nextSubInterval = SubInterval.STEADY;
					}					
				} else {
					// previous interval failed
					numRepeatsPassed = 0;
					if (curUsers < minFailUsers) {
						logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase 
										+ ": Found new minFailUsers = " + curUsers);
						minFailUsers = curUsers;
						if (minFailUsers <= getMinUsers()) {
							// Never passed.  End the run.
							logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase 
										+ ": Failed at minUsers.  Ending run");
							maxPassUsers = minUsers;
							maxPassIntervalName = "";
							loadPathComplete(false);
							return nextInterval(true);
						}
						if ((minFailUsers - maxPassUsers) < (minFailUsers * getFindMaxStopPct())) {
							logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase
										+ ": maxPass and minFail are within {} percent, going to next phase", getFindMaxStopPct());
							if (maxPassUsers < getMinUsers()) {
								// Never passed.  End the run.
								logger.debug("nextInterval " + this.getName() + ", curPhase " + curPhase + ": never passed.  Ending run");
								maxPassUsers = minUsers;
								maxPassIntervalName = "";
								loadPathComplete(false);
								return nextInterval(true);
							}
							moveToNextPhase();
							return nextInterval(true);
						}
					}

					long nextRateStep = curRateStep;		
					numSucessiveIntervalsPassed = 0;
					numSucessiveIntervalsFailed++;
					if (numSucessiveIntervalsFailed >= 2) {
						/*
						 * Have failed twice in a row, increase the rate step to possibly 
						 * shorten run
						 */
						logger.debug("nextInterval " + this.getName() +  ", curPhase " 
								+ curPhase + ": Failed twice in a row.  Increasing nextRateStep");
						nextRateStep *= 1.5;					
						numSucessiveIntervalsFailed = 0;
					}
					
					/*
					 * The next interval needs to be greater than maxPassUsers. May need to shrink the
					 * step size in order to do this.
					 */
					if ((curUsers - nextRateStep) <= maxPassUsers) {
						logger.debug("nextInterval " + getName() + ", curPhase " + curPhase 
								+ ": Reducing nextRateStep to halfway between maxPass and minFail");
						nextRateStep = (long) Math.ceil((minFailUsers - maxPassUsers) * 0.75);
					} 

					long prevCurUsers = curUsers;
					curRateStep = nextRateStep;
					logger.debug("nextInterval " + getName() + ", curPhase " + curPhase 
							+ ": curRateStep = {}, curUsers = {}, minUsers = {}", curRateStep, curUsers, getMinUsers());
					if ((curUsers - nextRateStep) <= getMinUsers()) {
						curUsers = getMinUsers();
						logger.debug("nextInterval " + getName() + ", curPhase " + curPhase 
							+ ": (curUsers - nextRateStep) <= minUsers, set curUsers to minUsers");
					} else {
						curUsers -= curRateStep;
						
						long logCurUsers = curUsers;
						curUsers = niceRound(curUsers, maxPassUsers, minFailUsers);
						if (logCurUsers != curUsers) {
							logger.debug("nextInterval " + getName() + ", curPhase " + curPhase 
								+ ": rounding curUsers from "+logCurUsers+ " to "+curUsers+ " during decrease");
						}
						
						logger.debug("nextInterval " + getName() + ", curPhase " + curPhase 
							+ ": (curUsers - nextRateStep) > minUsers, set curUsers to {}", curUsers);
					}

					/*
					 * Generate the intervals to ramp-up to the next curUsers
					 */
					nextSubInterval = SubInterval.RAMP;
					rampIntervals.addAll(generateRampIntervals(curPhase + "-RampTo-" + curUsers + "-", rampIntervalSec, 15, prevCurUsers, curUsers));

					curStatusInterval.setName(curPhase + "-RampTo-" + curUsers);
					curStatusInterval.setStartUsers(prevCurUsers);
					curStatusInterval.setEndUsers(curUsers);
					curStatusInterval.setDuration(rampIntervalSec);
					return nextInterval(true);
				}
			}
			
			if (SubInterval.WARMUP.equals(nextSubInterval)) {
				/*
				 * Set up an interval for WARMUP
				 */
				logger.debug("getNextFindFirstMaxInterval " + getName() + ": WARMUP subinterval for interval " + phaseIntervalNum);
				UniformLoadInterval nextInterval = new UniformLoadInterval();
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(warmupIntervalSec);
				nextInterval.setName(curPhase + "-Warmup-" + curUsers);

				curStatusInterval.setName(nextInterval.getName());
				curStatusInterval.setStartUsers(curUsers);
				curStatusInterval.setEndUsers(curUsers);
				curStatusInterval.setDuration(warmupIntervalSec);
				
				statsIntervalComplete = true;
				curStatsInterval.setName(nextInterval.getName());
				curStatsInterval.setUsers(curUsers);
				curStatsInterval.setDuration(warmupIntervalSec);
				
				nextSubInterval = SubInterval.STEADY;
				return nextInterval;
			} else if (SubInterval.STEADY.equals(nextSubInterval)) {
				/*
				 * Do the sub-interval used for decisions. This is run at the same number of
				 * users for the previous interval, but with the non-warmup duration
				 */
				logger.debug("getNextFindFirstMaxInterval " + getName() + ": STEADY subinterval for interval " + phaseIntervalNum);
				UniformLoadInterval nextInterval = new UniformLoadInterval();
				nextInterval.setUsers(curUsers);
				nextInterval.setDuration(getQosPeriodSec());
				if (Phase.FINDFIRSTMAX.equals(curPhase)) {
					nextInterval.setName(curPhase + "-" + curUsers);
				} else if (Phase.VERIFYMAX.equals(curPhase)) {
					nextInterval.setName(curPhase + "-" + curUsers + "-ITERATION-" + numRepeatsPassed);					
				}

				curStatusInterval.setName(nextInterval.getName());
				curStatusInterval.setStartUsers(curUsers);
				curStatusInterval.setEndUsers(curUsers);
				curStatusInterval.setDuration(getQosPeriodSec());

				statsIntervalComplete = true;
				curStatsInterval.setName(nextInterval.getName());
				curStatsInterval.setUsers(curUsers);
				curStatsInterval.setDuration(getQosPeriodSec());

				nextSubInterval = SubInterval.DECISION;
				return nextInterval;
			} else {
				return curInterval;
			}
		}
	}

	private void moveToVerifyMax() {
		/*
		 * When moving to VERIFYMAX, the initial rateStep is findMaxStopPct*maxPassUsers, 
		 */
		long prevCurUsers = curUsers;
		curRateStep = (long) Math.ceil(maxPassUsers * getFindMaxStopPct());
		curUsers = maxPassUsers;

		phaseIntervalNum = 0;
		numSucessiveIntervalsPassed = 0;
		numSucessiveIntervalsFailed = 0;
		curPhase = Phase.VERIFYMAX;
		
		/*
		 * Set minFailUsers to maxPass+1 so we don't exceed maxPass
		 * from findFirstMax
		 */
		minFailUsers = maxPassUsers + 1;
		
		curPhaseRepeats = numQosPeriods - 1;
		if (curPhaseRepeats <= 0) {
			loadPathComplete(true);
			return;
		}
		numRepeatsPassed = 0;
		maxPassUsers = 0;
		maxPassIntervalName = "";
		
		if (prevCurUsers != curUsers) {
			nextSubInterval = SubInterval.RAMP;
			/*
			 * Generate the intervals to ramp-up to the next curUsers
			 */
			rampIntervals.addAll(generateRampIntervals("VERIFYMAX-RampTo-" + curUsers + "-", rampIntervalSec, 15, prevCurUsers, curUsers));

			curStatusInterval.setName("VERIFYMAX-RampTo-" + curUsers);
			curStatusInterval.setStartUsers(prevCurUsers);
			curStatusInterval.setEndUsers(curUsers);
			curStatusInterval.setDuration(rampIntervalSec);
		} else {
			nextSubInterval = SubInterval.STEADY;
		}
	}

	private void moveToFindFirstMax() {
		/*
		 * When moving to FINDFIRSTMAX, the initial rateStep is 1/10 of curUsers
		 */
		long prevCurUsers = curUsers;
		if (getMaxPassHint() == 0) {
			curRateStep = curUsers / 10;
			curUsers -= curRateStep;
		} else {
			curRateStep = curUsers / 100;
		}

		if (curUsers <= 0) {
			curRateStep /= 2;
			curUsers += curRateStep;
		}
		
		long logCurUsers = curUsers;
		curUsers = niceRound(curUsers, 0, prevCurUsers);
		if (logCurUsers != curUsers) {
			logger.debug("moveToFindFirstMax " + getName() + ": rounding curUsers from "+logCurUsers+ " to "+curUsers);
		}

		phaseIntervalNum = 0;
		numSucessiveIntervalsPassed = 0;
		numSucessiveIntervalsFailed = 0;
		curPhase = Phase.FINDFIRSTMAX;
		
		// Run max only once in FindFirstMax
		curPhaseRepeats = 1;
		numRepeatsPassed = 0;
		
		/*
		 * Reset the pass/fail bounds so that we can narrow in with longer runs.
		 */
		minFailUsers = maxUsers;
		maxPassUsers = 0;
		
		/*
		 * Generate the intervals to ramp-up to the next curUsers
		 */
		rampIntervals.addAll(generateRampIntervals("FINDFIRSTMAX-RampTo-" + curUsers + "-", rampIntervalSec, 15, prevCurUsers, curUsers));

		curStatusInterval.setName("FINDFIRSTMAX-RampTo-" + curUsers);
		curStatusInterval.setStartUsers(prevCurUsers);
		curStatusInterval.setEndUsers(curUsers);
		curStatusInterval.setDuration(rampIntervalSec);

		nextSubInterval = SubInterval.RAMP;
		logger.debug("getNextInitialRampInterval " + this.getName() + ": Moving to FINDFIRSTMAX phase.  curUsers = " + curUsers
				+ ", curRateStep = " + curRateStep);
	}
	
	private void moveToNextPhase() {
		if (Phase.INITIALRAMP.equals(curPhase)) {
			moveToFindFirstMax();	
		} else if (Phase.FINDFIRSTMAX.equals(curPhase)) {
				moveToVerifyMax();	
		} else if (Phase.VERIFYMAX.equals(curPhase)) {
			// Complete
			boolean passed = false;
			if (maxPassUsers > minUsers) {
				passed = true;
			}
			loadPathComplete(passed);
		}
	}

	// round to nice numbers by at most 2% and 1000
	// meeting or exceeding the limits will return the original number, limits <= 0 are ignored
	private long niceRound(long number, long lowerLimit, long upperLimit) {
		long originalNumber = number;
		long tensMultiplier = 1;

		while (number > 1000 && tensMultiplier < 100) {
			number /= 10;
			tensMultiplier *= 10;
		}
		long rounder;
		if (number >= 250) {
			rounder = 10;
		} else if (tensMultiplier > 1 && number >= 200) {
			rounder = 5;
		} else if (tensMultiplier == 1 && number >= 100) {
			rounder = 4;
		} else if (number >= 50) {
			rounder = 2;
		} else {
			rounder = 1;
		}
		long roundDown = (number / rounder) * rounder * tensMultiplier;
		long roundUp = roundDown + rounder * tensMultiplier;
		//logger.debug("niceRound o:"+originalNumber+" ll:"+lowerLimit+" ul:"+upperLimit+" r:"+rounder+" t:"+tensMultiplier+" rd:"+roundDown+ " ru:"+roundUp);

		if (originalNumber - roundDown < roundUp - originalNumber) {
			if ((lowerLimit <= 0 || roundDown > lowerLimit) && (upperLimit <= 0 || roundDown < upperLimit)) {
				return roundDown;
			}
		} else {
			if ((upperLimit <= 0 || roundUp < upperLimit) && (lowerLimit <= 0 || roundUp > lowerLimit)) {
				return roundUp;
			}
			// limits prevent roundUp, try roundDown instead
			if ((lowerLimit <= 0 || roundDown > lowerLimit) && (upperLimit <= 0 || roundDown < upperLimit)) {
				return roundDown;
			}
		}

		// find a middle number within restrictive limits
		long rangeStart = lowerLimit;
		long rangeEnd = upperLimit;
		if (lowerLimit <= 0) {
			rangeStart = roundDown;
		}
		if (upperLimit <= 0) {
			rangeEnd = roundUp;
		}
		long rangeDelta = rangeEnd - rangeStart;
		long adder = rounder * tensMultiplier / 2;

		if (adder == rangeDelta && adder > 1) {
			// an edge case where conflicting rounding and limits should pick a simple mid point
			adder /= 2;
		}
		while (rangeDelta < adder && adder > 1) {
			// reduce until a middle number can be calculated within small range limits
			adder /= 2;
		}
		long middleNumber = rangeStart + adder;
		if ((lowerLimit <= 0 || middleNumber > lowerLimit) && (upperLimit <= 0 || middleNumber < upperLimit)) {
			return middleNumber;
		}

		// give up and return the original number
		return originalNumber;
	}

	private void loadPathComplete(boolean passed) {
		loadPathComplete = true;
		phaseIntervalNum = 0;
		WorkloadStatus status = new WorkloadStatus();
		status.setIntervalStatsSummaries(getIntervalStatsSummaries());
		status.setMaxPassUsers(maxPassUsers);
		status.setMaxPassIntervalName(maxPassIntervalName);
		status.setPassed(passed);
		status.setLoadPathName(this.getName());

		curInterval.setUsers(maxPassUsers);
		curInterval.setDuration(getQosPeriodSec());
		curInterval.setName("PostRun-" + phaseIntervalNum);

		curStatusInterval.setName(curInterval.getName());
		curStatusInterval.setStartUsers(curUsers);
		curStatusInterval.setEndUsers(curUsers);
		curStatusInterval.setDuration(getQosPeriodSec());

		loadPathController.removeIntervalResultCallback(getName());
		workload.loadPathComplete(status);
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
	

	public long getMaxUsers() {
		return maxUsers;
	}

	public void setMaxUsers(long maxUsers) {
		this.maxUsers = maxUsers;
	}

	public long getMinUsers() {
		return minUsers;
	}

	public void setMinUsers(long minUsers) {
		this.minUsers = minUsers;
	}

	public long getNumQosPeriods() {
		return numQosPeriods;
	}

	public long getQosPeriodSec() {
		return qosPeriodSec;
	}

	public double getFindMaxStopPct() {
		return findMaxStopPct;
	}

	public long getInitialRampRateStep() {
		return initialRampRateStep;
	}

	public void setInitialRampRateStep(long initialRampRateStep) {
		this.initialRampRateStep = initialRampRateStep;
	}

	public long getMaxPassHint() {
		return maxPassHint;
	}

	public void setMaxPassHint(long maxPassHint) {
		this.maxPassHint = maxPassHint;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("FixedLoadPath: ");

		return theStringBuilder.toString();
	}

}

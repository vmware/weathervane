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

import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.Semaphore;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.model.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryRollupResponseMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "findmax")
public class FindMaxLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(FindMaxLoadPath.class);

	private long maxUsers = 10000;

	@JsonIgnore
	private final long shortIntervalDurationSec = 60;
	@JsonIgnore
	private final long mediumIntervalDurationSec = 300;
	@JsonIgnore
	private final long longIntervalDurationSec = 600;
	
	/*
	 * Phases in a findMax run:
	 * - INITIALRAMP: Use short intervals to ramp up until response-times begin to fail
	 * - APPROXIMATE: Use medium intervals to get an estimate of the range in which the maximum falls.
	 * - NARROWIN: Use long intervals to narrow in on a final passing level
	 * - RAMPDOWN: Final ramp-down with small intervals to finish out run
	 */
	private enum Phase {INITIALRAMP, APPROXIMATE, NARROWIN, RAMPDOWN};
	private enum Direction {INCREASING, DECREASING};

	@JsonIgnore
	private Phase curPhase = Phase.INITIALRAMP;
	
	@JsonIgnore
	private long curUsers = 0;

	@JsonIgnore
	private Direction direction = Direction.INCREASING;
	@JsonIgnore
	private long intervalNum = 0;
	
	@JsonIgnore
	private UniformLoadInterval curInterval = null;
	
	@JsonIgnore
	private long curRateStep = 0;
	
	@JsonIgnore
	private long minFailUsers = Long.MAX_VALUE;
	@JsonIgnore
	private long maxPassUsers = 0;
	@JsonIgnore
	private String maxPassIntervalName = null;
	
	@JsonIgnore
	private final long minRateStep = maxUsers / 100;
	
	/*
	 * Use a semaphore to prevent returning stats interval until we have 
	 * determined the next load interval
	 */
	@JsonIgnore
	private final Semaphore statsIntervalAvailable = new Semaphore(0, true);
	
	@Override
	public void initialize(String runName, String workloadName, Workload workload, List<String> hosts, String statsHostName, int portNumber,
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, hosts, statsHostName, portNumber, restTemplate, executorService);

		// The initial step is 1/20 of maxUsers
		curRateStep = maxUsers / 20;
		
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
		intervalNum++;
		
		boolean prevIntervalPassed = true;
		if (intervalNum != 1) {
			String curIntervalName = curInterval.getName();

			/*
			 *  This is the not first interval.  Need to know whether the previous
			 *  interval passed.
			 *  Get the statsSummaryRollup for the previous interval
			 */
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);

			// For initial ramp, only interested in response-time
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassedRT();			
				getIntervalStatsSummaries().add(rollup);
			} 
			logger.debug("getNextInitialRampInterval: Interval " + intervalNum + " prevIntervalPassed = " + prevIntervalPassed);
		} 
		
		/*
		 * If we have reached max users, or the previous interval failed,
		 * then to go to the APPROXIMATE phase
		 */
		if (!prevIntervalPassed || ((curUsers + curRateStep) > maxUsers)) {
			intervalNum = 0;
			curPhase = Phase.APPROXIMATE;
			curRateStep /= 2;
			logger.debug("getNextInitialRampInterval: Moving to APPROXIMATE phase.  curUsers = " 
						+ curUsers + ", curRateStep = " + curRateStep);
			return getNextApproximateInterval();
		}

		curUsers += curRateStep;
		UniformLoadInterval nextInterval = new UniformLoadInterval();
		nextInterval.setUsers(curUsers);
		nextInterval.setDuration(shortIntervalDurationSec);
		nextInterval.setName("InitialRamp-" + intervalNum);
		logger.debug("getNextInitialRampInterval returning interval: " + nextInterval);
		return nextInterval;
	}

	/*
	 * Narrow in on max passing until at 2*minRateStep
	 */
	@JsonIgnore
	private UniformLoadInterval getNextApproximateInterval() {
		logger.debug("getNextApproximateInterval ");

		intervalNum++;		
		
		boolean prevIntervalPassed = false;
		if (intervalNum != 1) {
			String curIntervalName = curInterval.getName();
			/*
			 *  This is the not first interval.  Need to know whether the previous
			 *  interval passed.
			 *  Get the statsSummaryRollup for the previous interval
			 */
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassed();			
				getIntervalStatsSummaries().add(rollup);
			} 
		}		
		logger.debug("getNextApproximateInterval: Interval " + intervalNum + " prevIntervalPassed = " + prevIntervalPassed);

		if (prevIntervalPassed && (curUsers == maxUsers)) {
			/*
			 * Already passing at maxUsers.  The actual maximum must be higher than
			 * we can run, so just end the run.
			 */
			logger.debug("getNextApproximateInterval. At max users, so can't advance.  Ending workload and returning curInterval: " + curInterval);
			loadPathComplete();
			return curInterval;
		} else if (prevIntervalPassed && ((curUsers + curRateStep) > maxUsers)) {
			/*
			 * Can't step up beyond maxUsers, so just go to maxUsers.
			 * Reduce the curStep to halfway between curUsers and maxUsers
			 */
			logger.debug("getNextApproximateInterval: Next interval would have passed maxUsers, using maxUsers");
			curRateStep = (maxUsers - curUsers) /2;
			curUsers = maxUsers;
		} else if (prevIntervalPassed) {
			if (curUsers > maxPassUsers) {
				maxPassUsers = curUsers;
				maxPassIntervalName = curInterval.getName();
			}
			
			/*
			 * The next interval needs to be less than minFailUsers.  May need 
			 * to shrink the step size in order to do this.
			 */
			long nextRateStep = curRateStep;
			while ((curUsers + nextRateStep) > minFailUsers) {
				nextRateStep /= 2;
				if (nextRateStep < minRateStep) {
					nextRateStep = minRateStep;
					break;
				}
			}
			
			if ((curUsers + nextRateStep) >= minFailUsers) {
				/*
				 * Can't get closer to maximum with the minRateStep.
				 * Go to the next phase.
				 */
				logger.debug("getNextApproximateInterval: Can't get closer to maximum with minRateStep, going to next phase");
				intervalNum = 0;
				curPhase = Phase.NARROWIN;
				curRateStep /= 2;
				return getNextNarrowInInterval();
			}
			
			curRateStep = nextRateStep;
			curUsers +=  curRateStep;
		} else {
			// prevIntervalFailed
			if (curUsers < minFailUsers) {
				minFailUsers = curUsers;
			}
			
			/*
			 * The next interval needs to be less than minFailUsers.  May need 
			 * to shrink the step size in order to do this.
			 */
			long nextRateStep = curRateStep;
			while ((curUsers - nextRateStep) <= maxPassUsers) {
				nextRateStep /= 2;
				if (nextRateStep < minRateStep) {
					nextRateStep = minRateStep;
					break;
				}
			}
			
			if ((curUsers - nextRateStep) < maxPassUsers) {
				/*
				 * Can't get closer to maximum with the minRateStep.
				 * Go to the next phase.
				 */
				logger.debug("getNextApproximateInterval: Can't get closer to maximum with minRateStep, going to next phase");
				intervalNum = 0;
				curPhase = Phase.NARROWIN;
				curRateStep /= 2;
				return getNextNarrowInInterval();
			}
			
			curRateStep = nextRateStep;
			curUsers -=  curRateStep;

		}
		
		UniformLoadInterval nextInterval = new UniformLoadInterval();
		nextInterval.setUsers(curUsers);
		nextInterval.setDuration(mediumIntervalDurationSec);
		nextInterval.setName("APPROXIMATE-" + intervalNum);
		logger.debug("getNextApproximateInterval. returning interval: " + nextInterval);
		return nextInterval;
	}

	/*
	 * Narrow in on max passing until at minRateStep
	 */
	@JsonIgnore
	private UniformLoadInterval getNextNarrowInInterval() {
		logger.debug("getNextNarrowInInterval ");

		intervalNum++;
		if (intervalNum == 1) {
			/*
			 * Reset the pass/fail bounds so that we can narrow in with longer runs.
			 */
			minFailUsers = Long.MAX_VALUE;
			maxPassUsers = 0;
			maxPassIntervalName = null;
			
			/*
			 * First interval of APPROXIMATE should just be a longer 
			 * run at the same level that INITIALRAMP ended on.
			 */
			UniformLoadInterval nextInterval = new UniformLoadInterval();
			nextInterval.setUsers(curUsers);
			nextInterval.setDuration(longIntervalDurationSec);
			nextInterval.setName("NARROWIN-" + intervalNum);
			logger.debug("getNextNarrowInInterval first interval. returning interval: " + nextInterval);
			return nextInterval;
		}  
		
		/*
		 *  This is the not first interval.  Need to know whether the previous
		 *  interval passed.
		 *  Get the statsSummaryRollup for the previous interval
		 */
		String curIntervalName = curInterval.getName();
		StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
		boolean prevIntervalPassed = false;
		if (rollup != null) {
			prevIntervalPassed = rollup.isIntervalPassed();			
			getIntervalStatsSummaries().add(rollup);
		} 
		logger.debug("getNextNarrowInInterval: Interval " + intervalNum + " prevIntervalPassed = " + prevIntervalPassed);

		if (prevIntervalPassed && (curUsers == maxUsers)) {
			/*
			 * Already passing at maxUsers.  The actual maximum must be higher than
			 * we can run, so just end the run.
			 */
			logger.debug("getNextNarrowInInterval. At max users, so can't advance.  Ending workload and returning curInterval: " + curInterval);
			loadPathComplete();
			return curInterval;
		} else if (prevIntervalPassed && ((curUsers + curRateStep) > maxUsers)) {
			/*
			 * Can't step up beyond maxUsers, so just go to maxUsers.
			 * Reduce the curStep to halfway between curUsers and maxUsers
			 */
			curRateStep = (maxUsers - curUsers) /2;
			curUsers = maxUsers;
			logger.debug("getNextNarrowInInterval: Next interval would have passed maxUsers, using maxUsers");
		} else if (prevIntervalPassed) {
			if (curUsers > maxPassUsers) {
				maxPassUsers = curUsers;
				maxPassIntervalName = curInterval.getName();
			}
			
			/*
			 * The next interval needs to be less than minFailUsers.  May need 
			 * to shrink the step size in order to do this.
			 */
			long nextRateStep = curRateStep;
			while ((curUsers + nextRateStep) > minFailUsers) {
				nextRateStep /= 2;
				if (nextRateStep < minRateStep) {
					nextRateStep = minRateStep;
					break;
				}
			}
			
			if ((curUsers + nextRateStep) >= minFailUsers) {
				/*
				 * Can't get closer to maximum with the minRateStep.
				 * Have found the maximum
				 */
				logger.debug("getNextNarrowInInterval: Can't get closer to maximum. Found maximum at " + maxPassUsers);
				loadPathComplete();
				return curInterval;
			}
			
			curRateStep = nextRateStep;
			curUsers +=  curRateStep;
		} else {
			// prevIntervalFailed
			if (curUsers < minFailUsers) {
				minFailUsers = curUsers;
			}
			
			/*
			 * The next interval needs to be less than minFailUsers.  May need 
			 * to shrink the step size in order to do this.
			 */
			long nextRateStep = curRateStep;
			while ((curUsers - nextRateStep) <= maxPassUsers) {
				nextRateStep /= 2;
				if (nextRateStep < minRateStep) {
					nextRateStep = minRateStep;
					break;
				}
			}
			
			if ((curUsers - nextRateStep) < maxPassUsers) {
				/*
				 * Can't get closer to maximum with the minRateStep.
				 * Have found the maximum
				 */
				logger.debug("getNextApproximateInterval: Can't get closer to maximum. Found maximum at " + maxPassUsers);
				loadPathComplete();
				return curInterval;
			}
			
			curRateStep = nextRateStep;
			curUsers -=  curRateStep;

		}
		
		UniformLoadInterval nextInterval = new UniformLoadInterval();
		nextInterval.setUsers(curUsers);
		nextInterval.setDuration(longIntervalDurationSec);
		nextInterval.setName("NARROWIN-" + intervalNum);
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
			 *  Pass up the maximum number of users that passed a steady
			 *  interval.  	
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

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

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "interval")
public class IntervalLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(IntervalLoadPath.class);
	
	private List<LoadInterval> loadIntervals = new ArrayList<LoadInterval>();
	
	@JsonIgnore
	private List<UniformLoadInterval> uniformIntervals = null;
	
	@JsonIgnore
	private int nextIntervalIndex = 0;
	
	@JsonIgnore
	private int nextStatsIntervalIndex = 0;
	
	@JsonIgnore
	private long maxPassUsers = 0;
	
	@JsonIgnore
	private String maxPassIntervalName = null;
	
	@Override
	public void initialize(String runName, String workloadName, Workload workload, List<String> hosts, String statsHostName, int portNumber, RestTemplate restTemplate, 
			ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, hosts, statsHostName, portNumber, restTemplate, executorService);
		
		uniformIntervals = new ArrayList<UniformLoadInterval>();
		
		/*
		 * Create a list of uniform intervals from the list of
		 * uniform and ramp intervals
		 */
		boolean firstInterval = true;
		long previousIntervalEndUsers = 0;
		for (LoadInterval interval : loadIntervals) {
			Long duration = interval.getDuration();
			if (duration == null) {
				logger.error("The parameter duration must be specified for all ramp load intervals.");
				System.exit(1);				
			}
			
			if (interval instanceof UniformLoadInterval) {
				UniformLoadInterval uniformInterval = (UniformLoadInterval) interval;
				
				long users = uniformInterval.getUsers(); 

				logger.debug("For intervalLoadPath " + getName() + ", interval = " + interval.getName() 
						+ ", users = " + users);
				UniformLoadInterval newInterval = new UniformLoadInterval(users, interval.getDuration());
				newInterval.setName(interval.getName());
				uniformIntervals.add(newInterval);
				previousIntervalEndUsers = users;
			} else if (interval instanceof RampLoadInterval) {
				/*
				 * Turn the single ramp interval into a series of uniform 
				 * intervals where the number of users changes each timeStep seconds
				 */
				RampLoadInterval rampInterval = (RampLoadInterval) interval;
				long timeStep = rampInterval.getTimeStep();
				long numIntervals = (long) Math.ceil(duration / (timeStep * 1.0));
												
				Long endUsers = rampInterval.getEndUsers();
				if (endUsers == null) {
					logger.error("The parameter endUsers must be specified for all ramp load intervals.");
					System.exit(1);
				} 

				Long startUsers = rampInterval.getStartUsers();
				if (startUsers == null) {
					if (firstInterval) {
						/*
						 * If we have a ramp in the first interval, then set
						 * the starting number of users one increment up, so
						 * we don't start at 0
						 */
						startUsers = (long) Math.ceil(Math.abs(endUsers) / ((numIntervals - 1) * 1.0));
					} else {
						startUsers = previousIntervalEndUsers;						
					}
				}
				
				previousIntervalEndUsers = endUsers;
				
				/*
				 * When calculating the change in users per interval, need to 
				 * subtract one interval since the first interval is at startUsers
				 */
				long usersPerInterval = (long) Math.ceil(Math.abs(endUsers - startUsers) / ((numIntervals - 1) * 1.0));
				if (endUsers < startUsers) {
					usersPerInterval *= -1;
				}
				
				long totalDuration = 0;
				for (long i =0; i < numIntervals; i++) {
					long curUsers = startUsers + (i * usersPerInterval);
					if (endUsers < startUsers) {
						if (curUsers < endUsers) {
							curUsers = endUsers;
						}
					} else {
						if (curUsers > endUsers) {
							curUsers = endUsers;
						}
					}
					
					if ((totalDuration + timeStep) > duration) {
						timeStep = duration - totalDuration;
						if (timeStep <= 0) {
							break;
						}
					}
					
					UniformLoadInterval newInterval = new UniformLoadInterval(curUsers, timeStep);
					logger.debug("For intervalLoadPath " + getName() + ", interval = " + interval.getName() 
					+ ", adjustedUsers = " + curUsers);

					newInterval.setName(interval.getName());
					uniformIntervals.add(newInterval);

					totalDuration += timeStep;
					
				}
			}
			firstInterval = false;
		}
		
	}
		
	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {
		
		logger.debug("getNextInterval, nextIntervalIndex = " + nextIntervalIndex);
		if ((uniformIntervals == null) || (uniformIntervals.size() == 0)) {
			logger.debug("getNextInterval returning null");
			return null;
		}
 
		UniformLoadInterval nextInterval;
		if (nextIntervalIndex >= uniformIntervals.size()) {
			/*
			 * At end of intervals, signal that loadPath is complete.
			 * Keep returning the last interval
			 */
			boolean passed = false;
			if (maxPassUsers > 0) {
				/*
				 *  Pass up the maximum number of users that passed a steady
				 *  interval.  This is not the real passing criteria for an
				 *  interval load path, but may be useful info.				
				 */
				passed = true;
			}
			WorkloadStatus status = new WorkloadStatus();
			status.setIntervalStatsSummaries(getIntervalStatsSummaries());
			status.setMaxPassUsers(maxPassUsers);
			status.setMaxPassIntervalName(maxPassIntervalName);
			status.setPassed(passed);
			workload.loadPathComplete(status);
			nextInterval = uniformIntervals.get(nextIntervalIndex-1);
		} else {
			nextInterval = uniformIntervals.get(nextIntervalIndex);
			nextIntervalIndex++;
		}
		
		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;

	}

	
	@JsonIgnore
	@Override
	public LoadInterval getNextStatsInterval() {
		logger.debug("getNextStatsInterval, nextStatsIntervalIndex = " + nextStatsIntervalIndex);
		
		if (nextStatsIntervalIndex != 0) {
			int curIntervalIndex = nextStatsIntervalIndex - 1;
			String curIntervalName = loadIntervals.get(curIntervalIndex).getName();			
			StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
			boolean prevIntervalPassed = false;
			if (rollup != null) {
				prevIntervalPassed = rollup.isIntervalPassed();			
				long startUsers = rollup.getStartActiveUsers();
				long endUsers = rollup.getEndActiveUsers();

				// Only non-ramp intervals can be passing
				if ((startUsers == endUsers) && prevIntervalPassed && (endUsers > maxPassUsers)) {
					maxPassUsers = endUsers;
					maxPassIntervalName = curIntervalName;
				}
				
				getIntervalStatsSummaries().add(rollup);
			}

		}
		
		LoadInterval nextStatsInterval;
		if (nextStatsIntervalIndex >= loadIntervals.size()) {
			/*
			 * At end of intervals.  keep returning last interval 
			 */
			nextStatsInterval = loadIntervals.get(nextStatsIntervalIndex-1);			
		} else {
			nextStatsInterval = loadIntervals.get(nextStatsIntervalIndex);
			

			nextStatsIntervalIndex++;			
		}
		
		curStatusInterval.setName(nextStatsInterval.getName());
		curStatusInterval.setDuration(nextStatsInterval.getDuration());
		if (nextStatsInterval instanceof UniformLoadInterval) {
			UniformLoadInterval uniformInterval = (UniformLoadInterval) nextStatsInterval;
			curStatusInterval.setStartUsers(uniformInterval.getUsers());
			curStatusInterval.setEndUsers(uniformInterval.getUsers());			
		} else if (nextStatsInterval instanceof RampLoadInterval) {
			RampLoadInterval rampInterval = (RampLoadInterval) nextStatsInterval;
			curStatusInterval.setStartUsers(rampInterval.getStartUsers());
			curStatusInterval.setEndUsers(rampInterval.getEndUsers());			
		}
		logger.debug("getNextStatsInterval returning interval: " + nextStatsInterval);
		return nextStatsInterval;
	}

	@Override
	public RampLoadInterval getCurStatusInterval() {
		return getCurStatusInterval();
	}

	public final List<LoadInterval> getLoadIntervals() {
		return loadIntervals;
	}

	public void setLoadIntervals(List<LoadInterval> loadIntervals) {
		this.loadIntervals = loadIntervals;
	}
	
	public void addLoadInterval(LoadInterval interval) {
		loadIntervals.add(interval);
	}
	
	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("IntervalLoadPath: ");
		theStringBuilder.append("numLoadIntervals: " + loadIntervals.size()); 
		
		int i = 0;
		for (LoadInterval interval : loadIntervals) {
			theStringBuilder.append("\n\tLoadInterval" + i + ": " + interval.toString());
		}
		
		return theStringBuilder.toString();
	}
	
}

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
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "interval")
public class IntervalLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(IntervalLoadPath.class);
	
	private List<LoadInterval> loadIntervals = new ArrayList<LoadInterval>();
	
	@JsonIgnore
	private List<UniformLoadInterval> uniformIntervals = null;
	
	@JsonIgnore
	private Map<String, Integer> nextIntervalIndices = new HashMap<String, Integer>();
	
	@JsonIgnore
	private Map<String, Integer> nextStatsIntervalIndices = new HashMap<String, Integer>();
	
	@Override
	public void initialize(String name, Integer nodeNumber, Integer numNodes) {
		super.initialize(name, nodeNumber, numNodes);
		
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
				
				long adjustedUsers = adjustUserCount(uniformInterval.getUsers(), numNodes); 
				logger.debug("For intervalLoadPath " + getName() + ", interval = " + interval.getName() 
						+ ", adjustedUsers = " + adjustedUsers);
				UniformLoadInterval newInterval = new UniformLoadInterval(adjustedUsers, interval.getDuration());
				newInterval.setName(interval.getName());
				uniformIntervals.add(newInterval);
				if (adjustedUsers > maxUsers) {
					maxUsers = adjustedUsers;
				}
				previousIntervalEndUsers = adjustedUsers;
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
				} else {
					endUsers = adjustUserCount(endUsers, numNodes);
				}
				previousIntervalEndUsers = endUsers;
								
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
				} else {
					startUsers = adjustUserCount(startUsers, numNodes);
				}
				
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

					if (curUsers > maxUsers) {
						maxUsers = curUsers;
					}

					totalDuration += timeStep;
					
				}
			}
			firstInterval = false;
		}
		logger.debug("For intervalLoadPath " + getName() + ", maxUsers = " + this.maxUsers);
		
	}
		
	@Override
	public UniformLoadInterval getNextInterval(String targetName) {
		logger.debug("getNextInterval for target " + targetName);
		if ((uniformIntervals == null) || (uniformIntervals.size() == 0)) {
			logger.debug("getNextInterval for target " + targetName + " returning null");
			return null;
		}

		if (!nextIntervalIndices.containsKey(targetName)) {
			nextIntervalIndices.put(targetName, 0);
		}
		
		Integer nextIntervalIndex = nextIntervalIndices.get(targetName);
		logger.debug("getNextInterval for target " + targetName + ", nextIntervalIndex = " + nextIntervalIndex);

		/* 
		 * wrap at end of intervals
		 */
		if (nextIntervalIndex >= uniformIntervals.size()) {
			nextIntervalIndex = 0;
		}
		
		UniformLoadInterval nextInterval = uniformIntervals.get(nextIntervalIndex);
		nextIntervalIndex++;
		
		nextIntervalIndices.put(targetName, nextIntervalIndex);
		logger.debug("getNextInterval for target " + targetName + ", returning interval: " + nextInterval);
		return nextInterval;
	}

	
	@Override
	public LoadInterval getNextStatsInterval(String targetName) {
		logger.debug("getNextStatsInterval for target " + targetName);

		if (!nextStatsIntervalIndices.containsKey(targetName)) {
			nextStatsIntervalIndices.put(targetName, 0);
		}		
		Integer nextStatsIntervalIndex = nextStatsIntervalIndices.get(targetName);
		
		logger.debug("getNextStatsInterval for target " + targetName + ", nextStatsIntervalIndex = " + nextStatsIntervalIndex);

		/* 
		 * wrap at end of intervals
		 */
		if (nextStatsIntervalIndex >= loadIntervals.size()) {
			nextStatsIntervalIndex = 0;
		}
		
		LoadInterval nextStatsInterval = loadIntervals.get(nextStatsIntervalIndex);
		nextStatsIntervalIndex++;
		
		nextStatsIntervalIndices.put(targetName, nextStatsIntervalIndex);
		logger.debug("getNextStatsInterval for target " + targetName + ", returning interval: " + nextStatsInterval);
		return nextStatsInterval;
	}

	private long adjustUserCount(long originalUserCount, int numRemoteNodes) {
		
		long adjustedUserCount = originalUserCount / numRemoteNodes;

		/*
		 * Add an additional user from the remainder for the first 
		 * usersRemaining nodes
		 */
		long usersRemaining = originalUserCount - (numRemoteNodes * adjustedUserCount);	
		if (usersRemaining > getNodeNumber()) {
			adjustedUserCount++;
		}
		
		return adjustedUserCount;
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

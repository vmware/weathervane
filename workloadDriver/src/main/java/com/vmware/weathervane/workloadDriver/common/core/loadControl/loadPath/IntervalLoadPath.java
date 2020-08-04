/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

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
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.LoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.UniformLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeName(value = "interval")
public class IntervalLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(IntervalLoadPath.class);
	
	private List<LoadInterval> loadIntervals;

	private long runDuration = 1800;

	private boolean repeatLoadPath = false;

	private boolean runForever = false;

	@JsonIgnore
	private List<UniformLoadInterval> uniformIntervals = null;
	
	@JsonIgnore
	private int curIntervalIndex = -1;
	
	@JsonIgnore
	private int curStatsIntervalIndex = 0;
	
	@JsonIgnore
	private long remainingRunDuration;
	
	@JsonIgnore
	private long maxPassUsers = 0;
	
	@JsonIgnore
	private String maxPassIntervalName = null;

	@JsonIgnore
	private boolean statsIntervalComplete = false;
		
	@JsonIgnore
	private boolean curIntervalEndOfStats = false;
	
	@JsonIgnore
	private boolean repeatingLastInterval = false;
	
	@JsonIgnore
	private UniformLoadInterval curStatsInterval;
	
	@Override
	public void initialize(String runName, String workloadName, Workload workload, LoadPathController loadPathController,
			List<String> hosts, String statsHostName, int portNumber, RestTemplate restTemplate, 
			ScheduledExecutorService executorService) {
		super.initialize(runName, workloadName, workload, loadPathController, 
				hosts, statsHostName, portNumber, restTemplate, executorService);
		logger.debug("initialize: There are " + loadIntervals.size() + " loadIntervals" 
				+ ", runDuration = " + runDuration
				+ ", repeatLoadPath = " + repeatLoadPath
				+ ", runForever = " + runForever
				);
		
		uniformIntervals = new ArrayList<UniformLoadInterval>();
		remainingRunDuration = runDuration;
		/*
		 * Create a list of uniform intervals from the list of
		 * uniform and ramp intervals
		 */
		boolean firstInterval = true;
		long previousIntervalEndUsers = 0;
		int intervalCount = 1;
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
				newInterval.setEndOfStatsInterval(true);

				logger.debug("For intervalLoadPath " + getName() 
				           + ", interval = " + interval.getName() 
				           + ", users = " + users
				           + ", intervalCount = " + intervalCount
				           + ", endOfStatsInterval = " + newInterval.isEndOfStatsInterval()
				);
				uniformIntervals.add(newInterval);
				intervalCount++;
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
				for (long i = 0; i < numIntervals; i++) {
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
					newInterval.setName(interval.getName());
					if ((i+1) == numIntervals) {
						newInterval.setEndOfStatsInterval(true);
					}

					logger.debug("For intervalLoadPath " + getName() 
					           + ", interval = " + interval.getName() 
					           + ", adjustedUsers = " + curUsers
					           + ", intervalCount = " + intervalCount
					           + ", endOfStatsInterval = " + newInterval.isEndOfStatsInterval()
					);
					uniformIntervals.add(newInterval);
					intervalCount++;

					totalDuration += timeStep;
					
				}
			}
			firstInterval = false;
		}
		logger.debug("initialize: There are " + uniformIntervals.size() + " uniform intervals");
		// Initialize the curStats and curStatus intervals to the first interval
		logger.debug("initialize: Initializing curStatsInverval");
		LoadInterval firstLoadInterval = loadIntervals.get(0);
		if (firstLoadInterval != null) {
			curStatsInterval = new UniformLoadInterval();
			curStatsInterval.setDuration(firstLoadInterval.getDuration());
			curStatsInterval.setName(firstLoadInterval.getName());
			if (firstLoadInterval instanceof UniformLoadInterval) {
				UniformLoadInterval uniformInterval = (UniformLoadInterval) firstLoadInterval;
				curStatsInterval.setUsers(uniformInterval.getUsers());
			} else if (firstLoadInterval instanceof RampLoadInterval) {
				RampLoadInterval rampInterval = (RampLoadInterval) firstLoadInterval;
				curStatsInterval.setUsers(rampInterval.getEndUsers());
			}

			curStatusInterval = new RampLoadInterval();
			curStatusInterval.setName(firstLoadInterval.getName());
			curStatusInterval.setDuration(firstLoadInterval.getDuration());
			if (firstLoadInterval instanceof UniformLoadInterval) {
				UniformLoadInterval uniformInterval = (UniformLoadInterval) firstLoadInterval;
				curStatusInterval.setStartUsers(uniformInterval.getUsers());
				curStatusInterval.setEndUsers(uniformInterval.getUsers());
			} else if (firstLoadInterval instanceof RampLoadInterval) {
				RampLoadInterval rampInterval = (RampLoadInterval) firstLoadInterval;
				curStatusInterval.setStartUsers(rampInterval.getStartUsers());
				curStatusInterval.setEndUsers(rampInterval.getEndUsers());
			}
		} else {
			logger.error("initialize: Can't initialize curStatsInterval.  loadIntervals is empty");
		}
		
	}
		
	@JsonIgnore
	@Override
	public UniformLoadInterval getNextInterval() {
		
		logger.debug("getNextInterval, curIntervalIndex = " + curIntervalIndex);
		statsIntervalComplete = false;
		if ((uniformIntervals == null) || (uniformIntervals.size() == 0)) {
			logger.error("getNextInterval returning null");
			return null;
		}
 
		UniformLoadInterval nextInterval;
		if (remainingRunDuration == 0) {
			/*
			 * At end of runDuration, signal that loadPath is complete.
			 * Keep returning the last interval
			 */
			logger.debug("getNextInterval: remainingRunDuration = 0, setting loadPathComplete");
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
			status.setLoadPathName(this.getName());
			workload.loadPathComplete(status);
			nextInterval = uniformIntervals.get(curIntervalIndex);
		} else {
			curIntervalIndex++;
			if (curIntervalIndex == uniformIntervals.size()) {
				if (repeatLoadPath || runForever) {
					logger.debug("getNextInterval: repeating load path");
					curIntervalIndex = 0;
				} else {
					// Otherwise we leave curIntervalIndex at the last interval
					curIntervalIndex--;
					repeatingLastInterval = true;
				}
			}
			
			nextInterval = uniformIntervals.get(curIntervalIndex);
			if (!runForever) {
				// Only decrement remainingRunDuration if not running forever 
				if (nextInterval.getDuration() > remainingRunDuration) {
					logger.debug("getNextInterval: Duration " + nextInterval.getDuration() + " greater than remainingRunDuration " 
							+ remainingRunDuration);
					nextInterval.setDuration(nextInterval.getDuration() - remainingRunDuration);
					remainingRunDuration = 0;
				} else {
					logger.debug("getNextInterval: decrementing remainingRunDuration by " + nextInterval.getDuration());
					remainingRunDuration -= nextInterval.getDuration();
				}
			}
			
			logger.debug("getNextInterval: " + "remainingRunDuration = " + remainingRunDuration + 
					", curIntervalIndex = " + curIntervalIndex +
					", users = " + nextInterval.getUsers() +
					", duration = " + nextInterval.getDuration()
					);

			if (curIntervalEndOfStats && !repeatingLastInterval) {
				logger.debug("getNextInterval: curIntervalEndOfStats\n");
				// Get the rollup for the previous interval
				String curIntervalName = "Interval-" + curStatsIntervalIndex;			
				StatsSummaryRollup rollup = fetchStatsSummaryRollup(curIntervalName);
				logger.debug("getNextInterval: curIntervalEndOfStats got rollup\n");
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
				
				// Set the curStats and curStatus to the new current interval
				curStatsIntervalIndex++;
				int indexForCurStatsInterval = curStatsIntervalIndex % loadIntervals.size();
				logger.debug("getNextInterval: curStatsIntervalIndex = " + curStatsIntervalIndex
						+ " Getting curLoadInterval for index " + indexForCurStatsInterval);
				LoadInterval curLoadInterval = loadIntervals.get(indexForCurStatsInterval);
				curStatsInterval.setDuration(curLoadInterval.getDuration());
				curStatsInterval.setName("Interval-" + curStatsIntervalIndex);
				if (curLoadInterval instanceof UniformLoadInterval) {
					UniformLoadInterval uniformInterval = (UniformLoadInterval) curLoadInterval;
					curStatsInterval.setUsers(uniformInterval.getUsers());
				} else if (curLoadInterval instanceof RampLoadInterval) {
					RampLoadInterval rampInterval = (RampLoadInterval) curLoadInterval;
					curStatsInterval.setUsers(rampInterval.getEndUsers());			
				}
				curStatusInterval.setName("Interval-" + curStatsIntervalIndex);
				curStatusInterval.setDuration(curLoadInterval.getDuration());
				if (curLoadInterval instanceof UniformLoadInterval) {
					UniformLoadInterval uniformInterval = (UniformLoadInterval) curLoadInterval;
					curStatusInterval.setStartUsers(uniformInterval.getUsers());
					curStatusInterval.setEndUsers(uniformInterval.getUsers());			
				} else if (curLoadInterval instanceof RampLoadInterval) {
					RampLoadInterval rampInterval = (RampLoadInterval) curLoadInterval;
					curStatusInterval.setStartUsers(rampInterval.getStartUsers());
					curStatusInterval.setEndUsers(rampInterval.getEndUsers());			
				}
			}
			
			curIntervalEndOfStats = nextInterval.isEndOfStatsInterval();
			if (curIntervalEndOfStats) {
				statsIntervalComplete = true;
			}
		}
				
		logger.debug("getNextInterval returning interval: " + nextInterval);
		return nextInterval;

	}

	@JsonIgnore
	@Override
	public boolean isStatsIntervalComplete() {
		logger.debug("isStatsIntervalComplete returning: " + statsIntervalComplete);
		return statsIntervalComplete;
	}

	@JsonIgnore
	@Override
	public UniformLoadInterval getCurStatsInterval() {		
		logger.debug("getCurStatsInterval returning: " + curStatsInterval);
		return curStatsInterval;
	}

	@Override
	@JsonIgnore
	public RampLoadInterval getCurStatusInterval() {
		logger.debug("getCurStatusInterval returning: " + curStatusInterval);
		return curStatusInterval;
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
	
	public long getRunDuration() {
		return runDuration;
	}

	public void setRunDuration(long runDuration) {
		this.runDuration = runDuration;
	}

	public boolean isRepeatLoadPath() {
		return repeatLoadPath;
	}

	public void setRepeatLoadPath(boolean repeatLoadPath) {
		this.repeatLoadPath = repeatLoadPath;
	}

	public boolean isRunForever() {
		return runForever;
	}

	public void setRunForever(boolean runForever) {
		this.runForever = runForever;
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

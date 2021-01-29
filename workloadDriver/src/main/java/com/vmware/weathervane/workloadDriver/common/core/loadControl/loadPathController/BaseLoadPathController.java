/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Map.Entry;
import java.util.concurrent.Future;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;

public abstract class BaseLoadPathController implements LoadPathController {

	private static final Logger logger = LoggerFactory.getLogger(BaseLoadPathController.class);

	protected Map<String, LoadPathIntervalResultWatcher> watchers = new HashMap<>();
	protected int numWatchers = 0;
	protected Map<String, Integer> numIntervalResults = new HashMap<>();

	boolean useCombinedResults = true;
	protected Map<String, Boolean> intervalCombinedResults = new HashMap<>();	
	protected Map<String, Boolean> loadPathIndividualResults = new HashMap<>();
	

	private ScheduledExecutorService executorService;

	@Override
	public void initialize(ScheduledExecutorService executorService) {
		this.executorService = executorService;
	}
	
	@Override
	public void registerIntervalResultCallback(String name, LoadPathIntervalResultWatcher watcher) {
		logger.debug("registerIntervalResultCallback for loadPath {}", name);

		watchers.put(name, watcher);
		numWatchers++;
		logger.debug("registerIntervalResultCallback for loadPath {}, numWatchers = {}", 
				name, numWatchers);
	}

	@Override
	public synchronized void postIntervalResult(String loadPathName, String intervalName, boolean passed) {
		loadPathIndividualResults.put(loadPathName, passed);
		
		int curNumResults = 0;
		if (!numIntervalResults.containsKey(intervalName)) {
			curNumResults = 1;
			intervalCombinedResults.put(intervalName, passed);
		} else {
			curNumResults = numIntervalResults.get(intervalName) + 1;
			boolean isLastInInterval = false;
			if (curNumResults == numWatchers) {
				isLastInInterval = true;
			}
			intervalCombinedResults.put(intervalName, 
					combineIntervalResults(intervalCombinedResults.get(intervalName), passed, isLastInInterval));
		}
		numIntervalResults.put(intervalName, curNumResults);

		logger.debug("postIntervalResult for loadPath {}, interval {}, passed {}, curNumResults {}, numWatchers {}, result: {}",
				loadPathName, intervalName, passed, curNumResults, numWatchers, intervalCombinedResults.get(intervalName));
		if (curNumResults == numWatchers) {
			logger.debug("postIntervalResult notifying watchers for interval {} with result {}", 
					intervalName, intervalCombinedResults.get(intervalName));
			notifyWatchers(intervalName);
		}
	}
	
	protected abstract boolean combineIntervalResults(boolean previousResult, 
									boolean latestResult, boolean isLastInInterval);
	
	protected void notifyWatchers(String intervalName) {
		logger.info("notifyWatchers for interval {}", intervalName);
		boolean intervalCombinedResult = intervalCombinedResults.get(intervalName);
		/*
		 * Notify the watchers in parallel to avoid waiting for all of the driver nodes 
		 * to be notified of changes in the number of users.
		 * Schedule the change 10ms into the future to allow all 
		 */
		List<Future<?>> sfList = new ArrayList<>();
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			String loadPathName = entry.getKey();
			logger.debug("notifyWatchers for loadPath {}, interval {}, scheduling a notification", 
					loadPathName, intervalName);
			sfList.add(executorService.submit(new Runnable() {
				
				@Override
				public void run() {
					logger.info("notifyWatchers for loadPath {}, interval {}, in scheduled notification", 
							loadPathName, intervalName);
					boolean loadPathResult = intervalCombinedResult;
					if (!useCombinedResults) {
						loadPathResult = loadPathIndividualResults.get(loadPathName);
					}
					entry.getValue().changeInterval(intervalName, loadPathResult);					
				}
			}));
			logger.debug("notifyWatchers for loadPath {},  interval {}, scheduled a notification", 
					loadPathName, intervalName);
		}
		logger.debug("notifyWatchers for interval {}, scheduled all notifications", intervalName);
		
		/*
		 * Now wait for all of the watchers to be notified of the change in interval
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("notifyWatchers for interval {}, getting a result of a notification", intervalName);
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying watcher for interval " + intervalName 
						+ " got exception: " + e.getMessage());
			};
		});
		logger.info("notifyWatchers complete for interval {}", intervalName);
		
		
		/*
		 * Now that all loadPaths have changed users, actually start the next interval.
		 * This call doesn't block so it can happen in series
		 */
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			entry.getValue().startNextInterval();
		}
	}
	
	
	
}

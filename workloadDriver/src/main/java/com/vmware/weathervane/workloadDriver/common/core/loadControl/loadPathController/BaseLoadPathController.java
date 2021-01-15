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
	protected Map<String, Boolean> intervalResults = new HashMap<>();

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
		int curNumResults = 0;
		if (!numIntervalResults.containsKey(intervalName)) {
			curNumResults = 1;
			intervalResults.put(intervalName, passed);
		} else {
			curNumResults = numIntervalResults.get(intervalName) + 1;
			boolean isLastInInterval = false;
			if (curNumResults == numWatchers) {
				isLastInInterval = true;
			}
			intervalResults.put(intervalName, 
					combineIntervalResults(intervalResults.get(intervalName), passed, isLastInInterval));
		}
		numIntervalResults.put(intervalName, curNumResults);

		logger.debug("postIntervalResult for loadPath {}, interval {}, passed {}, curNumResults {}, numWatchers {}, result: {}",
				loadPathName, intervalName, passed, curNumResults, numWatchers, intervalResults.get(intervalName));
		if (curNumResults == numWatchers) {
			logger.debug("postIntervalResult notifying watchers for interval {} with result {}", 
					intervalName, intervalResults.get(intervalName));
			notifyWatchers(intervalName, intervalResults.get(intervalName));
		}
	}
	
	protected abstract boolean combineIntervalResults(boolean previousResult, 
									boolean latestResult, boolean isLastInInterval);
	
	protected void notifyWatchers(String intervalName, boolean passed) {
		logger.debug("notifyWatchers for interval {}, result = {}", intervalName, passed);
		/*
		 * Notify the watchers in parallel to avoid waiting for all of the driver nodes 
		 * to be notified of changes in the number of users
		 */
		List<ScheduledFuture<?>> sfList = new ArrayList<>();
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			logger.debug("notifyWatchers for interval {}, scheduling a notification", intervalName);
			ScheduledFuture<?> sf = executorService.schedule(new Runnable() {
				
				@Override
				public void run() {
					logger.debug("notifyWatchers for interval {}, in scheduled notification");
					entry.getValue().intervalResult(intervalName, passed);					
				}
			}, 0, TimeUnit.MILLISECONDS);
			logger.debug("notifyWatchers for interval {}, scheduled a notification", intervalName);
			sfList.add(sf);
		}
		logger.debug("notifyWatchers for interval {}, scheduled all notifications", intervalName, passed);
		
		/*
		 * Now wait for all of the watchers to be notified
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("notifyWatchers for interval {}, getting a result of a notification", intervalName, passed);
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying watcher for interval " + intervalName 
						+ " got exception: " + e.getMessage());
			};
		});
	}
	
	
	
}

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
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class BaseLoadPathController implements LoadPathController {

	private static final Logger logger = LoggerFactory.getLogger(BaseLoadPathController.class);

	protected Map<String, LoadPathIntervalResultWatcher> watchers = new HashMap<>();
	protected int numWatchers = 0;
	protected Map<Long, Integer> numIntervalResults = new HashMap<>();

	boolean useCombinedResults = true;
	protected Map<Long, Boolean> intervalCombinedResults = new HashMap<>();	
	protected Map<String, Boolean> loadPathIndividualResults = new HashMap<>();
	
	private ExecutorService executorService;
	
	@Override
	public void initialize(int numWorkloads) {
		executorService = Executors.newFixedThreadPool(numWorkloads);
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
	public void removeIntervalResultCallback(String name) {
		logger.debug("removeIntervalResultCallback for loadPath {}", name);

		watchers.remove(name);
		numWatchers--;
		logger.debug("registerIntervalResultCallback for loadPath {}, numWatchers = {}", 
				name, numWatchers);
	}

	@Override
	public synchronized void postIntervalResult(String loadPathName, Long intervalNum, boolean passed) {
		logger.info("postIntervalResult for loadPath {}, interval {}, passed {}",
				loadPathName, intervalNum, passed);

		loadPathIndividualResults.put(loadPathName, passed);
		
		int curNumResults = 0;
		if (!numIntervalResults.containsKey(intervalNum)) {
			curNumResults = 1;
			intervalCombinedResults.put(intervalNum, passed);
		} else {
			curNumResults = numIntervalResults.get(intervalNum) + 1;
			boolean isLastInInterval = false;
			if (curNumResults == numWatchers) {
				isLastInInterval = true;
			}
			intervalCombinedResults.put(intervalNum, 
					combineIntervalResults(intervalCombinedResults.get(intervalNum), passed, isLastInInterval));
		}
		numIntervalResults.put(intervalNum, curNumResults);

		logger.debug("postIntervalResult for loadPath {}, interval {}, passed {}, curNumResults {}, numWatchers {}, result: {}",
				loadPathName, intervalNum, passed, curNumResults, numWatchers, intervalCombinedResults.get(intervalNum));
		if (curNumResults == numWatchers) {
			logger.debug("postIntervalResult notifying watchers for interval {} with result {}", 
					intervalNum, intervalCombinedResults.get(intervalNum));
			notifyWatchers(intervalNum);
		}
	}
	
	protected abstract boolean combineIntervalResults(boolean previousResult, 
									boolean latestResult, boolean isLastInInterval);
	
	protected void notifyWatchers(long intervalNum) {
		logger.info("notifyWatchers for interval {}", intervalNum);
		boolean intervalCombinedResult = intervalCombinedResults.get(intervalNum);
		/*
		 * Notify the watchers in parallel to avoid waiting for all of the driver nodes 
		 * to be notified of changes in the number of users.
		 * Schedule the change 10ms into the future to allow all 
		 */
		List<Future<?>> sfList = new ArrayList<>();
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			String loadPathName = entry.getKey();
			logger.debug("notifyWatchers for loadPath {}, interval {}, scheduling a notification", 
					loadPathName, intervalNum);
			sfList.add(executorService.submit(new Runnable() {
				
				@Override
				public void run() {
					logger.info("notifyWatchers for loadPath {}, interval {}, in scheduled notification", 
							loadPathName, intervalNum);
					boolean loadPathResult = intervalCombinedResult;
					if (!useCombinedResults) {
						loadPathResult = loadPathIndividualResults.get(loadPathName);
					}
					entry.getValue().changeInterval(intervalNum, loadPathResult);					
				}
			}));
			logger.debug("notifyWatchers for loadPath {},  interval {}, scheduled a notification", 
					loadPathName, intervalNum);
		}
		logger.debug("notifyWatchers for interval {}, scheduled all notifications", intervalNum);
		
		/*
		 * Now wait for all of the watchers to be notified of the change in interval
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("notifyWatchers for interval {}, getting a result of a notification", intervalNum);
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying watcher for interval " + intervalNum 
						+ " got exception: " + e.getMessage());
			};
		});
		logger.info("notifyWatchers complete for interval {}", intervalNum);
		
		
		/*
		 * Now that all loadPaths have changed users, actually start the next interval.
		 * This call doesn't block so it can happen in series
		 */
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			entry.getValue().startNextInterval();
		}
	}
	
	
	
}

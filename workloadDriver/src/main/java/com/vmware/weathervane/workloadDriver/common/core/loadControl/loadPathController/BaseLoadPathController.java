package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class BaseLoadPathController implements LoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(BaseLoadPathController.class);

	private Map<String, LoadPathIntervalResultWatcher> watchers = new HashMap<>();
	private int numWatchers = 0;
	private Map<String, Integer> numIntervalResults = new HashMap<>();
	private Map<String, Boolean> intervalResults = new HashMap<>();
	
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
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			entry.getValue().intervalResult(intervalName, passed);
		}
	}
	
}

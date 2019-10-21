package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

public abstract class BaseLoadPathController implements LoadPathController {
	
	private Map<String, LoadPathIntervalResultWatcher> watchers = new HashMap<>();
	private int numWatchers = 0;
	private Map<String, Integer> numIntervalResults = new HashMap<>();
	private Map<String, Boolean> intervalResults = new HashMap<>();
	
	@Override
	public void registerIntervalResultCallback(String name, LoadPathIntervalResultWatcher watcher) {
		watchers.put(name, watcher);
		numWatchers = numWatchers++;
	}

	@Override
	public synchronized void postIntervalResult(String loadPathName, String intervalName, boolean passed) {
		int curNumResults = 0;
		if (!numIntervalResults.containsKey(intervalName)) {
			curNumResults = 1;
			intervalResults.put(intervalName, passed);
		} else {
			curNumResults = numIntervalResults.get(intervalName) + 1;
			intervalResults.put(intervalName, 
					combineIntervalResults(intervalResults.get(intervalName), passed));
		}
		numIntervalResults.put(intervalName, curNumResults);
		if (curNumResults == numWatchers) {
			notifyWatchers(intervalName, intervalResults.get(intervalName));
		}
	}
	
	protected abstract boolean combineIntervalResults(boolean previousResult, boolean latestResult);
	
	protected void notifyWatchers(String intervalName, boolean passed) {
		for (Entry<String, LoadPathIntervalResultWatcher> entry : watchers.entrySet()) {
			entry.getValue().intervalResult(intervalName, passed);
		}
	}
	
}

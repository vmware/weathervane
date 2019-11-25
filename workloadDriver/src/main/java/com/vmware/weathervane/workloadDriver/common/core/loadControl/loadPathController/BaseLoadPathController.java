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
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import java.util.HashMap;
import java.util.Map;
import java.util.Map.Entry;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public abstract class BaseLoadPathController implements LoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(BaseLoadPathController.class);

	protected Map<String, LoadPathIntervalResultWatcher> watchers = new HashMap<>();
	protected int numWatchers = 0;
	protected Map<String, Integer> numIntervalResults = new HashMap<>();
	protected Map<String, Boolean> intervalResults = new HashMap<>();
	
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

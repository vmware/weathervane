package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "syncuntilfail")
public class SyncUntilAllFailThenAsyncLoadPathController extends BaseLoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(SyncUntilAllFailThenAsyncLoadPathController.class);
	private boolean allFailed = false;

	@Override
	public synchronized void postIntervalResult(String loadPathName, String intervalName, boolean passed) {
		
		if (allFailed) {
			/*
			 * Once all loadPaths fail an interval, we treat this as an async
			 * loadPath and just return to each loadPath its own result
			 */
			watchers.get(loadPathName).intervalResult(intervalName, passed);
		} else {
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

			logger.debug(
					"postIntervalResult for loadPath {}, interval {}, passed {}, curNumResults {}, numWatchers {}, result: {}",
					loadPathName, intervalName, passed, curNumResults, numWatchers, intervalResults.get(intervalName));
			if (curNumResults == numWatchers) {
				logger.debug("postIntervalResult notifying watchers for interval {} with result {}", intervalName,
						intervalResults.get(intervalName));
				notifyWatchers(intervalName, intervalResults.get(intervalName));
			}
		}
	}

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, latestResult = {}, isLastInInverval = {}, allFailed = {}", 
				previousResult, latestResult, isLastInInverval, allFailed);
		boolean combinedValue = previousResult || latestResult;
		if (isLastInInverval && !combinedValue) {
			allFailed = true;
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}
}

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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "syncuntilhalffail")
public class SyncUntilHalfFailThenAsyncLoadPathController extends BaseLoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(SyncUntilHalfFailThenAsyncLoadPathController.class);
	private boolean runAsync = false;
	private int numPassed = 0;
	private int numFailed = 0;

	@Override
	public synchronized void postIntervalResult(String loadPathName, String intervalName, boolean passed) {
		
		if (runAsync) {
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
				numPassed = 0;
				numFailed = 0;
				notifyWatchers(intervalName, intervalResults.get(intervalName));
			}
		}
	}

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, latestResult = {}, isLastInInverval = {}, allFailed = {}", 
				previousResult, latestResult, isLastInInverval, runAsync);
		if (latestResult) {
			numPassed++;
		} else {
			numFailed++;
		}
	
		boolean combinedValue = previousResult || latestResult;
		if (isLastInInverval && (numFailed >= numPassed)) {
			/*
			 * Switch to running async when more instances fail in
			 * an interval than pass 
			 */
			runAsync = true;
			combinedValue = false;
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}
}

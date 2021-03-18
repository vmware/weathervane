/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, latestResult = {}, isLastInInverval = {}, allFailed = {}", 
				previousResult, latestResult, isLastInInverval, runAsync);
		if (latestResult) {
			numPassed++;
		} else {
			numFailed++;
		}
		
		boolean combinedValue = true;
		if (numFailed >= numPassed) {
			combinedValue = false;
		}
		
		if (isLastInInverval) {
			numPassed = 0;
			numFailed = 0;

			if (runAsync) {
				useCombinedResults = false;
			}
			
			/*
			 * Switch to running async when more instances fail in
			 * an interval than pass.  This takes effect next interval 
			 */
			if (!combinedValue) {
				runAsync = true;
			}
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}
}

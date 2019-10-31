package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "anypassuntilhalffail")
public class AnyPassUntilHalfFailLoadPathController extends BaseLoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(AnyPassUntilHalfFailLoadPathController.class);
	private boolean allMustPass = false;
	private int numPassed = 0;
	private int numFailed = 0;

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, " 
					+ "latestResult = {}, isLastInInverval = {}, allMustPass = {}, "
					+ "numPassed = {}, numFailed = {}",
				previousResult, latestResult, isLastInInverval, allMustPass,
				numPassed, numFailed);
		boolean combinedValue = false;
		if (allMustPass) {
			/*
			 * One we reached an interval where all have failed, then 
			 * we act like an allMustPassLoadController
			 */
			combinedValue = previousResult && latestResult;			
		} else {
			if (latestResult) {
				numPassed++;
			} else {
				numFailed++;
			}
			
			if (isLastInInverval && (numFailed >= numPassed)) {
				allMustPass = true;
				combinedValue = false;
				numPassed = 0;
				numFailed = 0;
			} else {
				combinedValue = previousResult || latestResult;							
			}
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}

}

package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "anypassuntilfail")
public class AnyPassUntilAllFailLoadPathController extends BaseLoadPathController {
	private static final Logger logger = LoggerFactory.getLogger(AnyPassUntilAllFailLoadPathController.class);
	private boolean allFailed = false;

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
		logger.debug("combineIntervalResults previousResult = {}, latestResult = {}, isLastInInverval = {}", 
				previousResult, latestResult, isLastInInverval);
		boolean combinedValue = false;
		if (allFailed) {
			/*
			 * One we reached an interval where all have failed, then 
			 * we act like an allMustPassLoadController
			 */
			combinedValue = previousResult && latestResult;			
		} else {
			combinedValue = previousResult || latestResult;			
			if (isLastInInverval && !combinedValue) {
				allFailed = true;
			}
		}
		logger.debug("combineIntervalResults combinedValue = {}", combinedValue);
		return combinedValue;
	}

}

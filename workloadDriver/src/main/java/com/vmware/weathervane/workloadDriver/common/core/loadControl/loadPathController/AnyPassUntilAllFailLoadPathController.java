package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "anypassuntilfail")
public class AnyPassUntilAllFailLoadPathController extends BaseLoadPathController {
	private boolean allFailed = false;

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult, boolean isLastInInverval) {
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
		return combinedValue;
	}

}

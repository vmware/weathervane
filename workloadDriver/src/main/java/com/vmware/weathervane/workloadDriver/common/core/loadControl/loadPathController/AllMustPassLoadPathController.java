package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

import com.fasterxml.jackson.annotation.JsonTypeName;

@JsonTypeName(value = "allpass")
public class AllMustPassLoadPathController extends BaseLoadPathController {

	@Override
	protected boolean combineIntervalResults(boolean previousResult, boolean latestResult) {
		return previousResult && latestResult;
	}

}

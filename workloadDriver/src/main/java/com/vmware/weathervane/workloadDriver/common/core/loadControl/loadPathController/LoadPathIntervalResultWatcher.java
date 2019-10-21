package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

public interface LoadPathIntervalResultWatcher {
	void intervalResult(String intervalName, boolean intervalResult);
}

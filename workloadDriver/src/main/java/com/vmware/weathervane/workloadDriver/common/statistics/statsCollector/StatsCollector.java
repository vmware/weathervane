package com.vmware.weathervane.workloadDriver.common.statistics.statsCollector;

import java.util.List;

import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.OperationStats;

public interface StatsCollector {
	void submitOperationStats(OperationStats operationStats);

	void statsIntervalComplete(StatsIntervalCompleteMessage completeMessage);

	void setTargetNames(List<String> targetNames);
}

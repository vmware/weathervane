/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics;

import java.io.IOException;

import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryResponseMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryRollupResponseMessage;

public interface StatsService {

	void postStatsSummary(String runName, StatsSummary statsSummary) throws IOException;

	void initializeRun(String runName, InitializeRunStatsMessage initializeRunStatsMessage);

	void runStarted(String runName);
	
	void runComplete(String runName) throws IOException;

	StatsSummaryResponseMessage getStatsSummary(String runName, String workloadName, String specName,
			String intervalName);

	StatsSummaryRollupResponseMessage getStatsSummaryRollup(String runName, String workloadName, String specName,
			String intervalName);

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.service;

import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;

public interface DriverService {

	void addWorkload(String runName, String workloadName, Workload theWorkload) throws DuplicateRunException;

	void stopWorkload(String runName, String workloadName);

	void initializeWorkload(String runName, String workloadName, InitializeWorkloadMessage initializeWorkloadMessage);

	void changeActiveUsers(String runName, String workloadName, long activeUsers);

	void addRun(String runName) throws DuplicateRunException;
	void removeRun(String runName);

	void statsIntervalComplete(String runName, String workloadName,
			StatsIntervalCompleteMessage statsIntervalCompleteMessage);

	void exit(String runName);

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

public interface LoadPathIntervalResultWatcher {
	void changeInterval(String intervalName, boolean intervalResult);

	void startNextInterval();
}

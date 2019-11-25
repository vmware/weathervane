/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController;

public interface LoadPathIntervalResultWatcher {
	void intervalResult(String intervalName, boolean intervalResult);
}

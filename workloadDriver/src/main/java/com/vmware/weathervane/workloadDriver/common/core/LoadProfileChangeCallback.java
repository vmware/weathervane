/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core;

public interface LoadProfileChangeCallback {
	void loadProfileChanged(long numActiveUsers);

	void loadProfilesComplete();
}

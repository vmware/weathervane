package com.vmware.weathervane.workloadDriver.common.core;

public interface LoadProfileChangeCallback {
	void loadProfileChanged(long numActiveUsers);

	void loadProfilesComplete();
}

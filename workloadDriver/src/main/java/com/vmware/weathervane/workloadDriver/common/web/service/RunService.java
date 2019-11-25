/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.service;

import java.net.UnknownHostException;
import java.util.List;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.Run;
import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.RunStateResponse;

public interface RunService {

	void addRun(String runName, Run theRun) throws DuplicateRunException;

	void initialize(String runName) throws UnknownHostException;

	void start(String runName);

	void stop(String runName);

	boolean isStarted(String runName);

	void shutdown(String runName);
	
	void changeActiveUsers(String runName, String workloadName, long numUsers) throws TooManyUsersException;
	
	ActiveUsersResponse getNumActiveUsers(String runName);

	Run getRun(String runName);

	RunStateResponse getRunState(String runName);

	Boolean isUp();

	Boolean areDriversUp();

	void setHosts(List<String> hosts);

	void setPortNumber(Integer portNumber);

	Boolean addBehaviorSpec(BehaviorSpec theSpec);

}

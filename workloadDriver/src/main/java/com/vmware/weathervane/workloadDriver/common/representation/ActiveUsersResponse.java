/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

import java.util.Map;

public class ActiveUsersResponse extends BasicResponse{

	private Map<String, Long> workloadActiveUsers;

	public Map<String, Long> getWorkloadActiveUsers() {
		return workloadActiveUsers;
	}

	public void setWorkloadActiveUsers(Map<String, Long> workloadActiveUsers) {
		this.workloadActiveUsers = workloadActiveUsers;
	}

}

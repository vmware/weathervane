/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

public class ChangeUsersMessage {

	private long activeUsers;
	
	public long getActiveUsers() {
		return activeUsers;
	}
	public void setActiveUsers(long activeUsers) {
		this.activeUsers = activeUsers;
	}

}

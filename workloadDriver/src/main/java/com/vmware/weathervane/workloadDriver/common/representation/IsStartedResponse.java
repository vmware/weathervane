/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

public class IsStartedResponse {
	private String status;
	private String message;
	private Boolean isStarted;
	
	public Boolean getIsStarted() {
		return isStarted;
	}
	public void setIsStarted(Boolean isStarted) {
		this.isStarted = isStarted;
	}
	public String getStatus() {
		return status;
	}
	public void setStatus(String status) {
		this.status = status;
	}
	public String getMessage() {
		return message;
	}
	public void setMessage(String message) {
		this.message = message;
	}
	
	
}

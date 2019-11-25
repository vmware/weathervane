/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

import java.util.List;

import com.vmware.weathervane.workloadDriver.common.core.Run;
import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;

public class RunStateResponse {
	private String status;
	private String message;
	private Run.RunState state;
	private List<WorkloadStatus> workloadStati;
	
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
	public Run.RunState getState() {
		return state;
	}
	public void setState(Run.RunState state) {
		this.state = state;
	}
	public List<WorkloadStatus> getWorkloadStati() {
		return workloadStati;
	}
	public void setWorkloadStati(List<WorkloadStatus> workloadStati) {
		this.workloadStati = workloadStati;
	}
	
	
}

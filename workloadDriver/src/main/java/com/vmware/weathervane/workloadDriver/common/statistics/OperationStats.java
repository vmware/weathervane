/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics;

import com.vmware.weathervane.workloadDriver.common.core.Operation;

public class OperationStats {
	private String targetName = null;
	
	private int operationIndex = 0;
	private String operationName;
	
	private boolean failed;
	private String failureString = null;
	
	private long startTime = 0;
	private long endTime = 0;
	private long cycleTime;
	private long totalSteps;
			
	public OperationStats(Operation operation) {
		this.setTargetName(operation.getTarget().getName());
		this.operationIndex = operation.getOperationIndex();
		this.operationName = operation.getOperationName();
		this.failed = operation.isFailed();
		this.failureString = operation.getFailureString();
		this.startTime = operation.getTimeStarted();
		this.endTime = operation.getTimeFinished();
		this.setCycleTime(operation.getCycleTime());
		this.totalSteps = operation.getTotalSteps();		
	}
	
	public String getTargetName() {
		return targetName;
	}

	public void setTargetName(String targetName) {
		this.targetName = targetName;
	}

	public int getOperationIndex() {
		return operationIndex;
	}

	public void setOperationIndex(int operationIndex) {
		this.operationIndex = operationIndex;
	}

	public String getOperationName() {
		return operationName;
	}

	public void setOperationName(String operationName) {
		this.operationName = operationName;
	}

	public boolean isFailed() {
		return failed;
	}

	public void setFailed(boolean failed) {
		this.failed = failed;
	}

	public String getFailureString() {
		return failureString;
	}

	public void setFailureString(String failureString) {
		this.failureString = failureString;
	}

	public long getStartTime() {
		return startTime;
	}

	public void setStartTime(long startTime) {
		this.startTime = startTime;
	}

	public long getEndTime() {
		return endTime;
	}

	public void setEndTime(long endTime) {
		this.endTime = endTime;
	}

	public long getTotalSteps() {
		return totalSteps;
	}

	public void setTotalSteps(long totalSteps) {
		this.totalSteps = totalSteps;
	}


	public long getCycleTime() {
		return cycleTime;
	}

	public void setCycleTime(long cycleTime) {
		this.cycleTime = cycleTime;
	}
	
	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder("OperationStats: opName = " + operationName);
		retVal.append(", targetName = " + targetName);
		retVal.append(", failed = " + failed);
		retVal.append(", _failureString = " + failureString);
		retVal.append(", startTime = " + startTime);
		retVal.append(", endTime = " + endTime);
		retVal.append(", cycleTime = " + getCycleTime());
		retVal.append(", responseTime = " + (endTime - startTime) / 1000.0);
		retVal.append(", totalSteps = " + totalSteps);
		
		return retVal.toString();
	}
	
}

/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

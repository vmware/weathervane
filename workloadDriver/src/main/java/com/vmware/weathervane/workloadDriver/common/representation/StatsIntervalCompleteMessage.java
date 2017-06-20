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
package com.vmware.weathervane.workloadDriver.common.representation;

public class StatsIntervalCompleteMessage {

	private String completedSpecName;
	private Long curIntervalStartTime;
	private Long lastIntervalEndTime;
	private String curIntervalName;
	
	public String getCompletedSpecName() {
		return completedSpecName;
	}
	public void setCompletedSpecName(String completedSpecName) {
		this.completedSpecName = completedSpecName;
	}
	public Long getCurIntervalStartTime() {
		return curIntervalStartTime;
	}
	public void setCurIntervalStartTime(Long curIntervalStartTime) {
		this.curIntervalStartTime = curIntervalStartTime;
	}
	public Long getLastIntervalEndTime() {
		return lastIntervalEndTime;
	}
	public void setLastIntervalEndTime(Long lastIntervalEndTime) {
		this.lastIntervalEndTime = lastIntervalEndTime;
	}
	public String getCurIntervalName() {
		return curIntervalName;
	}
	public void setCurIntervalName(String curIntervalName) {
		this.curIntervalName = curIntervalName;
	}
	
	@Override
	public String toString() {
		return "StatsIntervalCompleteMessage: "
				+ "completedSpecName = " + completedSpecName
				+ ", curIntervalName = " + curIntervalName
				+ ", curIntervalStartTime = " + curIntervalStartTime
				+ ", lastIntervalEndTime = " + lastIntervalEndTime;
	}
	
}

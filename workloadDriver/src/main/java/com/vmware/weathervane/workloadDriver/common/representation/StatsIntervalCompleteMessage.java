/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

public class StatsIntervalCompleteMessage {

	private String completedSpecName;
	private Long curIntervalStartTime;
	private Long lastIntervalEndTime;
	private String curIntervalName;
	private Long intervalStartUsers;
	private Long intervalEndUsers;
	
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
	
	public Long getIntervalStartUsers() {
		return intervalStartUsers;
	}
	public void setIntervalStartUsers(Long intervalStartUsers) {
		this.intervalStartUsers = intervalStartUsers;
	}
	public Long getIntervalEndUsers() {
		return intervalEndUsers;
	}
	public void setIntervalEndUsers(Long intervalEndUsers) {
		this.intervalEndUsers = intervalEndUsers;
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

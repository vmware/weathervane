/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;

public class InitializeWorkloadMessage {

	private String hostname;
	private Integer nodeNumber;
	private Integer numNodes;
	private BehaviorSpec behaviorSpec;
	private String statsHostName;
	private String runName;
	private Boolean perTargetStats;
	
	public String getHostname() {
		return hostname;
	}
	public void setHostname(String hostname) {
		this.hostname = hostname;
	}
	public Integer getNodeNumber() {
		return nodeNumber;
	}
	public void setNodeNumber(Integer nodeNumber) {
		this.nodeNumber = nodeNumber;
	}
	public Integer getNumNodes() {
		return numNodes;
	}
	public void setNumNodes(Integer numNodes) {
		this.numNodes = numNodes;
	}
	public BehaviorSpec getBehaviorSpec() {
		return behaviorSpec;
	}
	public void setBehaviorSpec(BehaviorSpec behaviorSpec) {
		this.behaviorSpec = behaviorSpec;
	}
	public String getStatsHostName() {
		return statsHostName;
	}
	public void setStatsHostName(String statsHostName) {
		this.statsHostName = statsHostName;
	}
	public String getRunName() {
		return runName;
	}
	public void setRunName(String runName) {
		this.runName = runName;
	}
	public Boolean isPerTargetStats() {
		return perTargetStats;
	}
	public void setPerTargetStats(Boolean perTargetStats) {
		this.perTargetStats = perTargetStats;
	}
	
}

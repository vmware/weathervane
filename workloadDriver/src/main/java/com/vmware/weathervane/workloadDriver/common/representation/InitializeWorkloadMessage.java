package com.vmware.weathervane.workloadDriver.common.representation;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;

public class InitializeWorkloadMessage {

	private String hostname;
	private Integer nodeNumber;
	private Integer numNodes;
	private BehaviorSpec behaviorSpec;
	private String statsHostName;
	private Integer statsPortNumber;
	private String runName;
	
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
	public Integer getStatsPortNumber() {
		return statsPortNumber;
	}
	public void setStatsPortNumber(Integer statsPortNumber) {
		this.statsPortNumber = statsPortNumber;
	}
	public String getRunName() {
		return runName;
	}
	public void setRunName(String runName) {
		this.runName = runName;
	}
	
}

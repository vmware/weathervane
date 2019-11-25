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

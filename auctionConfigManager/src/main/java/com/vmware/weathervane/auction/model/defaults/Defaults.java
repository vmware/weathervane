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
package com.vmware.weathervane.auction.model.defaults;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown=true)
public class Defaults {
		
	private String hostName;
	private String vmName;
	private String dockerName;
	private Integer instanceNum;
	
	private Boolean useDocker;
	private Integer dockerMemorySwap = 0;
	private String dockerMemory = "";
	private Integer dockerHostPort;
	private String dockerCpuSetCpus = "";
	private String dockerNet = "bridge";
	private Integer frontendConnectionMultiplier;
	private Integer logLevel;
	private Boolean ssl;
	
	private Long dockerCpuShares;

	private Long users;

	public String getHostName() {
		return hostName;
	}
	public void setHostName(String hostName) {
		this.hostName = hostName;
	}
	public String getVmName() {
		return vmName;
	}
	public void setVmName(String vmName) {
		this.vmName = vmName;
	}
	public Integer getInstanceNum() {
		return instanceNum;
	}
	public void setInstanceNum(Integer instanceNum) {
		this.instanceNum = instanceNum;
	}
	public Boolean getUseDocker() {
		return useDocker;
	}
	public void setUseDocker(Boolean useDocker) {
		this.useDocker = useDocker;
	}
	public Integer getDockerHostPort() {
		return dockerHostPort;
	}
	public void setDockerHostPort(Integer dockerPort) {
		this.dockerHostPort = dockerPort;
	}
	public Integer getDockerMemorySwap() {
		return dockerMemorySwap;
	}
	public void setDockerMemorySwap(Integer dockerMemorySwap) {
		this.dockerMemorySwap = dockerMemorySwap;
	}
	public String getDockerMemory() {
		return dockerMemory;
	}
	public void setDockerMemory(String dockerMemory) {
		this.dockerMemory = dockerMemory;
	}
	public String getDockerCpuSetCpus() {
		return dockerCpuSetCpus;
	}
	public void setDockerCpuSetCpus(String dockerCpuSetCpus) {
		this.dockerCpuSetCpus = dockerCpuSetCpus;
	}
	public String getDockerNet() {
		return dockerNet;
	}
	public void setDockerNet(String dockerNet) {
		this.dockerNet = dockerNet;
	}
	public Long getDockerCpuShares() {
		return dockerCpuShares;
	}
	public void setDockerCpuShares(Long dockerCpuShares) {
		this.dockerCpuShares = dockerCpuShares;
	}
	public String getDockerName() {
		return dockerName;
	}
	public void setDockerName(String dockerName) {
		this.dockerName = dockerName;
	}
	public Boolean getSsl() {
		return ssl;
	}
	public void setSsl(Boolean ssl) {
		this.ssl = ssl;
	}
	public Integer getFrontendConnectionMultiplier() {
		return frontendConnectionMultiplier;
	}
	public void setFrontendConnectionMultiplier(Integer frontendConnectionMultiplier) {
		this.frontendConnectionMultiplier = frontendConnectionMultiplier;
	}
	public Integer getLogLevel() {
		return logLevel;
	}
	public void setLogLevel(Integer logLevel) {
		this.logLevel = logLevel;
	}
	public Long getUsers() {
		return users;
	}
	public void setUsers(Long users) {
		this.users = users;
	}
	@Override
	public String toString() {
		return "Defaults [hostName=" + hostName + ", vmName=" + vmName + ", dockerName="
				+ dockerName + ", instanceNum=" + instanceNum + ", useDocker=" + useDocker
				+ ", dockerMemorySwap=" + dockerMemorySwap + ", dockerMemory=" + dockerMemory
				+ ", dockerHostPort=" + dockerHostPort + ", dockerCpuSetCpus=" + dockerCpuSetCpus
				+ ", dockerNet=" + dockerNet + ", frontendConnectionMultiplier="
				+ frontendConnectionMultiplier + ", logLevel=" + logLevel + ", ssl=" + ssl
				+ ", dockerCpuShares=" + dockerCpuShares + ", getHostName()=" + getHostName()
				+ ", getVmName()=" + getVmName() + ", getInstanceNum()=" + getInstanceNum()
				+ ", getUseDocker()=" + getUseDocker() + ", getDockerHostPort()="
				+ getDockerHostPort() + ", getDockerMemorySwap()=" + getDockerMemorySwap()
				+ ", getDockerMemory()=" + getDockerMemory() + ", getDockerCpuSetCpus()="
				+ getDockerCpuSetCpus() + ", getDockerNet()=" + getDockerNet()
				+ ", getDockerCpuShares()=" + getDockerCpuShares() + ", getDockerName()="
				+ getDockerName() + ", getSsl()=" + getSsl()
				+ ", getFrontendConnectionMultiplier()=" + getFrontendConnectionMultiplier()
				+ ", getLogLevel()=" + getLogLevel() + "]";
	}
	
}

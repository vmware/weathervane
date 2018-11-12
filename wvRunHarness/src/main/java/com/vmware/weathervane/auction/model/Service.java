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
package com.vmware.weathervane.auction.model;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.auction.defaults.Defaults;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "class")
@JsonSubTypes({ @Type(value = AppServer.class, name = "appServer"),
	@Type(value = CoordinationServer.class, name = "coordinationServer"),
		@Type(value = DbServer.class, name = "dbServer"),
		@Type(value = MsgServer.class, name = "msgServer"),
		@Type(value = NosqlServer.class, name = "nosqlServer"),
		@Type(value = WebServer.class, name = "webServer") })
@JsonIgnoreProperties(ignoreUnknown = true)
public abstract class Service {
	private static final Logger logger = LoggerFactory.getLogger(Service.class);

	public enum ServiceState {
		NEW, STARTED, ACTIVE, REMOVE, REMOVABLE, STOPPED
	};
	
	private Long id;

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	private String hostName;
	private String vmName;
	private String dockerName;

	private Boolean useDocker;
	private Integer dockerMemorySwap;
	private String dockerMemory;
	private String dockerCpuSetCpus;
	private String dockerNet;
	private Long dockerCpuShares;
	private Long dockerCpus;
	private Integer dockerHostPort;
	private Long users;
	private Integer frontendConnectionMultiplier;
	private Boolean ssl;
	private Integer logLevel;

	private String hostHostName;
	private String hostIpAddr;
	private Long hostCpus;
	private Long hostMemKb;
	private Boolean vicHost;
	private String imageStoreType;
	
	private ServiceState state;
	
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

	public String getDockerName() {
		return dockerName;
	}

	public void setDockerName(String dockerName) {
		this.dockerName = dockerName;
	}

	public Integer getDockerHostPort() {
		return dockerHostPort;
	}

	public void setDockerHostPort(Integer dockerHostPort) {
		this.dockerHostPort = dockerHostPort;
	}

	public Boolean getUseDocker() {
		return useDocker;
	}

	public void setUseDocker(Boolean useDocker) {
		this.useDocker = useDocker;
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

	public Long getUsers() {
		return users;
	}

	public void setUsers(Long users) {
		this.users = users;
	}

	public Integer getFrontendConnectionMultiplier() {
		return frontendConnectionMultiplier;
	}

	public void setFrontendConnectionMultiplier(Integer frontendConnectionMultiplier) {
		this.frontendConnectionMultiplier = frontendConnectionMultiplier;
	}

	public Boolean getSsl() {
		return ssl;
	}

	public void setSsl(Boolean ssl) {
		this.ssl = ssl;
	}

	public Integer getLogLevel() {
		return logLevel;
	}

	public void setLogLevel(Integer logLevel) {
		this.logLevel = logLevel;
	}

	public String getHostHostName() {
		return hostHostName;
	}

	public void setHostHostName(String hostHostName) {
		this.hostHostName = hostHostName;
	}

	public String getHostIpAddr() {
		return hostIpAddr;
	}

	public void setHostIpAddr(String hostIpAddr) {
		this.hostIpAddr = hostIpAddr;
	}

	public void setHostCpus(Long hostCpus) {
		this.hostCpus = hostCpus;
	}

	public Long getHostMemKb() {
		return hostMemKb;
	}

	public void setHostMemKb(Long hostMemKb) {
		this.hostMemKb = hostMemKb;
	}

	public Long getDockerCpuShares() {
		return dockerCpuShares;
	}

	public void setDockerCpuShares(Long dockerCpuShares) {
		this.dockerCpuShares = dockerCpuShares;
	}

	public Boolean isVicHost() {
		return vicHost;
	}

	public void setVicHost(Boolean vicHost) {
		this.vicHost = vicHost;
	}

	public String getImageStoreType() {
		return imageStoreType;
	}

	public void setImageStoreType(String imageStoreType) {
		this.imageStoreType = imageStoreType;
	}

	public ServiceState getState() {
		return state;
	}

	public void setState(ServiceState state) {
		this.state = state;
	}

	public Long getDockerCpus() {
		return dockerCpus;
	}

	public void setDockerCpus(Long dockerCpus) {
		this.dockerCpus = dockerCpus;
	}

	public Service mergeDefaults(Service service, final Defaults defaults) {
		if (hostHostName == null) {
			hostHostName = hostName;
		}
				
		service.setUseDocker(getUseDocker() != null ? getUseDocker() : defaults.getUseDocker());
		service.setDockerHostPort(
				getDockerHostPort() != null ? getDockerHostPort() : defaults.getDockerHostPort());
		service.setDockerMemorySwap(getDockerMemorySwap() != null ? getDockerMemorySwap()
				: defaults.getDockerMemorySwap());
		service.setDockerMemory(
				getDockerMemory() != null ? getDockerMemory() : defaults.getDockerMemory());
		service.setDockerCpuSetCpus(getDockerCpuSetCpus() != null ? getDockerCpuSetCpus()
				: defaults.getDockerCpuSetCpus());
		service.setDockerNet(getDockerNet() != null ? getDockerNet() : defaults.getDockerNet());
		service.setFrontendConnectionMultiplier(getFrontendConnectionMultiplier() != null
				? getFrontendConnectionMultiplier() : defaults.getFrontendConnectionMultiplier());
		service.setSsl(getSsl() != null ? getSsl() : defaults.getSsl());
		service.setLogLevel(getLogLevel() != null ? getLogLevel() : defaults.getLogLevel());
		service.setUsers(getUsers() != null ? getUsers() : defaults.getUsers());
		return service;
	}

	public boolean corunningDockerized(Service that) {
		if ((this.getUseDocker() == null) || !this.getUseDocker() || (that.getUseDocker() == null)
				|| !that.getUseDocker() || (this.getDockerNet() == null)
				|| (this.getDockerNet().equals("host")) || (that.getDockerNet() == null)
				|| (that.getDockerNet().equals("host"))
				|| !this.getDockerNet().equals(that.getDockerNet())
				|| !this.getHostHostName().equals(that.getHostHostName())) {
			return false;
		} else {
			return true;
		}
	}

	public String getHostnameForUsedService(Service that) {
		String hostname = that.getHostHostName();
		if (this.corunningDockerized(that)) {
			/*
			 * Figure out the internal IP address for the service on the docker
			 * host
			 */
			Pattern pattern = Pattern.compile("(.*)\n");
			Runtime r = Runtime.getRuntime();
			Process p;
			try {
				
				p = r.exec("DOCKER_HOST=" + that.getHostHostName() + ":" + that.getDockerHostPort()
						+ "docker inspect --format '{{ .NetworkSettings.IPAddress }}' "
						+ that.getDockerName());
				p.waitFor();
				BufferedReader b = new BufferedReader(new InputStreamReader(p.getInputStream()));
				String line = b.readLine();

				Matcher m = pattern.matcher(line);
				if (m.find()) {
					hostname = m.group(0);
				}

				b.close();
			} catch (IOException e) {
				return hostname;
			} catch (InterruptedException e) {
				return hostname;
			}

		}
		return hostname;
	}

	@Override
	public String toString() {
		return "Service [hostName=" + hostName + ", vmName=" + vmName + ", dockerName=" + dockerName
				+ ", id=" + id + ", useDocker=" + useDocker
				+ ", dockerMemorySwap=" + dockerMemorySwap + ", dockerMemory=" + dockerMemory
				+ ", dockerCpuSetCpus=" + dockerCpuSetCpus + ", dockerNet=" + dockerNet
				+ ", dockerCpuShares=" + dockerCpuShares + ", dockerHostPort=" + dockerHostPort
				+ ", users=" + users + ", frontendConnectionMultiplier="
				+ frontendConnectionMultiplier + ", ssl=" + ssl + ", logLevel=" + logLevel
				+ ", hostHostName=" + hostHostName + ", hostIpAddr=" + hostIpAddr + ", hostCpus="
				+ hostCpus + ", hostMemKb=" + hostMemKb + ", hostIsBonneville=" + vicHost
				+ "]";
	}
}

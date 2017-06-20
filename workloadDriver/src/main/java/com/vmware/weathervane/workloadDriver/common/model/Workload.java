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
package com.vmware.weathervane.workloadDriver.common.model;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionWorkload;
import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.factory.UserFactory;
import com.vmware.weathervane.workloadDriver.common.model.loadPath.LoadPath;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StopWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.StatsIntervalSpec;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ @Type(value = AuctionWorkload.class, name = "auction") })
public abstract class Workload implements UserFactory {
	private static final Logger logger = LoggerFactory.getLogger(Workload.class);

	private String name;

	public enum WorkloadState {
		PENDING, INITIALIZED, RUNNING, STOPPING, COMPLETED
	};

	private WorkloadState state;

	private String behaviorSpecName;
	private int maxUsers;

	private Boolean useThinkTime = false;

	private List<Target> targets;

	private LoadPath loadPath;

	private List<StatsIntervalSpec> statsIntervalSpecs;

	@JsonIgnore
	private List<String> hosts;

	@JsonIgnore
	private StatsCollector statsCollector;

	@JsonIgnore
	private String runName;

	@JsonIgnore
	private String statsHostName;

	@JsonIgnore
	private int statsPortNumber;

	@JsonIgnore
	private String hostname = null;

	@JsonIgnore
	protected int numNodes;

	@JsonIgnore
	protected int nodeNumber;

	@JsonIgnore
	private List<Operation> operations = null;

	@JsonIgnore
	private RestTemplate restTemplate = new RestTemplate();

	@JsonIgnore
	private ScheduledExecutorService executorService = null;
	
	/*
	 * Used to initialize the master workload in the RunService
	 */
	public void initialize(String runName, List<String> hosts, String statsHostName, int statsPortNumber, 
			RestTemplate restTemplate, ScheduledExecutorService executorService) {
		logger.debug("Initialize workload: " + this.toString());

		if (getLoadPath() == null) {
			logger.error("There must be a load path defined for each workload.");
			System.exit(1);
		}

		if (getStatsIntervalSpecs() == null) {
			logger.error("There must be at least one StatsIntervalSpec defined for each workload.");
			System.exit(1);
		}

		this.runName = runName;
		this.hosts = hosts;
		this.statsHostName = statsHostName;
		this.statsPortNumber = statsPortNumber;
		this.restTemplate = restTemplate;
		this.executorService = executorService;
		
		/*
		 * Send initialize workload message to all of the driver nodes
		 */
		int nodeNum = 0;
		for (String hostname : hosts) {
			InitializeWorkloadMessage msg = new InitializeWorkloadMessage();
			msg.setHostname(hostname);
			msg.setNodeNumber(nodeNum);
			msg.setNumNodes(hosts.size());
			msg.setStatsHostName(statsHostName);
			msg.setStatsPortNumber(statsPortNumber);
			msg.setRunName(runName);
			/*
			 * Send the initialize workload message to the host
			 */
			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);

			HttpEntity<InitializeWorkloadMessage> msgEntity = new HttpEntity<InitializeWorkloadMessage>(msg,
					requestHeaders);
			String url = "http://" + hostname + ":" + statsPortNumber + "/driver/run/" + runName + "/workload/" + getName() + "/initialize";
			logger.debug("initialize workload  " + name + ", sending initialize workload message to host " + hostname);
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload initialization to " + url);
			}

			nodeNum++;
		}
		
		/* 
		 * StatsIntervalSpecs run locally
		 */
		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {	
			spec.initialize(runName, name, hosts, statsPortNumber, restTemplate, executorService);
		}
		
		/*
		 * LoadPaths run locally
		 */
		getLoadPath().initialize(runName, name, hosts, statsPortNumber, restTemplate, executorService);

		state = WorkloadState.INITIALIZED;
	}

	/*
	 * Used to initialize the workload in each DriverService
	 */
	public void initializeNode(InitializeWorkloadMessage initializeWorkloadMessage) {
		logger.debug("initializeNode name = " + name);
		this.hostname = initializeWorkloadMessage.getHostname();
		this.statsHostName = initializeWorkloadMessage.getStatsHostName();
		this.statsPortNumber = initializeWorkloadMessage.getStatsPortNumber();
		this.numNodes = initializeWorkloadMessage.getNumNodes();
		this.nodeNumber = initializeWorkloadMessage.getNodeNumber();
		this.runName = initializeWorkloadMessage.getRunName();

		operations = this.getOperations();

		statsCollector = new StatsCollector(getStatsIntervalSpecs(), loadPath, operations, runName, name, statsHostName, statsPortNumber,
				hostname, BehaviorSpec.getBehaviorSpec(behaviorSpecName));

		/*
		 * Initialize all of the targets in the workload
		 */
		List<String> targetNames = new ArrayList<String>();
		for (Target target: getTargets()) {
			target.initialize(name, maxUsers, nodeNumber, numNodes, this, statsCollector);
			targetNames.add(target.getName());
		}

		/*
		 * Set the target names in the statsCollector so that we send a summary
		 * for every interval even if there is no activity for that target
		 */
		statsCollector.setTargetNames(targetNames);
		
		state = WorkloadState.INITIALIZED;

	}

	public void start() {
		logger.debug("start for workload " + name);
		getLoadPath().start();

		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {
			spec.start();
		}
		
		state = WorkloadState.RUNNING;
	}
	
	public void stop() {
		logger.debug("stop for workload " + name);

		getLoadPath().stop();

		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {
			spec.stop();
		}
		
		/*
		 * Send stop messages to workloads on all nodes
		 */
		for (String hostname : hosts) {
			StopWorkloadMessage msg = new StopWorkloadMessage();
			msg.setRunName(runName);
			/*
			 * Send the initialize workload message to the host
			 */
			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);

			HttpEntity<StopWorkloadMessage> msgEntity = new HttpEntity<StopWorkloadMessage>(msg,
					requestHeaders);
			String url = "http://" + hostname + ":" + statsPortNumber + "/driver/run/" + runName + "/workload/" + getName() + "/stop";
			logger.debug("stop workload  " + name + ", sending stop workload message to host " + hostname 
					+ " at url " + url);
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload stop to " + url);
			}

		}
		
		state = WorkloadState.STOPPING;

	}

	public void stopNode() {
		logger.debug("stopNode for workload " + name);

		for (Target target : targets) {
			target.stop();
		}
		
		state = WorkloadState.STOPPING;

	}
	
	public void shutdown() {
		logger.debug("shutdown for workload " + name);

		state = WorkloadState.COMPLETED;

	}
	
	protected abstract List<Operation> getOperations();

	@JsonIgnore
	public long getNumActiveUsers() {
		return getLoadPath().getNumActiveUsers();
	}

	public void changeActiveUsers(long numUsers) throws TooManyUsersException {
		if (maxUsers < numUsers) {
			throw new TooManyUsersException("MaxUsers = " + maxUsers);
		}
		getLoadPath().changeActiveUsers(numUsers);
	}


	public void setCurrentUsers(long numUsers) throws TooManyUsersException {
		if (maxUsers < numUsers) {
			throw new TooManyUsersException("MaxUsers = " + maxUsers);
		}
		
		/*
		 * Divide the users among the targets and set the load per-target
		 */
		int numTargets = getTargets().size();
		long baseUsersPerTarget = numUsers / numTargets;
		long remainingUsers = numUsers - (baseUsersPerTarget * numTargets);
		int targetNum = 0;
		for (Target target : getTargets()) {
			long targetNumUsers = baseUsersPerTarget;
			if (remainingUsers > targetNum) {
				targetNumUsers += 1;
			}
			target.setUserLoad(targetNumUsers);
		}
	}
	

	public void statsIntervalComplete(StatsIntervalCompleteMessage statsIntervalCompleteMessage) {
		logger.debug("statsIntervalComplete");
		statsCollector.statsIntervalComplete(statsIntervalCompleteMessage);
		logger.debug("statsIntervalComplete returning");
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getBehaviorSpecName() {
		return behaviorSpecName;
	}

	public void setBehaviorSpecName(String behaviorSpecName) {
		this.behaviorSpecName = behaviorSpecName;
	}

	public int getMaxUsers() {
		return maxUsers;
	}

	public void setMaxUsers(int maxUsers) {
		this.maxUsers = maxUsers;
	}

	public Boolean getUseThinkTime() {
		return useThinkTime;
	}

	public void setUseThinkTime(Boolean useThinkTime) {
		this.useThinkTime = useThinkTime;
	}

	public StatsCollector getStatsCollector() {
		return statsCollector;
	}

	public void setStatsCollector(StatsCollector statsCollector) {
		this.statsCollector = statsCollector;
	}

	@JsonIgnore
	public int getNumTargets() {
		return getTargets().size();
	}
	
	public WorkloadState getState() {
		return state;
	}

	public void setState(WorkloadState state) {
		this.state = state;
	}
	

	public List<Target> getTargets() {
		return targets;
	}

	public void setTargets(List<Target> targets) {
		this.targets = targets;
	}

	public LoadPath getLoadPath() {
		return loadPath;
	}

	public void setLoadPath(LoadPath loadPath) {
		this.loadPath = loadPath;
	}

	public List<StatsIntervalSpec> getStatsIntervalSpecs() {
		return statsIntervalSpecs;
	}

	public void setStatsIntervalSpecs(List<StatsIntervalSpec> statsIntervalSpecs) {
		this.statsIntervalSpecs = statsIntervalSpecs;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder();
		theStringBuilder.append("Workload name: " + name);
		theStringBuilder.append(", state: " + state);
		theStringBuilder.append(", behaviorSpecName: " + behaviorSpecName);
		theStringBuilder.append(", maxUsers: " + maxUsers);
		theStringBuilder.append(", useThinkTime: " + useThinkTime);
		if (getLoadPath() != null) {
			theStringBuilder.append(", loadPath: " + getLoadPath().getName());
		} else {
			theStringBuilder.append(", No Load Path");
		}
		if (getStatsIntervalSpecs() != null) {
			for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {
				theStringBuilder.append(", statsIntervalSpec: " + spec.getName());
			}
		} else {
			theStringBuilder.append(", No StatsIntervalSpecs");
		}
		if (getTargets() != null) {
			for (Target target : getTargets()) {
				theStringBuilder.append(", target: " + target.getName());
			}
		} else {
			theStringBuilder.append(", No Targets");
		}

		
		return theStringBuilder.toString();
	}

}

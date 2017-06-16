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
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;

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
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadStatsMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.StatsIntervalSpec;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ 
	@Type(value = AuctionWorkload.class, name = "auction")
})
public abstract class Workload {
	private static final Logger logger = LoggerFactory.getLogger(Workload.class);

	@JsonIgnore
	public static final RestTemplate restTemplate = new RestTemplate();
	
	private String behaviorSpecName;
	private int maxUsers;

	private Boolean useThinkTime = false;
	
	private List<String> statsIntervalSpecNames;

	@JsonIgnore
	private String name;
	@JsonIgnore
	private Integer nodeNumber;
	@JsonIgnore
	private Integer numNodes;
	
	@JsonIgnore
	private List<String> targetNames = new ArrayList<String>();
	
	@JsonIgnore
	private Map<String,Target> targets = new HashMap<String, Target>();
	
	@JsonIgnore
	private StatsCollector statsCollector;
	
	@JsonIgnore
	private String masterHostName;

	@JsonIgnore
	private int masterPortNumber;

	@JsonIgnore
	private String localHostName;

	@JsonIgnore
	private List<Operation> operations = null;
	
	public abstract User createUser(Long userId, Long orderingId, Long globalOrderingId, Target target);

	public void initialize(String name, Integer nodeNumber, Integer numNodes, 
			Map<String, StatsIntervalSpec> statsIntervalSpecsMap,
			String masterHostName, int masterPortNumber, String localHostname) {
		this.name = name;
		this.nodeNumber = nodeNumber;
		this.numNodes = numNodes;
		this.masterHostName = masterHostName;
		this.masterPortNumber = masterPortNumber;
		this.localHostName = localHostname;
		
		
		operations = this.getOperations();
		
		List<StatsIntervalSpec> statsIntervalSpecs = new LinkedList<StatsIntervalSpec>();
		for (String statsIntervalSpecName : statsIntervalSpecNames) {
			StatsIntervalSpec spec = statsIntervalSpecsMap.get(statsIntervalSpecName);
			if (spec == null) {
				logger.error("Definition of workload " + name 
						+ " specifies a statsIntervalSpec named " + statsIntervalSpecName
						+ " which does not exist.");
				System.exit(1);
			}
			statsIntervalSpecs.add(spec);
		}
		statsCollector = new StatsCollector(statsIntervalSpecs, operations, name, masterHostName, 
									masterPortNumber, localHostname, BehaviorSpec.getBehaviorSpec(behaviorSpecName));

	}
	
	protected abstract List<Operation> getOperations();

	public void start() {

		/*
		 * Set the target names in the statsCollector so that we send a summary for every
		 * interval even if there is no activity for that target
		 */
		statsCollector.setTargetNames(targetNames);
		
		/*
		 * Let the stats service know about this workload so that it can 
		 * properly aggregate stats for targets
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		InitializeWorkloadStatsMessage initializeWorkloadStatsMessage = new InitializeWorkloadStatsMessage();
		initializeWorkloadStatsMessage.setWorkloadName(name);
		initializeWorkloadStatsMessage.setTargetNames(targetNames);
		initializeWorkloadStatsMessage.setStatsIntervalSpecNames(statsIntervalSpecNames);
		
		HttpEntity<InitializeWorkloadStatsMessage> statsEntity = new HttpEntity<InitializeWorkloadStatsMessage>(initializeWorkloadStatsMessage, requestHeaders);
		String url = "http://" + masterHostName + ":" + masterPortNumber + "/stats/initialize/workload";
		ResponseEntity<BasicResponse> responseEntity 
				= restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);

		BasicResponse response = responseEntity.getBody();
		if (responseEntity.getStatusCode() != HttpStatus.OK) {
			logger.error("Error posting workload initialization to " + url);
		}
		
	}
	
	public long getNumActiveUsers() {
		
		long numUsers = 0;
		
		for (String name : targets.keySet()) {
			numUsers += targets.get(name).getNumActiveUsers();
		}
		return numUsers;
	}
	
	public void changeActiveUsers(long numUsers) throws TooManyUsersException {
		if (maxUsers < numUsers) {
			throw new TooManyUsersException("MaxUsers = " + maxUsers);
		}
		
		int numTargets = targetNames.size();
		
		long baseUsersPerTarget = numUsers / numTargets;
		long remainingUsers = numUsers % numTargets;
		
		for (String name : targets.keySet()) {
			long newUsers = baseUsersPerTarget + ((remainingUsers > 0) ? 1 : 0);
			logger.info("Setting numUsers for target " + name + " to " + newUsers);
			targets.get(name).setUserLoad(newUsers);
			logger.info("Setting numUsers for target " + name + " returned");
			logger.info("");
			remainingUsers--;
		}
		
	}
	
	/*
	 * ToDo: Check for valid targetName and throw exception if not 
	 */
	public void changeActiveUsers(long numUsers, String targetName) throws TooManyUsersException {
		Target target = targets.get(targetName);
		if (target != null) {
			target.setUserLoad(numUsers);
		}
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

	public List<String> getStatsIntervalSpecNames() {
		return statsIntervalSpecNames;
	}

	public void setStatsIntervalSpecNames(List<String> statsIntervalSpecNames) {
		this.statsIntervalSpecNames = statsIntervalSpecNames;
	}

	public void addTargetName(String targetName) {
		this.targetNames.add(targetName);
	}

	public void addTarget(Target target) {
		this.targets.put(target.getName(), target);
		this.addTargetName(target.getName());
	}

	public String getLocalHostName() {
		return localHostName;
	}

	public void setLocalHostName(String localHostName) {
		this.localHostName = localHostName;
	}

}

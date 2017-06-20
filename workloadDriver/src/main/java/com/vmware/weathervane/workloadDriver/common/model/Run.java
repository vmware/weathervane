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

import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

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
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;

public class Run {
	private static final Logger logger = LoggerFactory.getLogger(Run.class);

	@JsonIgnore
	public static final RestTemplate restTemplate = new RestTemplate();

	private String name;
	
	public enum RunState {PENDING, INITIALIZED, RUNNING, STOPPING, COMPLETED};

	private RunState state;
	
	private String statsOutputDirName;
	
	private String statsHost;

	private Integer portNumber = 7500;

	private List<String> hosts;

	private List<Workload> workloads;	
		
	@JsonIgnore
	private ScheduledExecutorService executorService = null;
	
	public void initialize() throws UnknownHostException {
		logger.debug("initialize name = " + name);
		
		if (workloads == null) {
			logger.error("There must be at least one workload defined in the run configuration file.");
			System.exit(1);
		}
		
		if (hosts == null) {
			logger.error("There must be at least one host defined in the run configuration file.");
			System.exit(1);
		}
		
		executorService = Executors.newScheduledThreadPool(4 * Runtime.getRuntime().availableProcessors());
		
		/*
		 * Convert all of the host names to lower case
		 */
		List<String> lcHosts = new ArrayList<String>();
		for (String host : hosts) {
			lcHosts.add(host.toLowerCase());
		}
		hosts = lcHosts;
	
		
		/*
		 * Let the stats service know about the run so that it can
		 * properly aggregate stats for hosts
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		InitializeRunStatsMessage initializeRunStatsMessage = new InitializeRunStatsMessage();
		initializeRunStatsMessage.setHosts(hosts);
		initializeRunStatsMessage.setStatsOutputDirName(getStatsOutputDirName());
		Map<String, Integer> workloadNameToNumTargetsMap = new HashMap<String, Integer>();
		for (Workload workload : workloads) {
			workloadNameToNumTargetsMap.put(workload.getName(), workload.getNumTargets());
		}
		initializeRunStatsMessage.setWorkloadNameToNumTargetsMap(workloadNameToNumTargetsMap);
		
		HttpEntity<InitializeRunStatsMessage> statsEntity = new HttpEntity<InitializeRunStatsMessage>(initializeRunStatsMessage, requestHeaders);
		String url = "http://" + statsHost + ":" + portNumber + "/stats/initialize/run/" + name;
		logger.debug("Sending initialize run message to stats controller.  url = " + url + ", maessage: " + initializeRunStatsMessage);
		ResponseEntity<BasicResponse> responseEntity 
				= restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);

		BasicResponse response = responseEntity.getBody();
		if (responseEntity.getStatusCode() != HttpStatus.OK) {
			logger.error("Error posting workload initialization to " + url);
		}

		/*
		 * Initialize the workloads
		 */
		for (Workload workload : workloads) {
			logger.debug("initialize name = " + name + ", initializing workload " + workload.getName());
			workload.initialize(name, hosts, statsHost, portNumber, restTemplate, executorService);
		}
		
		state = RunState.INITIALIZED;
		
	}
	
	public void start() {
		
		for (Workload workload : workloads) {
			logger.debug("start run " + name + " starting workload " + workload.getName());
			workload.start();
		}
		
		state = RunState.RUNNING;

	}
	
	public void stop() {
		logger.debug("stop for run " + name);
		state = RunState.STOPPING;
		
		for (Workload workload : workloads) {
			workload.stop();
		}
		state = RunState.COMPLETED;

		logger.debug("stopped load paths and spec intervals");
		
	}
	
	
	public void shutdown() {
		logger.debug("shutdown for run " + name);

		executorService.shutdown();
		try {
			executorService.awaitTermination(10, TimeUnit.SECONDS);
		} catch (InterruptedException e) {
		}
		logger.debug("stopped executor");

		try {
			Operation.shutdownExecutor();
		} catch (InterruptedException e) {
		}
		logger.debug("stopped Operation executor");

		/*
		 * Send exit messages to the other driver nodes
		 */
		for (String hostname : hosts) {
			if (hostname == statsHost) {
				continue;
			}
			HttpHeaders requestHeaders = new HttpHeaders();
			HttpEntity<String> stringEntity = new HttpEntity<String>(name, requestHeaders);
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);
			String url = "http://" + hostname + ":" + portNumber + "/driver/exit/" + name;
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, stringEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload to " + url);
			}
		}
		
		/*
		 * Shutdown the driver after returning so that the web interface can
		 * send a response
		 */
		Thread shutdownThread = new Thread(new ShutdownThreadRunner());
		shutdownThread.start();
	}

	public ActiveUsersResponse getNumActiveUsers() {
		ActiveUsersResponse activeUsersResponse = new ActiveUsersResponse();
		Map<String, Long> workloadActiveUsersMap = new HashMap<String, Long>();
		
		long numActiveUsers = 0;
		for (Workload workload : workloads) {
			numActiveUsers = workload.getNumActiveUsers();
			workloadActiveUsersMap.put(workload.getName(), numActiveUsers);
		}
		
		activeUsersResponse.setWorkloadActiveUsers(workloadActiveUsersMap);
		return activeUsersResponse;
	}
	
	public void changeActiveUsers(String workloadName, long numUsers) throws TooManyUsersException {
		for (Workload workload : workloads) {
			if (workload.getName() == workloadName) {
				if (numUsers > workload.getMaxUsers()) {
					throw new TooManyUsersException("Workload " + workloadName 
							+ " has a maxUsers of " + workload.getMaxUsers() + " users.");
				}
				workload.changeActiveUsers(numUsers);
			}
		}
	}
	public List<Workload> getWorkloads() {
		return workloads;
	}
	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public void setWorkloads(List<Workload> workloads) {
		this.workloads = workloads;
	}


	public List<String> getHosts() {
		return hosts;
	}

	public void setHosts(List<String> hosts) {
		this.hosts = hosts;
	}

	public RunState getState() {
		return state;
	}

	public void setState(RunState state) {
		this.state = state;
	}

	public String getStatsHost() {
		return statsHost;
	}

	public void setStatsHost(String statsHost) {
		this.statsHost = statsHost;
	}

	public Integer getPortNumber() {
		return portNumber;
	}

	public void setPortNumber(Integer portNumber) {
		this.portNumber = portNumber;
	}

	public String getStatsOutputDirName() {
		return statsOutputDirName;
	}

	public void setStatsOutputDirName(String statsOutputDirName) {
		this.statsOutputDirName = statsOutputDirName;
	}

	@Override
	public String toString() {
		StringBuilder theStringBuilder = new StringBuilder("Run: ");
		
		if (workloads != null) {
			for (Workload workload : workloads) {
				theStringBuilder.append("\n\tWorkload " + workload.getName() + ": " + workload.toString());
			}
		} else {
			theStringBuilder.append("\n\tNo Workloads!");
		}
		
		return theStringBuilder.toString();

	}

	
	private class ShutdownThreadRunner implements Runnable {

		@Override
		public void run() {
			try {
				Thread.sleep(30000);
			} catch (InterruptedException e) {
			}
			System.exit(0);
		}
		
	}

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core;

import java.net.UnknownHostException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
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
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.RunStateResponse;

public class Run {
	private static final Logger logger = LoggerFactory.getLogger(Run.class);

	@JsonIgnore
	public static final RestTemplate restTemplate = new RestTemplate();

	private String name;
	
	public enum RunState {PENDING, INITIALIZED, RUNNING, STOPPING, COMPLETED};

	private RunState state;
	
	private String statsOutputDirName;
	
	private String runStatsHost;

	private String workloadStatsHost;

	private List<Workload> workloads;	
	
	private LoadPathController loadPathController;
	
	private Set<String> runningWorkloadNames = new HashSet<String>();
		
	private boolean perTargetStats = false;

	private boolean abortOnFail = false;

	@JsonIgnore
	private List<String> hosts;

	@JsonIgnore
	private ScheduledExecutorService executorService = null;
	
	@JsonIgnore
	private List<WorkloadStatus> completedWorkloadStati = new ArrayList<WorkloadStatus>();
	
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
		
		executorService = Executors.newScheduledThreadPool(3 * workloads.size());
		
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
		initializeRunStatsMessage.setIsPerTargetStats(perTargetStats);
		Map<String, Integer> workloadNameToNumTargetsMap = new HashMap<String, Integer>();
		for (Workload workload : workloads) {
			workloadNameToNumTargetsMap.put(workload.getName(), workload.getNumTargets());
		}
		initializeRunStatsMessage.setWorkloadNameToNumTargetsMap(workloadNameToNumTargetsMap);
		
		HttpEntity<InitializeRunStatsMessage> statsEntity = new HttpEntity<InitializeRunStatsMessage>(initializeRunStatsMessage, requestHeaders);
		String url = "http://" + runStatsHost + "/stats/initialize/run/" + name;
		logger.debug("Sending initialize run message to stats controller.  url = " + url + ", maessage: " + initializeRunStatsMessage);
		ResponseEntity<BasicResponse> responseEntity 
				= restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);

		BasicResponse response = responseEntity.getBody();
		if (responseEntity.getStatusCode() != HttpStatus.OK) {
			logger.error("Error posting workload initialization to " + url);
		}
		
		/*
		 * Let the loadPathController know how many workloads there
		 * are so that it can size resources.
		 */
		loadPathController.initialize(workloads.size());

		/*
		 * Initialize the workloads
		 */
		for (Workload workload : workloads) {
			logger.debug("initialize name = " + name + ", initializing workload " + workload.getName());
			workload.initialize(name, this, hosts, runStatsHost, workloadStatsHost,
					loadPathController, restTemplate, executorService, perTargetStats);
		}
		
		state = RunState.INITIALIZED;
		
	}
	
	public void start() {
		
		for (Workload workload : workloads) {
			logger.debug("start run " + name + " starting workload " + workload.getName());
			runningWorkloadNames.add(workload.getName());
			workload.start();
		}
		
		state = RunState.RUNNING;

	}

	/*
	 * One of the workloads has completed.  If all of the workloads
	 * have completed then the run is complete. 
	 */
	public void workloadComplete(WorkloadStatus status) {
		synchronized (completedWorkloadStati) {
			runningWorkloadNames.remove(status.getName());
			completedWorkloadStati.add(status);			
		}
		if (runningWorkloadNames.isEmpty()) {
			logger.debug("All workloads have finished.  Run is completed");
			state = RunState.COMPLETED;
		}
		if (!status.isPassed() && abortOnFail) {
			logger.debug("Workload {} failed.  Aborting run", status.getName());
			this.stop();			
		}
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

		/*
		 * Send exit messages to the other driver nodes
		 */
		List<Future<?>> sfList = new ArrayList<>();
		for (String hostname : hosts) {
			if (hostname.equals(workloadStatsHost)) {
				continue;
			}
			
			sfList.add(executorService.submit(new Runnable() {
				
				@Override
				public void run() {
					HttpHeaders requestHeaders = new HttpHeaders();
					HttpEntity<String> stringEntity = new HttpEntity<String>(name, requestHeaders);
					requestHeaders.setContentType(MediaType.APPLICATION_JSON);
					String url = "http://" + hostname + "/driver/exit/" + name;
					ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, stringEntity,
							BasicResponse.class);

					BasicResponse response = responseEntity.getBody();
					if (responseEntity.getStatusCode() != HttpStatus.OK) {
						logger.error("Error posting workload to " + url);
					}
				}
			}));
		}
		/*
		 * Now wait for all of the nodes to be notified of the exit
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("shutdown getting a result of a notification");
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying node got exception: " + e.getMessage());
			};
		});

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
	
	public RunStateResponse getRunState() {
		RunStateResponse response = new RunStateResponse();
		response.setState(getState());

		List<WorkloadStatus> workloadStati = new ArrayList<WorkloadStatus>();
		synchronized (completedWorkloadStati) {
			// Add status for completed workloads
			for (WorkloadStatus status : completedWorkloadStati) {
				workloadStati.add(status);
			}
			
			// Add status for running workloads
			for (Workload aWorkload: workloads) {
				if (runningWorkloadNames.contains(aWorkload.getName())) {
					workloadStati.add(aWorkload.getWorkloadStatus());
				}
			}	
		}		
		response.setWorkloadStati(workloadStati);

		return(response);
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

	public String getRunStatsHost() {
		return runStatsHost;
	}

	public void setRunStatsHost(String runStatsHost) {
		this.runStatsHost = runStatsHost;
	}

	public String getWorkloadStatsHost() {
		return workloadStatsHost;
	}

	public void setWorkloadStatsHost(String workloadStatsHost) {
		this.workloadStatsHost = workloadStatsHost;
	}

	public String getStatsOutputDirName() {
		return statsOutputDirName;
	}

	public void setStatsOutputDirName(String statsOutputDirName) {
		this.statsOutputDirName = statsOutputDirName;
	}

	public LoadPathController getLoadPathController() {
		return loadPathController;
	}

	public void setLoadPathController(LoadPathController loadPathController) {
		this.loadPathController = loadPathController;
	}

	public boolean isPerTargetStats() {
		return perTargetStats;
	}

	public void setPerTargetStats(boolean perTargetStats) {
		this.perTargetStats = perTargetStats;
	}

	public boolean isAbortOnFail() {
		return abortOnFail;
	}

	public void setAbortOnFail(boolean abortOnFail) {
		this.abortOnFail = abortOnFail;
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

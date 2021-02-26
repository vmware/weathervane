/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Future;
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
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath.LoadPath;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.factory.UserFactory;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StopWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.PerTargetStatsCollector;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.PerWorkloadStatsCollector;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;
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
	private boolean perTargetStats = false;

	@JsonIgnore
	private List<String> hosts;

	@JsonIgnore
	private StatsCollector statsCollector;

	@JsonIgnore
	private String runName;

	@JsonIgnore
	private String runStatsHost;

	@JsonIgnore
	private String workloadStatsHost;

	@JsonIgnore
	private String hostname = null;

	@JsonIgnore
	protected int numNodes;

	@JsonIgnore
	protected int nodeNumber;
	
	@JsonIgnore
	private LoadPathController LoadPathController;

	@JsonIgnore
	private List<Operation> operations = null;

	@JsonIgnore
	private RestTemplate restTemplate = new RestTemplate();

	@JsonIgnore
	private ScheduledExecutorService executorService = null;

	@JsonIgnore
	private Run run = null;
	
	@JsonIgnore
	private boolean finished = false;
	
	/*
	 * Used to initialize the master workload in the RunService
	 */
	public void initialize(String runName, Run run, List<String> hosts, String runStatsHost, String workloadStatsHost,
			LoadPathController loadPathController, RestTemplate restTemplate, ScheduledExecutorService executorService,
			boolean perTargetStats) {
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
		this.run = run;
		this.hosts = hosts;
		
		this.runStatsHost = runStatsHost;
		this.workloadStatsHost = workloadStatsHost;
		this.LoadPathController = loadPathController;
		this.restTemplate = restTemplate;
		this.executorService = executorService;
		this.perTargetStats = perTargetStats;
		
		/*
		 * Send initialize workload message to all of the driver nodes
		 */
		int nodeNum = 0;
		List<Future<?>> sfList = new ArrayList<>();
		for (String hostname : hosts) {
			sfList.add(executorService.submit(new SendInitMsgRunner(nodeNum, hostname, hosts.size())));
			nodeNum++;
		}
		/*
		 * Now wait for all of the nodes to be notified of the change
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("initialize getting a result of a notification");
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying node got exception: " + e.getMessage());
			};
		});

		/* 
		 * StatsIntervalSpecs run locally
		 */
		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {	
			spec.initialize(runName, name, hosts, restTemplate, executorService);
		}
		
		/*
		 * LoadPaths run locally
		 */
		getLoadPath().initialize(runName, name, this, loadPathController, 
				hosts, runStatsHost, restTemplate, executorService);

		state = WorkloadState.INITIALIZED;
	}

	private class SendInitMsgRunner implements Runnable {
		private int nodeNum;
		private String hostname;
		private int numNodes;

		public SendInitMsgRunner(int nodeNum, String hostname, int numNodes) {
			super();
			this.nodeNum = nodeNum;
			this.hostname = hostname;
			this.numNodes = numNodes;
		}

		@Override
		public void run() {
			InitializeWorkloadMessage msg = new InitializeWorkloadMessage();
			msg.setHostname(hostname);
			msg.setNodeNumber(nodeNum);
			msg.setNumNodes(numNodes);
			msg.setStatsHostName(workloadStatsHost);
			msg.setRunName(runName);
			msg.setPerTargetStats(perTargetStats);
			/*
			 * Send the initialize workload message to the host
			 */
			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);

			HttpEntity<InitializeWorkloadMessage> msgEntity = new HttpEntity<InitializeWorkloadMessage>(msg,
					requestHeaders);
			String url = "http://" + hostname + "/driver/run/" + runName + "/workload/" + getName() + "/initialize";
			logger.debug("initialize workload  " + name + ", sending initialize workload message to host " + hostname);
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload initialization to " + url);
			}			
		}
	}
	
	/*
	 * Used to initialize the workload in each DriverService
	 */
	public void initializeNode(InitializeWorkloadMessage initializeWorkloadMessage) {
		logger.debug("initializeNode name = " + name);
		this.hostname = initializeWorkloadMessage.getHostname();
		this.workloadStatsHost = initializeWorkloadMessage.getStatsHostName();
		this.numNodes = initializeWorkloadMessage.getNumNodes();
		this.nodeNumber = initializeWorkloadMessage.getNodeNumber();
		this.runName = initializeWorkloadMessage.getRunName();
		this.perTargetStats = initializeWorkloadMessage.isPerTargetStats();

		operations = this.getOperations();

		if (perTargetStats) {
			statsCollector = new PerTargetStatsCollector(getStatsIntervalSpecs(), loadPath, operations, runName, name, workloadStatsHost,
					hostname, BehaviorSpec.getBehaviorSpec(behaviorSpecName));
		} else {
			statsCollector = new PerWorkloadStatsCollector(getStatsIntervalSpecs(), loadPath, operations, runName, name, workloadStatsHost,
					hostname, BehaviorSpec.getBehaviorSpec(behaviorSpecName));
		}

		/*
		 * Initialize all of the BehaviorSpecs
		 */
		for (String behaviorSpecName: BehaviorSpec.getBehaviorSpecNames()) {
			BehaviorSpec.getBehaviorSpec(behaviorSpecName).initialize();
		}

		/*
		 * Initialize all of the targets in the workload
		 */
		List<String> targetNames = new ArrayList<String>();
		int targetNum = 0;
		for (Target target: getTargets()) {
			target.initialize(name, maxUsers, nodeNumber, numNodes, targetNum, getTargets().size(), this, statsCollector);
			targetNames.add(target.getName());
			targetNum++;
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

		finished = true;
		
		getLoadPath().stop();

		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {
			spec.stop();
		}
		
		/*
		 * Send stop messages to workloads on all nodes
		 */
		List<Future<?>> sfList = new ArrayList<>();
		for (String hostname : hosts) {
			sfList.add(executorService.submit(new Runnable() {
				
				@Override
				public void run() {
					StopWorkloadMessage msg = new StopWorkloadMessage();
					msg.setRunName(runName);
					/*
					 * Send the initialize workload message to the host
					 */
					HttpHeaders requestHeaders = new HttpHeaders();
					requestHeaders.setContentType(MediaType.APPLICATION_JSON);

					HttpEntity<StopWorkloadMessage> msgEntity = new HttpEntity<StopWorkloadMessage>(msg,
							requestHeaders);
					String url = "http://" + hostname + "/driver/run/" + runName + "/workload/" + getName() + "/stop";
					logger.debug("stop workload  " + name + ", sending stop workload message to host " + hostname 
							+ " at url " + url);
					ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
							BasicResponse.class);

					BasicResponse response = responseEntity.getBody();
					if (responseEntity.getStatusCode() != HttpStatus.OK) {
						logger.error("Error posting workload stop to " + url);
					}
				}
			}));
		}
		/*
		 * Now wait for all of the nodes to be notified of the change
		 */
		sfList.stream().forEach(sf -> {
			try {
				logger.debug("stop getting a result of a notification");
				sf.get(); 
			} catch (Exception e) {
				logger.warn("When notifying node got exception: " + e.getMessage());
			};
		});

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
		 * Determine how many users to run based on maxUsers, the number of nodes,
		 * the number of targets per node, and the targetNumber and nodeNumber of this
		 * target.
		 */
		int numTargets = getTargets().size();
		long usersPerTarget = numUsers / (numNodes * numTargets);
		long excessUsers = numUsers % (numNodes * numTargets);
		for (Target target : getTargets()) {
			int targetOrderingId = target.getTargetNumber() + (nodeNumber * numTargets);
			long targetNumUsers = usersPerTarget;
			if (targetOrderingId < excessUsers) {
				targetNumUsers++;
			}
			
			target.setUserLoad(targetNumUsers);
		}
		
	}
	

	public void statsIntervalComplete(StatsIntervalCompleteMessage statsIntervalCompleteMessage) {
		logger.debug("statsIntervalComplete");
		statsCollector.statsIntervalComplete(statsIntervalCompleteMessage);
		logger.debug("statsIntervalComplete returning");
	}
	

	public void loadPathComplete(WorkloadStatus status) {
		status.setName(name);
		status.setState(getState());
		run.workloadComplete(status);
	}

	public WorkloadStatus getWorkloadStatus() {
		WorkloadStatus status = new WorkloadStatus();
		status.setName(name);
		status.setState(state);
		status.setCurInterval(loadPath.getCurStatusInterval());
		status.setIntervalStatsSummaries(loadPath.getIntervalStatsSummaries());
		status.setLoadPathName(loadPath.getName());
		
		return status;
	}

	public void setActiveUsers(long users) {
		logger.debug("setActiveUsers: users set to " + users);
		for (StatsIntervalSpec spec : getStatsIntervalSpecs()) {	
			spec.setActiveUsers(users);
		}		
		logger.debug("setActiveUsers: finished");
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

	public boolean isPerTargetStats() {
		return perTargetStats;
	}

	public void setPerTargetStats(boolean perTargetStats) {
		this.perTargetStats = perTargetStats;
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

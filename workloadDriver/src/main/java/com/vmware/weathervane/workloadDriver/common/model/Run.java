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

import java.net.InetAddress;
import java.net.UnknownHostException;
import java.text.SimpleDateFormat;
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
import com.vmware.weathervane.workloadDriver.common.model.loadPath.LoadPath;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.LoadPathStatsIntervalSpec;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.StatsIntervalSpec;

public class Run {
	private static final Logger logger = LoggerFactory.getLogger(Run.class);

	@JsonIgnore
	public static final RestTemplate restTemplate = new RestTemplate();

	private Long rampUp;
	private Long steadyState;
	private Long rampDown;

	private String behaviorSpecDirName;
	private String statsOutputDirName;
	
	private int statsInterval = 10;

	private Map<String, Workload> workloads;	

	private Map<String,  LoadPath> loadPaths;

	private Map<String, Target> targets;

	private Map<String, StatsIntervalSpec> statsIntervalSpecs;
	
	private List<String> hosts;

	private String statsHost;
	
	private Integer portNumber = 7500;
	
	@JsonIgnore
	private String localHostname;
	
	@JsonIgnore
	private ScheduledExecutorService executorService = null;

	public void initialize() throws UnknownHostException {
		
		if (targets == null) {
			logger.error("There must be at least one target defined in the run configuration file.");
			System.exit(1);
		}
		
		if (loadPaths == null) {
			logger.error("There must be at least one load path defined in the run configuration file.");
			System.exit(1);
		}
		
		if (workloads == null) {
			logger.error("There must be at least one workload defined in the run configuration file.");
			System.exit(1);
		}
		
		if (hosts == null) {
			logger.error("There must be at least one host defined in the run configuration file.");
			System.exit(1);
		}
		
		executorService = Executors.newScheduledThreadPool(Runtime.getRuntime().availableProcessors());
		
		/*
		 * Convert all of the host names to lower case
		 */
		List<String> lcHosts = new ArrayList<String>();
		for (String host : hosts) {
			lcHosts.add(host.toLowerCase());
		}
		hosts = lcHosts;
		
		/*
		 * First determine the nodeNumber of this node (based on position in hosts list).
		 * if there is only one node then we know this is node 0
		 */
		String[] localHostnameParts = InetAddress.getLocalHost().getHostName().split ("\\.");
		if (localHostnameParts.length <= 0) {
			throw new UnknownHostException();
		}
		localHostname = localHostnameParts[0].toLowerCase();
		int nodeNumber = 0;
		if (hosts.size() > 1) {
			localHostname = determineLocalHostname();
			nodeNumber = determineNodeNumber(localHostname);
		}

		for (String name : getStatsIntervalSpecs().keySet()) {
			StatsIntervalSpec spec = statsIntervalSpecs.get(name);
			if (spec instanceof LoadPathStatsIntervalSpec) {
				String loadPathName = ((LoadPathStatsIntervalSpec) spec).getLoadPathName();
				LoadPath path = loadPaths.get(loadPathName);
				if (path == null) {
					logger.error("StatsIntervalSpec " + name + " refers to a LoadPath called " 
							+ loadPathName + " which does not exist" );
					System.exit(1);
				}
				((LoadPathStatsIntervalSpec) spec).setLoadPath(path);
			}
			
			spec.initialize(name);
		}

		for (String name : loadPaths.keySet()) {
			loadPaths.get(name).initialize(name, nodeNumber, hosts.size());
		}

		for (String name : workloads.keySet()) {
			workloads.get(name).initialize(name, nodeNumber, hosts.size(),
					statsIntervalSpecs,	statsHost, portNumber, localHostname);
		}
		
		for (String name : targets.keySet()) {
			targets.get(name).initialize(name, rampUp, steadyState, rampDown, executorService, 
									loadPaths, workloads, nodeNumber, hosts.size());
		}
		
		/*
		 * Let the stats service know about the run so that it can
		 * properly aggregate stats for hosts
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		InitializeRunStatsMessage initializeRunStatsMessage = new InitializeRunStatsMessage();
		initializeRunStatsMessage.setHosts(hosts);
		initializeRunStatsMessage.setStatsOutputDirName(getStatsOutputDirName());
		
		HttpEntity<InitializeRunStatsMessage> statsEntity = new HttpEntity<InitializeRunStatsMessage>(initializeRunStatsMessage, requestHeaders);
		String url = "http://" + statsHost + ":" + portNumber + "/stats/initialize/run";
		ResponseEntity<BasicResponse> responseEntity 
				= restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);

		BasicResponse response = responseEntity.getBody();
		if (responseEntity.getStatusCode() != HttpStatus.OK) {
			logger.error("Error posting workload initialization to " + url);
		}

	}
	
	public void start() {
		
		for (Workload workload : workloads.values()) {
			workload.start();
		}

		for (Target target : targets.values()) {
			target.start();
		}

		for (StatsIntervalSpec spec : statsIntervalSpecs.values()) {
			spec.start();
		}
		
		Thread progressMessageThread = new Thread(new progressMessageRunner());
		progressMessageThread.start();

	}
	
	public void stop() {
		logger.debug("stop");
		for (Target target : targets.values()) {
			target.stop();
		}
		logger.debug("stopped targets");
		
		StatsIntervalSpec.stop();
		logger.debug("stopped spec intervals");
		
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
	}
	
	
	public void shutdown() {
		logger.debug("shutdown");

		/*
		 * Shutdown the driver after returning so that the web interface can
		 * send a response
		 */
		Thread shutdownThread = new Thread(new ShutdownThreadRunner());
		shutdownThread.start();
	}
	
	
	private String determineLocalHostname() {
		String localHostname = null;
		String canonicalLocalHostname = null;
		String localAddress = null;
		try {
			String[] localHostnameParts = InetAddress.getLocalHost().getHostName().split ("\\.");
			if (localHostnameParts.length <= 0) {
				throw new UnknownHostException();
			}
			localHostname = localHostnameParts[0].toLowerCase();
			
			canonicalLocalHostname = InetAddress.getLocalHost().getCanonicalHostName().toLowerCase();
			localAddress = InetAddress.getLocalHost().getHostAddress().toLowerCase();
			
			logger.info("localHostname = " + localHostname);
			logger.info("canonical localHostname = " + canonicalLocalHostname);
			logger.info("local address = " + localAddress);
			
		} catch (UnknownHostException e) {
			String hostnameEnv = System.getenv("HOSTNAME");
			if (hostnameEnv == null) {
				logger.error("Can't determine the hostname of the local system");
				System.exit(1);				
			}
			
			String[] localHostnameParts = hostnameEnv.split ("\\.");
			if (localHostnameParts.length <= 0) {
				logger.error("Can't determine the hostname of the local system");
				System.exit(1);
			}
			localHostname = localHostnameParts[0].toLowerCase();
			logger.info("localHostname from System.getenv = " + localHostname);
			canonicalLocalHostname = System.getenv("HOSTNAME");
			if (canonicalLocalHostname != null) {
				canonicalLocalHostname = canonicalLocalHostname.toLowerCase();
			}
			
		}

		int nodeNumber = -1;
		if (localHostname != null) {
			nodeNumber = hosts.indexOf(localHostname);
			if (nodeNumber != -1) return localHostname;
		}
		if (canonicalLocalHostname != null) {
			nodeNumber = hosts.indexOf(canonicalLocalHostname);			
			if (nodeNumber != -1) return canonicalLocalHostname;
		}
		if (localAddress != null) {
			nodeNumber = hosts.indexOf(localAddress);			
			if (nodeNumber != -1) return localAddress;
		}

		/*
		 * Check if the local IP address matches the IP address for
		 * any of the hosts
		 */
		for (String host : hosts) {
			String hostAddress = null;
			try {
				hostAddress = InetAddress.getByName(host).getHostAddress();
				if ((localAddress != null) && localAddress.equals(hostAddress)) {
					return host;
				}
				
			}  catch (UnknownHostException e) {				
				logger.error("Can't resolve ip address for host named " + host);
				System.exit(1);
				return null;
			}
			
		}
		
		logger.error("The hostname or address of the host for this driver node must be in the run's \"hosts\" list");
		System.exit(1);
		return null;
		
	}
	
	private int determineNodeNumber(String hostname) {
		return hosts.indexOf(hostname);
	}
	
	private boolean determineIsMaster(String hostname) {
		boolean isMaster = false;
		if (hostname.equals(statsHost.toLowerCase())) {
			isMaster = true;
		}

		return isMaster;
	}
	
	public ActiveUsersResponse getNumActiveUsers() {
		ActiveUsersResponse activeUsersResponse = new ActiveUsersResponse();
		Map<String, Long> workloadActiveUsersMap = new HashMap<String, Long>();
		
		for (String name : workloads.keySet()) {
			workloadActiveUsersMap.put(name, workloads.get(name).getNumActiveUsers());
		}
		
		activeUsersResponse.setWorkloadActiveUsers(workloadActiveUsersMap);
		return activeUsersResponse;
	}
	
	public void changeActiveUsers(String workloadName, long numUsers) throws TooManyUsersException {
		Workload workload = workloads.get(workloadName);
		workload.changeActiveUsers(numUsers);
	}

	
	public Map<String, Target> getTargets() {
		return targets;
	}
	public void setTargets(Map<String, Target> targets) {
		this.targets = targets;
	}
	public Map<String, LoadPath> getLoadPaths() {
		return loadPaths;
	}
	public void setLoadPaths(Map<String, LoadPath> loadPaths) {
		this.loadPaths = loadPaths;
	}
	public Map<String, Workload> getWorkloads() {
		return workloads;
	}
	public void setWorkloads(Map<String, Workload> workloads) {
		this.workloads = workloads;
	}

	public Map<String, StatsIntervalSpec> getStatsIntervalSpecs() {
		return statsIntervalSpecs;
	}

	public void setStatsIntervalSpecs(Map<String, StatsIntervalSpec> statsIntervalSpecs) {
		this.statsIntervalSpecs = statsIntervalSpecs;
	}

	public List<String> getHosts() {
		return hosts;
	}

	public void setHosts(List<String> hosts) {
		this.hosts = hosts;
	}

	public Long getRampUp() {
		return rampUp;
	}
	public void setRampUp(Long rampUp) {
		this.rampUp = rampUp;
	}
	public Long getSteadyState() {
		return steadyState;
	}
	public void setSteadyState(Long steadyState) {
		this.steadyState = steadyState;
	}
	public Long getRampDown() {
		return rampDown;
	}
	public void setRampDown(Long rampDown) {
		this.rampDown = rampDown;
	}
	
	public String getBehaviorSpecDirName() {
		return behaviorSpecDirName;
	}

	public void setBehaviorSpecDirName(String behaviorSpecDirName) {
		this.behaviorSpecDirName = behaviorSpecDirName;
	}

	public int getStatsInterval() {
		return statsInterval;
	}

	public void setStatsInterval(int statsInterval) {
		this.statsInterval = statsInterval;
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
		theStringBuilder.append("rampUp: " + getRampUp());
		theStringBuilder.append("; steadyState: " + getSteadyState());
		theStringBuilder.append("; rampDown: " + getRampDown());
		theStringBuilder.append("; behaviorSpecDirName: " + getBehaviorSpecDirName());
		
		if (workloads != null) {
			for (String name : workloads.keySet()) {
				theStringBuilder.append("\n\tWorkload " + name + ": " + workloads.get(name).toString());
			}
		} else {
			theStringBuilder.append("\n\tNo Workloads!");
		}

		if (loadPaths != null) {
			for (String name : loadPaths.keySet()) {
				theStringBuilder.append("\n\tLoadPath " + name + ": " + loadPaths.get(name).toString());
			}
		} else {
			theStringBuilder.append("\n\tNo LoadPaths!");
		}

		if (targets != null) {
			for (String name : targets.keySet()) {
				theStringBuilder.append("\n\tTarget " + name + ": " + targets.get(name).toString());
			}
		} else {
			theStringBuilder.append("\n\tNo Targets!");
		}
		
		return theStringBuilder.toString();


	}
	
	private class progressMessageRunner implements Runnable {

		@Override
		public void run() {
			try {

				SimpleDateFormat formatter = new SimpleDateFormat("yyyy/MM/dd HH" + ":mm:ss.SSS");

				System.out.println(formatter.format(System.currentTimeMillis()) + ": Ramp-Up Started");
				Thread.sleep(rampUp * 1000);

				System.out.println(formatter.format(System.currentTimeMillis()) + ": Steady-State Started");
				Thread.sleep(steadyState * 1000);

				System.out.println(formatter.format(System.currentTimeMillis()) + ": Steady-State Ended");
				Thread.sleep(rampDown * 1000);

				System.out.println(formatter.format(System.currentTimeMillis()) + ": Ramp-Down Ended");

			} catch (InterruptedException e) {
			}

		}

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

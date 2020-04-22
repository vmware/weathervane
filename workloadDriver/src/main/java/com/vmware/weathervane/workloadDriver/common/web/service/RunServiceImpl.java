/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.service;

import java.net.UnknownHostException;
import java.util.HashMap;
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
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.Run;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.Run.RunState;
import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.exceptions.RunNotInitializedException;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.IsStartedResponse;
import com.vmware.weathervane.workloadDriver.common.representation.RunStateResponse;

@Service
public class RunServiceImpl implements RunService {
	private static final Logger logger = LoggerFactory.getLogger(RunServiceImpl.class);

	public static final RestTemplate restTemplate = new RestTemplate();

	private Map<String, Run> runs = new HashMap<String, Run>();
	
	private List<String> hosts;

	private Integer portNumber = 7500;

	@Override
	public Run getRun(String runName) throws RunNotInitializedException {
		// Make sure that this run isn't already being handled
		if (!runs.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		return runs.get(runName);
	}

	@Override
	public RunStateResponse getRunState(String runName) throws RunNotInitializedException {
		// Make sure that this run isn't already being handled
		if (!runs.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		return runs.get(runName).getRunState();
	}

	@Override
	public void addRun(String runName, Run theRun) throws DuplicateRunException {
		logger.debug("addRun runName = " + runName);
		// Make sure that this run isn't already being handled
		if (runs.containsKey(runName)) {
			throw new DuplicateRunException("Run " + runName + " is already loaded.");
		}

		if ((theRun.getState() == null) || (theRun.getState() != RunState.PENDING)) {
			theRun.setState(RunState.PENDING);
		}
		theRun.setHosts(hosts);
		theRun.setPortNumber(portNumber);
		runs.put(runName, theRun);

		/*
		 * Initialize the run on all of the run's hosts
		 */
		if (theRun.getHosts() == null) {
			logger.debug("addRun: Run " + runName + " does not have any hosts defined.");
			return;
		}
		for (String hostname : theRun.getHosts()) {
			HttpHeaders requestHeaders = new HttpHeaders();
			HttpEntity<String> stringEntity = new HttpEntity<String>(runName, requestHeaders);
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);
			String url = "http://" + hostname + ":" + theRun.getPortNumber() + "/driver/run/" + runName;
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, stringEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload to " + url);
			}

			if (theRun.getWorkloads() == null) {
				logger.debug("addRun: Run " + runName + " does not have any workloads defined.");
				return;
			}
			
			for (Workload workload : theRun.getWorkloads()) {

				HttpEntity<Workload> workloadEntity = new HttpEntity<Workload>(workload, requestHeaders);
				requestHeaders = new HttpHeaders();
				requestHeaders.setContentType(MediaType.APPLICATION_JSON);
				url = "http://" + hostname + ":" + theRun.getPortNumber() + "/driver/run/" + runName + "/workload/"
						+ workload.getName();
				logger.debug("addRun: For run " + runName + " adding workload " + workload.getName() 
								+ " to host " + hostname);
				responseEntity = restTemplate.exchange(url, HttpMethod.POST, workloadEntity, BasicResponse.class);

				response = responseEntity.getBody();
				if (responseEntity.getStatusCode() != HttpStatus.OK) {
					logger.error("Error posting workload to " + url);
				}

			}
		}
	}

	@Override
	public void initialize(String runName) throws UnknownHostException, RunNotInitializedException {
		logger.debug("initialize");
		Run run = runs.get(runName);
		if (run == null) {
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		if (run.getState() != RunState.PENDING) {
			throw new DuplicateRunException("Run " + runName + " is already active.");
		}

		run.initialize();
	}

	@Override
	public void start(String runName) throws RunNotInitializedException, DuplicateRunException {
		logger.debug("start " + runName);
		Run run = runs.get(runName);
		if (run == null) {
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		if (run.getState() != RunState.INITIALIZED) {
			throw new RunNotInitializedException("Run configuration must be initialized before starting");
		}

		run.start();

	}

	@Override
	public void stop(String runName) throws RunNotInitializedException {
		logger.debug("stop for run " + runName);
		Run run = runs.get(runName);
		if (run == null) {
			logger.warn("stop Run " + runName + " does not exist.");
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		run.stop();
	}

	@Override
	public void shutdown(String runName) throws RunNotInitializedException {
		logger.debug("shutdown for runName " + runName);
		Run run = runs.get(runName);
		if (run == null) {
			logger.debug("shutdown Run " + runName + " does not exist.");
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		if (run.getState() != RunState.COMPLETED) {
			logger.debug("shutdown Run " + runName + " has not completed.");
			throw new RunNotInitializedException("Run " + runName + " has not completed");
		}

		run.shutdown();
		runs.remove(runName);		
	}

	@Override
	public boolean isStarted(String runName) {
		Run run = runs.get(runName);

		if ((run != null) && (run.getState() == RunState.RUNNING)) {
			return true;
		} else {
			return true;
		}
	}

	@Override
	public Boolean areDriversUp() {
		logger.debug("areDriversUp");
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		for (String hostname : hosts) {
			String url = "http://" + hostname + ":" + portNumber + "/driver/up";
			logger.debug("areDriversUp: Peforming get for url: {}", url);
			ResponseEntity<IsStartedResponse> responseEntity = restTemplate.getForEntity(url, IsStartedResponse.class);

			IsStartedResponse response = responseEntity.getBody();
			if ((responseEntity.getStatusCode() != HttpStatus.OK) || !response.getIsStarted()) {
				logger.debug("Host " + hostname + " is not up.");			
				return false;
			}
			logger.debug("Host " + hostname + " is up.");			
		}
		return true;
	}

	@Override
	public Boolean addBehaviorSpec(BehaviorSpec theSpec) {
		boolean allSuceeeded = true;
		HttpHeaders requestHeaders = new HttpHeaders();
		HttpEntity<BehaviorSpec> specEntity = new HttpEntity<BehaviorSpec>(theSpec, requestHeaders);
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		for (String hostname : hosts) {
			String url = "http://" + hostname + ":" + portNumber + "/driver/behaviorSpec";
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, specEntity,
					BasicResponse.class);

			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting workload to " + url);
				allSuceeeded = false;
			}
		}
		return allSuceeeded;
	}

	@Override
	public Boolean isUp() {
		return true;
	}

	@Override
	public void changeActiveUsers(String runName, String workloadName, long numUsers)
			throws TooManyUsersException, RunNotInitializedException {
		Run run = runs.get(runName);

		if ((run != null) && (run.getState() == RunState.RUNNING)) {
			run.changeActiveUsers(workloadName, numUsers);
		} else {
			throw new RunNotInitializedException("Run " + runName + " is not active.");
		}

	}

	@Override
	public ActiveUsersResponse getNumActiveUsers(String runName) throws RunNotInitializedException {
		Run run = runs.get(runName);
		if (run == null) {
			throw new RunNotInitializedException("Run " + runName + " is not active.");
		}

		if ((run != null) && (run.getState() == RunState.RUNNING)) {
			return run.getNumActiveUsers();
		} else {
			throw new RunNotInitializedException("Run " + runName + " is not active.");
		}

	}

	public List<String> getHosts() {
		return hosts;
	}

	@Override
	public void setHosts(List<String> hosts) {
		this.hosts = hosts;
	}

	public Integer getPortNumber() {
		return portNumber;
	}

	@Override
	public void setPortNumber(Integer portNumber) {
		this.portNumber = portNumber;
	}

}

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
package com.vmware.weathervane.workloadDriver.common.web.service;

import java.net.UnknownHostException;
import java.util.HashMap;
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

import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.exceptions.RunNotInitializedException;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.model.Run;
import com.vmware.weathervane.workloadDriver.common.model.Run.RunState;
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;

@Service
public class RunServiceImpl implements RunService {
	private static final Logger logger = LoggerFactory.getLogger(RunServiceImpl.class);

	public static final RestTemplate restTemplate = new RestTemplate();

	private Map<String, Run> runs = new HashMap<String, Run>();

	@Override
	public Run getRun(String runName) throws RunNotInitializedException {
		// Make sure that this run isn't already being handled
		if (!runs.containsKey(runName)) {
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		return runs.get(runName);
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
			logger.debug("stop Run " + runName + " does not exist.");
			throw new RunNotInitializedException("Run " + runName + " does not exist.");
		}

		if (run.getState() != RunState.RUNNING) {
			logger.debug("stop Run " + runName + " has not completed.");
			throw new RunNotInitializedException("Run " + runName + " is not running");
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
	public boolean isUp(String runName) {
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

}

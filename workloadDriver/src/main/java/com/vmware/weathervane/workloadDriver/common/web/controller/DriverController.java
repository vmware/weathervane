/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
import com.vmware.weathervane.workloadDriver.common.representation.IsStartedResponse;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.web.service.DriverService;

@RestController
@RequestMapping("/driver")
public class DriverController {
	private static final Logger logger = LoggerFactory.getLogger(DriverController.class);

	@Autowired
	private DriverService driverService;
	
	@RequestMapping(value = "/run/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> addRun(@PathVariable String runName, 
			@RequestBody String runNameAgain) {
		logger.debug("addRun: run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.addRun(runName);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}", method = RequestMethod.DELETE)
	public HttpEntity<BasicResponse> deleteRun(@PathVariable String runName, 
			@RequestBody String runNameAgain) {
		logger.debug("deleteRun: run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.removeRun(runName);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}/workload/{workloadName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> addWorkload(@PathVariable String runName, @PathVariable String workloadName, 
			@RequestBody Workload theWorkload) {
		logger.debug("addWorkload: run " + runName + ", workload: " + workloadName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.addWorkload(runName, workloadName, theWorkload);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}/workload/{workloadName}/initialize", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initializeWorkload(@PathVariable String runName,
			@PathVariable String workloadName, @RequestBody InitializeWorkloadMessage initializeWorkloadMessage) {
		logger.debug("initializeWorkload for run " + runName + ", workload " + workloadName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.initializeWorkload(runName, workloadName, initializeWorkloadMessage);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}/workload/{workloadName}/users", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> changeUsers(@PathVariable String runName, @PathVariable String workloadName, 
			@RequestBody ChangeUsersMessage changeUsersMessage) {
		logger.debug("changeUsers for run " + runName + ", workload " + workloadName + " to " + changeUsersMessage.getActiveUsers());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.changeActiveUsers(runName, workloadName, changeUsersMessage.getActiveUsers());
		} catch (Exception e) {
			logger.warn("changeUsers: caught exception: {}", e.getMessage());
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}/workload/{workloadName}/statsIntervalComplete", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> statsIntervalComplete(@PathVariable String runName, @PathVariable String workloadName, 
			@RequestBody StatsIntervalCompleteMessage statsIntervalCompleteMessage) {
		logger.debug("statsIntervalComplete for run " + runName + ", workload "+ workloadName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.statsIntervalComplete(runName, workloadName, statsIntervalCompleteMessage);
		} catch (Exception e) {
			logger.warn("statsIntervalComplete: caught exception: {}", e.getMessage());
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/run/{runName}/workload/{workloadName}/stop", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> stopWorkload(@PathVariable String runName, @PathVariable String workloadName) {
		logger.debug("stopWorkload for run " + runName + ", workload " + workloadName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.stopWorkload(runName, workloadName);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value = "/exit/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> exit(@PathVariable String runName, 
			@RequestBody String runNameAgain) {
		logger.debug("exit: run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			driverService.exit(runName);
		} catch (Exception e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}


	@RequestMapping(value="/up", method = RequestMethod.GET)
	public HttpEntity<IsStartedResponse> isDriverUp() {
		logger.debug("isDriverUp");
		IsStartedResponse response = new IsStartedResponse();
		HttpStatus status = HttpStatus.OK;
		response.setIsStarted(true);

		return new ResponseEntity<IsStartedResponse>(response, status);
	}

	@RequestMapping(value="/behaviorSpec", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> addBehaviorSpec(@RequestBody BehaviorSpec theSpec) {
		logger.debug("addBehaviorSpec: " + theSpec.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		BehaviorSpec.addBehaviorSpec(theSpec.getName(), theSpec);

		return new ResponseEntity<BasicResponse>(response, status);
	}

}

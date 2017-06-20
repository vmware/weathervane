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

import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadMessage;
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


}

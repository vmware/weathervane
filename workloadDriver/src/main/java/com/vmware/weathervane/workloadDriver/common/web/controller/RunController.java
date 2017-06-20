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

import java.net.UnknownHostException;

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

import com.vmware.weathervane.workloadDriver.common.exceptions.DuplicateRunException;
import com.vmware.weathervane.workloadDriver.common.exceptions.RunNotInitializedException;
import com.vmware.weathervane.workloadDriver.common.exceptions.TooManyUsersException;
import com.vmware.weathervane.workloadDriver.common.model.Run;
import com.vmware.weathervane.workloadDriver.common.representation.ActiveUsersResponse;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;
import com.vmware.weathervane.workloadDriver.common.representation.IsStartedResponse;
import com.vmware.weathervane.workloadDriver.common.web.service.RunService;

@RestController
@RequestMapping("/run")
public class RunController {
	private static final Logger logger = LoggerFactory.getLogger(RunController.class);

	@Autowired
	private RunService runService;

	@RequestMapping(value="/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> addRun(@PathVariable String runName, @RequestBody Run theRun) {
		logger.debug("setRun for run " + runName );
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.addRun(runName, theRun);
		} catch (DuplicateRunException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}


	@RequestMapping(value="/{runName}", method = RequestMethod.GET)
	public HttpEntity<Run> getRun(@PathVariable String runName) {
		logger.debug("getRun for run " + runName );
		HttpStatus status = HttpStatus.OK;
		Run theRun = null;
		try {
			theRun = runService.getRun(runName);
		} catch (RunNotInitializedException e) {
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<Run>(theRun, status);
	}

	@RequestMapping(value="/{runName}/initialize", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initialize(@PathVariable String runName, @RequestBody Run theRun) {
		logger.debug("initialize for run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.initialize(runName);
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (UnknownHostException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/start", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> start(@PathVariable String runName) {
		logger.debug("start for run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.start(runName);
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (DuplicateRunException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/stop", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> stop(@PathVariable String runName) {
		logger.debug("stop for run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.stop(runName);
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/shutdown", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> shutdown(@PathVariable String runName) {
		logger.debug("shutdown for run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.shutdown(runName);
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/start", method = RequestMethod.GET)
	public HttpEntity<IsStartedResponse> isStarted(@PathVariable String runName) {
		logger.debug("start for run " + runName);
		IsStartedResponse response = new IsStartedResponse();
		HttpStatus status = HttpStatus.OK;
		
		response.setIsStarted(runService.isStarted(runName));

		return new ResponseEntity<IsStartedResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/users", method = RequestMethod.GET)
	public HttpEntity<ActiveUsersResponse> getNumActiveUsers(@PathVariable String runName) {
		logger.debug("getActiveUsers for run " + runName);
		ActiveUsersResponse response = new ActiveUsersResponse();
		HttpStatus status = HttpStatus.OK;

		try {
			response = runService.getNumActiveUsers(runName);
			response.setStatus("Success");
			response.setMessage("");
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		
		return new ResponseEntity<ActiveUsersResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/up", method = RequestMethod.GET)
	public HttpEntity<IsStartedResponse> isUp(@PathVariable String runName) {
		logger.debug("isUp for run " + runName);
		IsStartedResponse response = new IsStartedResponse();
		HttpStatus status = HttpStatus.OK;
		response.setIsStarted(runService.isUp(runName));

		return new ResponseEntity<IsStartedResponse>(response, status);
	}

	@RequestMapping(value="/{runName}/workload/{workloadName}/users", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> changeActiveUsers(@RequestBody ChangeUsersMessage changeUsersMessage,
			@PathVariable String runName, @PathVariable String workloadName) {
		logger.debug("changeActiveUsers for run " + runName + ": workloadName = " + workloadName
					+ ", numUsers = " + changeUsersMessage.getActiveUsers());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		response.setMessage("Num Users changed");
		response.setStatus("Success");
		
		try {
			runService.changeActiveUsers(runName, workloadName, changeUsersMessage.getActiveUsers());
		} catch (TooManyUsersException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
	
		logger.info("changeActiveUsers returning status " + status);
		return new ResponseEntity<BasicResponse>(response, status);
	}


}

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

	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<BasicResponse> setRun(@RequestBody Run theRun) {
		logger.debug("setRun: " + theRun.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.setRun(theRun);
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/initialize", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initialize() {
		logger.debug("initialize");
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.initialize();
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

	@RequestMapping(value="/start", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> start() {
		logger.debug("start");
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.start();
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/stop", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> stop() {
		logger.debug("stop");
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.stop();
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/shutdown", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> shutdown() {
		logger.debug("stop");
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			runService.shutdown();
		} catch (RunNotInitializedException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/start", method = RequestMethod.GET)
	public HttpEntity<IsStartedResponse> isStarted() {
		logger.debug("start");
		IsStartedResponse response = new IsStartedResponse();
		HttpStatus status = HttpStatus.OK;
		
		response.setIsStarted(runService.isStarted());

		return new ResponseEntity<IsStartedResponse>(response, status);
	}

	@RequestMapping(value="/users", method = RequestMethod.GET)
	public HttpEntity<ActiveUsersResponse> getNumActiveUsers() {
		logger.debug("getActiveUsers");
		ActiveUsersResponse response = runService.getNumActiveUsers();
		HttpStatus status = HttpStatus.OK;
		response.setStatus("Success");
		response.setMessage("");
		
		return new ResponseEntity<ActiveUsersResponse>(response, status);
	}

	@RequestMapping(value="/up", method = RequestMethod.GET)
	public HttpEntity<IsStartedResponse> isUp() {
		logger.debug("isUp");
		IsStartedResponse response = new IsStartedResponse();
		HttpStatus status = HttpStatus.OK;
		response.setIsStarted(runService.isUp());

		return new ResponseEntity<IsStartedResponse>(response, status);
	}

	@RequestMapping(value="/workload/{workloadName}/users", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> changeActiveUsers(@RequestBody ChangeUsersMessage changeUsersMessage,
														@PathVariable String workloadName) {
		logger.debug("changeActiveUsers: workloadName = " + workloadName
					+ ", numUsers = " + changeUsersMessage.getNumUsers());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		response.setMessage("Num Users changed");
		response.setStatus("Success");
		
		try {
			runService.changeActiveUsers(workloadName, changeUsersMessage.getNumUsers());
		} catch (TooManyUsersException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
	
		logger.info("changeActiveUsers returning status " + status);
		return new ResponseEntity<BasicResponse>(response, status);
	}


}

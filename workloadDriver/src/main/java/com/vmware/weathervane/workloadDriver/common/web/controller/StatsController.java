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

import java.io.IOException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeWorkloadStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.RunCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.representation.RunStartedMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummary;
import com.vmware.weathervane.workloadDriver.common.web.service.StatsService;

@RestController
@RequestMapping("/stats")
public class StatsController {
	private static final Logger logger = LoggerFactory.getLogger(StatsController.class);

	@Autowired
	private StatsService statsService;

	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<BasicResponse> postStatsSummary(@RequestBody StatsSummary statsSummary) {
		logger.debug("postStatsSummary: " + statsSummary.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			statsService.postStatsSummary(statsSummary);
		} catch (IOException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/initialize/run", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initializeRun(@RequestBody InitializeRunStatsMessage initializeRunStatsMessage) {
		logger.debug("initializeRun: " + initializeRunStatsMessage.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.initializeRun(initializeRunStatsMessage);
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/initialize/workload", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initializeWorkload(@RequestBody InitializeWorkloadStatsMessage initializeWorkloadStatsMessage) {
		logger.debug("initializeWorkload: " + initializeWorkloadStatsMessage.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.initializeWorkload(initializeWorkloadStatsMessage);
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/started", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> runStarted(@RequestBody RunStartedMessage runStartedMessage) {
		logger.debug("runStarted: " );
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.runStarted();
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/complete", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> runComplete(@RequestBody RunCompleteMessage runCompleteMessage) throws IOException {
		logger.debug("runComplete: " );
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.runComplete();
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	
}

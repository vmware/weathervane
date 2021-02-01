/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.controller;

import java.io.IOException;

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

import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.RunCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.representation.RunStartedMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryResponseMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryRollupResponseMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsService;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummary;

@RestController
@RequestMapping("/stats")
public class StatsController {
	private static final Logger logger = LoggerFactory.getLogger(StatsController.class);

	@Autowired
	private StatsService statsService;

	@RequestMapping(value="/run/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> postStatsSummary(@PathVariable String runName, @RequestBody StatsSummary statsSummary) {
		logger.debug("postStatsSummary for run " + runName + ": " + statsSummary.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		try {
			statsService.postStatsSummary(runName, statsSummary);
		} catch (Exception e) {
			logger.warn("postStatsSummary: caught exception: {}", e.getMessage());
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/run/{runName}/workload/{workloadName}/specName/{specName}/intervalName/{intervalName}", method = RequestMethod.GET)
	public HttpEntity<StatsSummaryResponseMessage> getStatsSummary(@PathVariable String runName, @PathVariable String workloadName, 
			@PathVariable String specName, @PathVariable String intervalName) {
		logger.debug("getStatsSummary for run " + runName + ", workload " + workloadName + ", statsIntervalSpec " + specName + ", interval " + intervalName);
		StatsSummaryResponseMessage response = null;
		HttpStatus status = HttpStatus.OK;
		
		response = statsService.getStatsSummary(runName, workloadName, specName, intervalName);
		response.setMessage("Success");
		response.setStatus("Success");
	
		return new ResponseEntity<StatsSummaryResponseMessage>(response, status);
	}

	@RequestMapping(value="/run/{runName}/workload/{workloadName}/specName/{specName}/intervalName/{intervalName}/rollup", method = RequestMethod.GET)
	public HttpEntity<StatsSummaryRollupResponseMessage> getStatsSummaryRollup(@PathVariable String runName, @PathVariable String workloadName, 
			@PathVariable String specName, @PathVariable String intervalName) {
		logger.debug("getStatsSummary for run " + runName + ", workload " + workloadName + ", statsIntervalSpec " + specName + ", interval " + intervalName);
		StatsSummaryRollupResponseMessage response = null;
		HttpStatus status = HttpStatus.OK;
		
		response = statsService.getStatsSummaryRollup(runName, workloadName, specName, intervalName);
		response.setMessage("Success");
		response.setStatus("Success");
	
		return new ResponseEntity<StatsSummaryRollupResponseMessage>(response, status);
	}

	@RequestMapping(value="/initialize/run/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> initializeRun(@PathVariable String runName, @RequestBody InitializeRunStatsMessage initializeRunStatsMessage) {
		logger.debug("initializeRun for run " + runName + ", message: " + initializeRunStatsMessage.toString());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.initializeRun(runName, initializeRunStatsMessage);
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/started/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> runStarted(@PathVariable String runName, @RequestBody RunStartedMessage runStartedMessage) {
		logger.debug("runStarted for run " + runName );
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.runStarted(runName);
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	@RequestMapping(value="/complete/{runName}", method = RequestMethod.POST)
	public HttpEntity<BasicResponse> runComplete(@PathVariable String runName, @RequestBody RunCompleteMessage runCompleteMessage) throws IOException {
		logger.debug("runComplete for run " + runName);
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		statsService.runComplete(runName);
	
		return new ResponseEntity<BasicResponse>(response, status);
	}

	
}

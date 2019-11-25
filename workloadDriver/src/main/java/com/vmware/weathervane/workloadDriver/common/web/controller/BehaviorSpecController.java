/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.web.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;

@RestController
@RequestMapping("/behaviorSpec")
public class BehaviorSpecController {
	private static final Logger logger = LoggerFactory.getLogger(BehaviorSpecController.class);

	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<BasicResponse> addBehaviorSpec(@RequestBody BehaviorSpec theSpec) {
		logger.debug("addBehaviorSpec: " + theSpec.getName());
		BasicResponse response = new BasicResponse();
		HttpStatus status = HttpStatus.OK;
		
		BehaviorSpec.addBehaviorSpec(theSpec.getName(), theSpec);

		return new ResponseEntity<BasicResponse>(response, status);
	}

}

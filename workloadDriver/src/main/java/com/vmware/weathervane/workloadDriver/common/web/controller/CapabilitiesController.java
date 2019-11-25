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
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/capabilities")
public class CapabilitiesController {
	private static final Logger logger = LoggerFactory.getLogger(CapabilitiesController.class);

	@RequestMapping(value="/numcpus", method=RequestMethod.GET)
	public HttpEntity<Integer> getNumCpus() {
		HttpStatus status = HttpStatus.OK;
		logger.debug("getNumCpus");

		return new ResponseEntity<Integer>(Runtime.getRuntime().availableProcessors(), status);
	}

	
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controller;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

import com.vmware.weathervane.auction.service.WarmerService;

@Controller
@RequestMapping(value = "/warmer")
public class WarmerController  {
	private static final Logger logger = LoggerFactory.getLogger(WarmerController.class);
	
	@Autowired
	private WarmerService warmerService;

	@RequestMapping(value="/healthCheck", method = RequestMethod.GET )
	@ResponseStatus( HttpStatus.OK )
	@ResponseBody
	public String healthCheck() {
		logger.info("healthCheck");
		
		return "alive";
		
	}
	
	@RequestMapping(value="/ready", method = RequestMethod.GET )
	@ResponseStatus( HttpStatus.OK )
	@ResponseBody
	public String ready() {
		logger.info("ready");
		if (warmerService.isWarmingComplete()) {
			return "ready";
		} else {
			return "initializing";
		}		
	}
	


}

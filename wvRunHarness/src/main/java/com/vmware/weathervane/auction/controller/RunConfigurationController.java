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
package com.vmware.weathervane.auction.controller;

import static org.springframework.hateoas.mvc.ControllerLinkBuilder.linkTo;
import static org.springframework.hateoas.mvc.ControllerLinkBuilder.methodOn;

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

import com.vmware.weathervane.auction.exception.DuplicateRunConfigurationException;
import com.vmware.weathervane.auction.message.GetRunConfigurationResponse;
import com.vmware.weathervane.auction.message.ResponseMessage;
import com.vmware.weathervane.auction.model.RunConfiguration;
import com.vmware.weathervane.auction.service.RunConfigurationService;

@RestController
@RequestMapping("/runConfiguration")
public class RunConfigurationController {
	private static final Logger logger = LoggerFactory.getLogger(RunConfigurationController.class);

	@Autowired
	private RunConfigurationService runConfigurationService;

	@RequestMapping(method= RequestMethod.GET)
	public HttpEntity<GetRunConfigurationResponse> getConfiguration() {
		GetRunConfigurationResponse response = new GetRunConfigurationResponse();
		HttpStatus status = HttpStatus.OK;
		response.setRunConfiguration(runConfigurationService.getRunConfiguration());
		
		response.add(linkTo(methodOn(RunConfigurationController.class).getConfiguration()).withSelfRel());
		
		return new ResponseEntity<GetRunConfigurationResponse>(response, status);
	}

	@RequestMapping(method = RequestMethod.PUT)
	public HttpEntity<ResponseMessage> addRunConfiguration(@RequestBody RunConfiguration runConfiguration) {
		ResponseMessage addConfigurationResponse = new ResponseMessage();
		HttpStatus status = HttpStatus.OK;
		logger.debug("addConfiguration: " + runConfiguration.toString());
		try {
			/*
			 * Send the the runConfiguration on to the servive that handles (and possible stores) it.
			 */
			runConfigurationService.setRunConfiguration(runConfiguration);
			
			addConfigurationResponse.setMessage("Configuration changed successfully.");
			addConfigurationResponse.setSuccess(true);
		} catch (DuplicateRunConfigurationException e) {
			addConfigurationResponse.setMessage("Service already exists in configuration");
			addConfigurationResponse.setSuccess(false);
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<ResponseMessage>(addConfigurationResponse, status);
	}	

}

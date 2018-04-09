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

import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.hateoas.ResourceSupport;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import com.vmware.weathervane.auction.model.configuration.AppInstance;
import com.vmware.weathervane.auction.model.defaults.AppInstanceDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddAppInstanceResponse;
import com.vmware.weathervane.auction.representation.configuration.GetAppInstanceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.AppInstanceService;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/appInstance")
public class AppInstanceController {
	private static final Logger logger = LoggerFactory.getLogger(AppInstanceController.class);

	@Autowired
	private AppInstanceService appInstanceService;

	@Autowired
	private DefaultsService defaultsService;
	
	private void addLinks(Long id, ResourceSupport response) {
		response.add(linkTo(methodOn(AppInstanceController.class).getAppInstance(id)).withSelfRel());
	}
		
	@RequestMapping(value="/{id}", method=RequestMethod.GET)
	public HttpEntity<GetAppInstanceResponse> getAppInstance(@PathVariable Long id) {
		GetAppInstanceResponse response = new GetAppInstanceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("getAppServer id = " + id);

		response.setMessage("AppInstance Found.");
		response.setStatus("SUCCESS");
		AppInstance appInstance = null;
		try {
			appInstance = appInstanceService.getAppInstance(id);
			logger.debug("getAppInstance: " + appInstance.toString());
		} catch (ServiceNotFoundException e) {
			response.setMessage("AppInstance Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		response.setAppInstance(appInstance);
		
		addLinks(id, response);

		return new ResponseEntity<GetAppInstanceResponse>(response,status);
	}

	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addAppServerDefaults(@RequestBody AppInstanceDefaults appInstance,
			HttpServletResponse response) {
		logger.debug("addAppInstanceDefaults: " + appInstance.toString());
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setAppInstanceDefaults(appInstance);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}
	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddAppInstanceResponse> addAppServer(@RequestBody AppInstance appInstance) {
		AddAppInstanceResponse addResponse = new AddAppInstanceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("addAppServer: " + appInstance.toString());
		try {
			appInstance = appInstance.mergeDefaults(defaultsService.getAppInstanceDefaults());
			AppInstance addedAppInstance = appInstanceService.addAppInstance(appInstance, defaultsService.getAppInstanceDefaults());
			addResponse.setEntityId(addedAppInstance.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedAppInstance.getId(), addResponse);
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} 

		return new ResponseEntity<AddAppInstanceResponse>(addResponse, status);
	}	
	
	@RequestMapping(value="/add", method = RequestMethod.POST)
	public HttpEntity<AddAppInstanceResponse> addAppServerInfo(@RequestBody AppInstance appInstance) {
		AddAppInstanceResponse addResponse = new AddAppInstanceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("addAppInstanceInfo: " + appInstance.toString());
		try {
			appInstance = appInstance.mergeDefaults(defaultsService.getAppInstanceDefaults());
			logger.debug("addAppInstanceInfo after merging defaults: " + appInstance.toString());
			AppInstance addedAppServer = appInstanceService.addAppInstanceInfo(appInstance);
			logger.debug("addAppInstanceInfo after adding to configuration info: " + appInstance.toString());
			addResponse.setEntityId(addedAppServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedAppServer.getId(), addResponse);
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddAppInstanceResponse>(addResponse, status);
	}

}

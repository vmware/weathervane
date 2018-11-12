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

import java.io.IOException;
import java.util.List;

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

import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.defaults.AppServerDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.ModifyServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.GetServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.AppServerService;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/appServer")
public class AppServerController {
	private static final Logger logger = LoggerFactory.getLogger(AppServerController.class);

	@Autowired
	private AppServerService appServerService;

	@Autowired
	private DefaultsService defaultsService;
	
	private void addLinks(Long id, ResourceSupport response) {
		response.add(linkTo(methodOn(AppServerController.class).getAppServer(id)).withSelfRel());
		response.add(linkTo(methodOn(AppServerController.class).configureAppServer(id)).withRel("configure"));
		response.add(linkTo(methodOn(AppServerController.class).startAppServer(id)).withRel("start"));
		response.add(linkTo(methodOn(AppServerController.class).removeAppServer(id)).withRel("remove"));
		response.add(linkTo(methodOn(AppServerController.class).warmAppServer(id)).withRel("warm"));
	}
	
	@RequestMapping(method=RequestMethod.GET)
	public HttpEntity<List<AppServer>> getAppServers() {
		List<AppServer> appServers = appServerService.getAppServers();
		HttpStatus status = HttpStatus.OK;

		return new ResponseEntity<List<AppServer>>(appServers,status);
	}
	
	@RequestMapping(value="/{id}", method=RequestMethod.GET)
	public HttpEntity<GetServiceResponse> getAppServer(@PathVariable Long id) {
		GetServiceResponse response = new GetServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("getAppServer id = " + id);

		response.setMessage("AppServer Found.");
		response.setStatus("SUCCESS");
		AppServer appServer = null;
		try {
			appServer = appServerService.getAppServer(id);
			logger.debug("getAppServer: " + appServer.toString());
		} catch (ServiceNotFoundException e) {
			response.setMessage("AppServer Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		response.setService(appServer);
		
		addLinks(id, response);

		return new ResponseEntity<GetServiceResponse>(response,status);
	}

	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addAppServerDefaults(@RequestBody AppServerDefaults appServer,
			HttpServletResponse response) {
		logger.debug("addAppServerDefaults: " + appServer.toString());
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setAppServerDefaults(appServer);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}
	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addAppServer(@RequestBody AppServer appServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("addAppServer: " + appServer.toString());
		try {
			appServer = appServer.mergeDefaults(defaultsService.getAppServerDefaults());
			AppServer addedAppServer = appServerService.addAppServer(appServer, defaultsService.getAppServerDefaults());
			addResponse.setEntityId(addedAppServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedAppServer.getId(), addResponse);
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (ServiceNotFoundException e) {
			addResponse.setMessage("Service not added");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (InterruptedException e) {
			addResponse.setMessage("Service not added");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (IOException e) {
			addResponse.setMessage("Service not added");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (AddFailedException e) {
			addResponse.setMessage("Service not added");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (IllegalConfigurationException e) {
			addResponse.setMessage("Incorrect Configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}	

	@RequestMapping(value="/{id}", method=RequestMethod.DELETE)
	public HttpEntity<ModifyServiceResponse> removeAppServer(@PathVariable Long id) {
		ModifyServiceResponse response = new ModifyServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("removeAppServer id = " + id);

		response.setMessage("AppServer removed.");
		response.setStatus("SUCCESS");
		try {
			appServerService.removeAppServer(id);
			logger.debug("removeAppServer:  removed");
		} catch (ServiceNotFoundException e) {
			response.setMessage("AppServer Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (IOException e) {
			response.setMessage("Web servers could not be reconfigured");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (InterruptedException e) {
			response.setMessage("Web servers could not be reconfigured");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		
		return new ResponseEntity<ModifyServiceResponse>(response,status);
	}

	@RequestMapping(value="/{id}/warm", method=RequestMethod.PUT)
	public HttpEntity<ModifyServiceResponse> warmAppServer(@PathVariable Long id) {
		ModifyServiceResponse response = new ModifyServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("warmAppServer id = " + id);

		response.setMessage("AppServer warmed.");
		response.setStatus("SUCCESS");
		try {
			appServerService.warmAppServer(id);
			logger.debug("warmAppServer:  warmed");
		} catch (ServiceNotFoundException e) {
			response.setMessage("AppServer Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} 
		
		return new ResponseEntity<ModifyServiceResponse>(response,status);
	}


	@RequestMapping(value="/warm", method=RequestMethod.PUT)
	public HttpEntity<ModifyServiceResponse> warmAppServers(@RequestBody List<Long> appServerIds) {
		ModifyServiceResponse response = new ModifyServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("warmAppServers");

		response.setMessage("AppServers warmed.");
		response.setStatus("SUCCESS");
		try {
			appServerService.warmAppServers(appServerIds);
			logger.debug("warmAppServers:  warmed");
		} catch (ServiceNotFoundException e) {
			response.setMessage(e.getMessage());
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} 
		
		return new ResponseEntity<ModifyServiceResponse>(response,status);
	}

	@RequestMapping(value="/add", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addAppServerInfo(@RequestBody AppServer appServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("addAppServerInfo: " + appServer.toString());
		try {
			appServer = appServer.mergeDefaults(defaultsService.getAppServerDefaults());
			logger.debug("addAppServerInfo after merging defaults: " + appServer.toString());
			AppServer addedAppServer = appServerService.addAppServerInfo(appServer);
			logger.debug("addAppServerInfo after adding to configuration info: " + appServer.toString());
			addResponse.setEntityId(addedAppServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedAppServer.getId(), addResponse);
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value = "/{appServerId}/configure", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> configureAppServer(@PathVariable Long appServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("configureAppServer id = " + appServerId);

		AppServerDefaults appServerDefaults = defaultsService.getAppServerDefaults();
		if (appServerDefaults == null) {
			addResponse.setMessage("No appServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				appServerService.configureAppServer(appServerId, appServerDefaults);
				addResponse.setEntityId(appServerId);
				addResponse.setMessage("App Server configured");
				addResponse.setStatus("SUCCESS");
				addLinks(appServerId, addResponse);
			} catch (ServiceNotFoundException e) {
				addResponse.setMessage("No app server found with id " + appServerId);
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			} catch (IOException e) {
				addResponse.setMessage("App Server has not been configured.");
				addResponse.setStatus("IOException");
				status = HttpStatus.CONFLICT;
			} catch (InterruptedException e) {
				addResponse.setMessage("App Server has not been configured.");
				addResponse.setStatus("InterruptedException");
				status = HttpStatus.CONFLICT;
			}
		}
		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value = "/{appServerId}/start", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> startAppServer(@PathVariable Long appServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("startAppServer id = " + appServerId);

		AppServerDefaults appServerDefaults = defaultsService.getAppServerDefaults();
		if (appServerDefaults == null) {
			addResponse.setMessage("No appServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				appServerService.startAppServer(appServerId, appServerDefaults);
				addResponse.setEntityId(appServerId);
				addResponse.setMessage("App Server configured");
				addResponse.setStatus("SUCCESS");
				addLinks(appServerId, addResponse);
			} catch (ServiceNotFoundException e) {
				addResponse.setMessage("No app server found with id " + appServerId);
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			} catch (IOException e) {
				addResponse.setMessage("App Server has not been started.");
				addResponse.setStatus("IOException");
				status = HttpStatus.CONFLICT;
			} catch (InterruptedException e) {
				addResponse.setMessage("App Server has not been started.");
				addResponse.setStatus("InterruptedException");
				status = HttpStatus.CONFLICT;
			}
		}
		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

}

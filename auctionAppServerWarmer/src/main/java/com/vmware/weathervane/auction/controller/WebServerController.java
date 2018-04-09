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

import com.vmware.weathervane.auction.model.configuration.WebServer;
import com.vmware.weathervane.auction.model.defaults.WebServerDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.ModifyServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.configuration.WebServerService;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/webServer")
public class WebServerController {
	private static final Logger logger = LoggerFactory.getLogger(WebServerController.class);

	@Autowired
	private WebServerService webServerService;

	@Autowired
	private DefaultsService defaultsService;
	
	@RequestMapping(value="/{id}", method= RequestMethod.GET)
	public HttpEntity<WebServer> getWebServer(@PathVariable Long id) {
		WebServer webServer = webServerService.getWebServer(id);
		HttpStatus status = HttpStatus.OK;

		return new ResponseEntity<WebServer>(webServer,status);
	}

	private void addLinks(Long id, ResourceSupport response) {
		response.add(linkTo(methodOn(WebServerController.class).getWebServer(id)).withSelfRel());
		response.add(linkTo(methodOn(WebServerController.class).configureWebServer(id)).withRel("configure"));
		response.add(linkTo(methodOn(WebServerController.class).removeWebServer(id)).withRel("remove"));
	}

	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addWebServerDefaults(@RequestBody WebServerDefaults webServer,
			HttpServletResponse response) {
		logger.debug("addWebServerDefaults: " + webServer.toString());
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setWebServerDefaults(webServer);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}
	
	@RequestMapping(value = "/add", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addWebServerInfo(@RequestBody WebServer webServer) {
		logger.debug("addWebServerInfo: " + webServer.toString());

		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			webServer = webServer.mergeDefaults(defaultsService.getWebServerDefaults());
			WebServer addedWebServer = webServerService.addWebServerInfo(webServer);
			addResponse.setEntityId(addedWebServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedWebServer.getId(), addResponse);
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addWebServer(@RequestBody WebServer webServer) {
		logger.debug("addWebServer: " + webServer.toString());

		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			webServer = webServer.mergeDefaults(defaultsService.getWebServerDefaults());
			WebServer addedWebServer = webServerService.addWebServer(webServer, defaultsService.getWebServerDefaults());
			addResponse.setEntityId(addedWebServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addLinks(addedWebServer.getId(), addResponse);
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
	public HttpEntity<ModifyServiceResponse> removeWebServer(@PathVariable Long id) {
		ModifyServiceResponse response = new ModifyServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("removeWebServer id = " + id);

		response.setMessage("WebServer removed.");
		response.setStatus("SUCCESS");
		try {
			webServerService.removeWebServer(id);
			logger.debug("removeWebServer:  removed");
		} catch (ServiceNotFoundException e) {
			response.setMessage("WebServer Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (IOException e) {
			response.setMessage("Lb servers could not be reconfigured");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		} catch (InterruptedException e) {
			response.setMessage("Lb servers could not be reconfigured");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		
		return new ResponseEntity<ModifyServiceResponse>(response,status);
	}

	@RequestMapping(value = "/{webServerId}/configure", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> configureWebServer(@PathVariable Long webServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;

		WebServerDefaults webServerDefaults = defaultsService.getWebServerDefaults();
		if (webServerDefaults == null) {
			addResponse.setMessage("No webServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				webServerService.configureWebServer(webServerId, webServerDefaults);
				addResponse.setEntityId(webServerId);
				addResponse.setMessage("App Server configured");
				addResponse.setStatus("SUCCESS");
			} catch (ServiceNotFoundException e) {
				addResponse.setMessage("App Server configuration has not been updated.");
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			} catch (IOException e) {
				addResponse.setMessage("App Server configuration has not been updated.");
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			} catch (InterruptedException e) {
				addResponse.setMessage("App Server configuration has not been updated.");
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			}
		}
		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

}

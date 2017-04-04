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

import com.vmware.weathervane.auction.model.configuration.NosqlServer;
import com.vmware.weathervane.auction.model.defaults.NosqlServerDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.GetServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.ModifyServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.configuration.NosqlServerService;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/nosqlServer")
public class NosqlServerController {
	private static final Logger logger = LoggerFactory.getLogger(NosqlServerController.class);

	@Autowired
	private NosqlServerService nosqlServerService;

	@Autowired
	private DefaultsService defaultsService;
	
	private void addLinks(Long id, ResourceSupport response) {
		response.add(linkTo(methodOn(NosqlServerController.class).getNosqlServer(id)).withSelfRel());
		response.add(linkTo(methodOn(NosqlServerController.class).configureNosqlServer(id)).withRel("configure"));
		response.add(linkTo(methodOn(NosqlServerController.class).removeNosqlServer(id)).withRel("remove"));
	}

	@RequestMapping(value="/{id}", method=RequestMethod.GET)
	public HttpEntity<GetServiceResponse> getNosqlServer(@PathVariable Long id) {
		GetServiceResponse response = new GetServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("getNosqlServer id = " + id);

		response.setMessage("NoSQLServer Found.");
		response.setStatus("SUCCESS");
		NosqlServer nosqlServer = null;
		try {
			nosqlServer = nosqlServerService.getNosqlServer(id);
			logger.debug("getNosqlServer: " + nosqlServer.toString());
		} catch (ServiceNotFoundException e) {
			response.setMessage("NosqlServer Not Found");
			response.setStatus("Failure");
			status = HttpStatus.CONFLICT;
		}
		response.setService(nosqlServer);
		
		addLinks(id, response);

		return new ResponseEntity<GetServiceResponse>(response,status);
	}

	
	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addNosqlServerDefaults(@RequestBody NosqlServerDefaults nosqlServer,
			HttpServletResponse response) {
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setNosqlServerDefaults(nosqlServer);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}
	
	@RequestMapping(value = "/add", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addNosqlServerInfo(@RequestBody NosqlServer nosqlServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			nosqlServer = nosqlServer.mergeDefaults(defaultsService.getNosqlServerDefaults());
			NosqlServer addedNosqlServer = nosqlServerService.addNosqlServer(nosqlServer);
			addResponse.setEntityId(addedNosqlServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(NosqlServerController.class).getNosqlServer(nosqlServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(NosqlServerController.class).configureNosqlServer(nosqlServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}	
	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addNosqlServer(@RequestBody NosqlServer nosqlServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			nosqlServer = nosqlServer.mergeDefaults(defaultsService.getNosqlServerDefaults());
			NosqlServer addedNosqlServer = nosqlServerService.addNosqlServer(nosqlServer);
			addResponse.setEntityId(addedNosqlServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(NosqlServerController.class).getNosqlServer(nosqlServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(NosqlServerController.class).configureNosqlServer(nosqlServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value = "/{nosqlServerId}/configure", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> configureNosqlServer(@PathVariable Long nosqlServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;

		NosqlServerDefaults nosqlServerDefaults = defaultsService.getNosqlServerDefaults();
		if (nosqlServerDefaults == null) {
			addResponse.setMessage("No nosqlServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				nosqlServerService.configureNosqlServer(nosqlServerId, nosqlServerDefaults);
				addResponse.setEntityId(nosqlServerId);
				addResponse.setMessage("App Server configured");
				addResponse.setStatus("SUCCESS");
			} catch (ServiceNotFoundException e) {
				addResponse.setMessage("App Server configuration has not been uploaded.");
				addResponse.setStatus("FAILURE");
				status = HttpStatus.CONFLICT;
			}
		}
		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value="/{id}", method=RequestMethod.DELETE)
	public HttpEntity<ModifyServiceResponse> removeNosqlServer(@PathVariable Long id) {
		ModifyServiceResponse response = new ModifyServiceResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("removeAppServer id = " + id);

		response.setMessage("NoSQLServer removed.");
		response.setStatus("SUCCESS");
		
		return new ResponseEntity<ModifyServiceResponse>(response,status);
	}

}

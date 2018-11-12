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

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.RestController;

import com.vmware.weathervane.auction.model.configuration.CoordinationServer;
import com.vmware.weathervane.auction.model.defaults.CoordinationServerDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.CoordinationServerService;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/coordinationServer")
public class CoordinationServerController {

	@Autowired
	private CoordinationServerService coordinationServerService;

	@Autowired
	private DefaultsService defaultsService;
	
	@RequestMapping(value="/{id}", method= RequestMethod.GET)
	public HttpEntity<CoordinationServer> getCoordinationServer(@PathVariable Long id) {
		CoordinationServer coordinationServer = coordinationServerService.getCoordinationServer(id);
		HttpStatus status = HttpStatus.OK;

		return new ResponseEntity<CoordinationServer>(coordinationServer,status);
	}

	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addCoordinationServerDefaults(@RequestBody CoordinationServerDefaults coordinationServer,
			HttpServletResponse response) {
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setCoordinationServerDefaults(coordinationServer);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}
	
	@RequestMapping(value = "/add", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addCoordinationServerInfo(@RequestBody CoordinationServer coordinationServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			coordinationServer = coordinationServer.mergeDefaults(defaultsService.getCoordinationServerDefaults());
			CoordinationServer addedCoordinationServer = coordinationServerService.addCoordinationServer(coordinationServer);
			addResponse.setEntityId(addedCoordinationServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(CoordinationServerController.class).getCoordinationServer(coordinationServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(CoordinationServerController.class).configureCoordinationServer(coordinationServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}
	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addCoordinationServer(@RequestBody CoordinationServer coordinationServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			coordinationServer = coordinationServer.mergeDefaults(defaultsService.getCoordinationServerDefaults());
			CoordinationServer addedCoordinationServer = coordinationServerService.addCoordinationServer(coordinationServer);
			addResponse.setEntityId(addedCoordinationServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(CoordinationServerController.class).getCoordinationServer(coordinationServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(CoordinationServerController.class).configureCoordinationServer(coordinationServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value = "/{coordinationServerId}/configure", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> configureCoordinationServer(@PathVariable Long coordinationServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;

		CoordinationServerDefaults coordinationServerDefaults = defaultsService.getCoordinationServerDefaults();
		if (coordinationServerDefaults == null) {
			addResponse.setMessage("No coordinationServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				coordinationServerService.configureCoordinationServer(coordinationServerId, coordinationServerDefaults);
				addResponse.setEntityId(coordinationServerId);
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

}

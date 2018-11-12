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

import com.vmware.weathervane.auction.model.configuration.MsgServer;
import com.vmware.weathervane.auction.model.defaults.MsgServerDefaults;
import com.vmware.weathervane.auction.representation.configuration.AddServiceResponse;
import com.vmware.weathervane.auction.representation.configuration.SetDefaultsResponse;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.configuration.MsgServerService;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/msgServer")
public class MsgServerController {

	@Autowired
	private MsgServerService msgServerService;

	@Autowired
	private DefaultsService defaultsService;
	
	@RequestMapping(value="/{id}", method= RequestMethod.GET)
	public HttpEntity<MsgServer> getMsgServer(@PathVariable Long id) {
		MsgServer msgServer = msgServerService.getMsgServer(id);
		HttpStatus status = HttpStatus.OK;

		return new ResponseEntity<MsgServer>(msgServer,status);
	}

	@RequestMapping(value = "/defaults", method = RequestMethod.POST)
	public HttpEntity<SetDefaultsResponse> addMsgServerDefaults(@RequestBody MsgServerDefaults msgServer,
			HttpServletResponse response) {
		SetDefaultsResponse setResponse = new SetDefaultsResponse();
		HttpStatus status = HttpStatus.OK;
		defaultsService.setMsgServerDefaults(msgServer);
		setResponse.setMessage("Defaults set.");
		setResponse.setStatus("SUCCESS");

		return new ResponseEntity<SetDefaultsResponse>(setResponse, status);
	}

	@RequestMapping(value = "/add", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addMsgServerInfo(@RequestBody MsgServer msgServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			msgServer = msgServer.mergeDefaults(defaultsService.getMsgServerDefaults());
			MsgServer addedMsgServer = msgServerService.addMsgServer(msgServer);
			addResponse.setEntityId(addedMsgServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(MsgServerController.class).getMsgServer(msgServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(MsgServerController.class).configureMsgServer(msgServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}
	
	@RequestMapping(method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> addMsgServer(@RequestBody MsgServer msgServer) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;
		try {
			msgServer = msgServer.mergeDefaults(defaultsService.getMsgServerDefaults());
			MsgServer addedMsgServer = msgServerService.addMsgServer(msgServer);
			addResponse.setEntityId(addedMsgServer.getId());
			addResponse.setMessage("Service added to configuration");
			addResponse.setStatus("SUCCESS");
			addResponse.add(linkTo(methodOn(MsgServerController.class).getMsgServer(msgServer.getId())).withSelfRel());
			addResponse.add(linkTo(methodOn(MsgServerController.class).configureMsgServer(msgServer.getId())).withRel("configure"));
		} catch (DuplicateServiceException e) {
			addResponse.setMessage("Service already exists in configuration");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<AddServiceResponse>(addResponse, status);
	}

	@RequestMapping(value = "/{msgServerId}/configure", method = RequestMethod.POST)
	public HttpEntity<AddServiceResponse> configureMsgServer(@PathVariable Long msgServerId) {
		AddServiceResponse addResponse = new AddServiceResponse();
		HttpStatus status = HttpStatus.OK;

		MsgServerDefaults msgServerDefaults = defaultsService.getMsgServerDefaults();
		if (msgServerDefaults == null) {
			addResponse.setMessage("No msgServer defaults set");
			addResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} else {
			try {
				msgServerService.configureMsgServer(msgServerId, msgServerDefaults);
				addResponse.setEntityId(msgServerId);
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

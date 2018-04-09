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
import java.util.ArrayList;
import java.util.List;

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

import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.configuration.WebServer;
import com.vmware.weathervane.auction.representation.configuration.ChangeConfigurationRequest;
import com.vmware.weathervane.auction.representation.configuration.ChangeConfigurationResponse;
import com.vmware.weathervane.auction.representation.configuration.ConfigurationResponse;
import com.vmware.weathervane.auction.service.configuration.AppServerService;
import com.vmware.weathervane.auction.service.configuration.ConfigurationManagerService;
import com.vmware.weathervane.auction.service.configuration.ConfigurationService;
import com.vmware.weathervane.auction.service.configuration.DbServerService;
import com.vmware.weathervane.auction.service.configuration.DefaultsService;
import com.vmware.weathervane.auction.service.configuration.FileServerService;
import com.vmware.weathervane.auction.service.configuration.IpManagerService;
import com.vmware.weathervane.auction.service.configuration.LbServerService;
import com.vmware.weathervane.auction.service.configuration.MsgServerService;
import com.vmware.weathervane.auction.service.configuration.NosqlServerService;
import com.vmware.weathervane.auction.service.configuration.WebServerService;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@RestController
@RequestMapping("/configuration")
public class ConfigurationController {
	private static final Logger logger = LoggerFactory.getLogger(ConfigurationController.class);

	@Autowired
	private AppServerService appServerService;

	@Autowired
	private ConfigurationManagerService configurationManagerService;

	@Autowired
	private DbServerService dbServerService;

	@Autowired
	private FileServerService fileServerService;

	@Autowired
	private IpManagerService ipManagerService;

	@Autowired
	private LbServerService lbServerService;

	@Autowired
	private MsgServerService msgServerService;

	@Autowired
	private NosqlServerService nosqlServerService;

	@Autowired
	private WebServerService webServerService;

	@Autowired
	private DefaultsService defaultsService;

	@Autowired
	private ConfigurationService configurationService;

	@RequestMapping(method= RequestMethod.GET)
	public HttpEntity<ConfigurationResponse> getConfiguration() {
		ConfigurationResponse configuration = new ConfigurationResponse();
		HttpStatus status = HttpStatus.OK;
		
		configuration.setAppServers(appServerService.getAppServers());
		configuration.setConfigurationManagers(configurationManagerService.getConfigurationManagers());
		configuration.setDbServers(dbServerService.getDbServers());
		configuration.setFileServers(fileServerService.getFileServers());
		configuration.setIpManagers(ipManagerService.getIpManagers());
		configuration.setLbServers(lbServerService.getLbServers());
		configuration.setMsgServers(msgServerService.getMsgServers());
		configuration.setNosqlServers(nosqlServerService.getNosqlServers());
		configuration.setWebServers(webServerService.getWebServers());
		
		configuration.add(linkTo(methodOn(ConfigurationController.class).getConfiguration()).withSelfRel());
		
		return new ResponseEntity<ConfigurationResponse>(configuration, status);
	}

	@RequestMapping(method = RequestMethod.PUT)
	public HttpEntity<ChangeConfigurationResponse> changeConfiguration(@RequestBody ChangeConfigurationRequest changeConfigurationRequest) {
		ChangeConfigurationResponse changeConfigurationResponse = new ChangeConfigurationResponse();
		HttpStatus status = HttpStatus.OK;
		logger.debug("changeConfiguration: " + changeConfigurationRequest.toString());
		try {

			List<AppServer> mergedAppServers = new ArrayList<AppServer>();
			List<WebServer> mergedWebServers = new ArrayList<WebServer>();
			if (changeConfigurationRequest.getAppServersToAdd() != null) {
				for (AppServer appServer : changeConfigurationRequest.getAppServersToAdd()) {
					appServer = appServer.mergeDefaults(defaultsService.getAppServerDefaults());
					mergedAppServers.add(appServer);
				}
			}
			if (changeConfigurationRequest.getWebServersToAdd() != null) {
				for (WebServer webServer : changeConfigurationRequest.getWebServersToAdd()) {
					webServer = webServer.mergeDefaults(defaultsService.getWebServerDefaults());
					mergedWebServers.add(webServer);
				}
			}
			ChangeConfigurationRequest mergedRequest = new ChangeConfigurationRequest(mergedAppServers, mergedWebServers,
					changeConfigurationRequest.getNumAppServersToRemove(), changeConfigurationRequest.getNumWebServersToRemove());
			changeConfigurationResponse = configurationService.changeConfiguration(mergedRequest);

			changeConfigurationResponse.setMessage("Configuration changed successfully.");
			changeConfigurationResponse.setStatus("SUCCESS");
		} catch (DuplicateServiceException e) {
			changeConfigurationResponse.setMessage("Service already exists in configuration");
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (ServiceNotFoundException e) {
			changeConfigurationResponse.setMessage(e.getMessage());
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (InterruptedException e) {
			changeConfigurationResponse.setMessage("Service not added");
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (IOException e) {
			changeConfigurationResponse.setMessage("Service not added");
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (AddFailedException e) {
			changeConfigurationResponse.setMessage(e.getMessage());
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		} catch (IllegalConfigurationException e) {
			changeConfigurationResponse.setMessage(e.getMessage());
			changeConfigurationResponse.setStatus("FAILURE");
			status = HttpStatus.CONFLICT;
		}

		return new ResponseEntity<ChangeConfigurationResponse>(changeConfigurationResponse, status);
	}	

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import java.io.IOException;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.Cookie;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;
import org.springframework.web.bind.annotation.ResponseStatus;

import com.vmware.weathervane.auction.rest.representation.AuthenticationRequestRepresentation;
import com.vmware.weathervane.auction.rest.representation.LoginResponse;
import com.vmware.weathervane.auction.service.AuthenticationService;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;


@Controller
public class LoginLogoutController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(LoginLogoutController.class);
			
	private AuthenticationService authenticationService;
	
	@Inject
	@Named("authenticationService")
	public void setAuthenticationService(AuthenticationService authenticationService) {
		this.authenticationService = authenticationService;
	}
	
	@RequestMapping(value = "/login", method = RequestMethod.POST)
	@ResponseStatus( HttpStatus.CREATED )
	@ResponseBody
	public LoginResponse login(@RequestBody AuthenticationRequestRepresentation authenticationRequest, HttpServletResponse response,
			HttpServletRequest request) throws AuthenticationException {
		logger.info("login username = " + authenticationRequest.getUsername() + ", password = " + authenticationRequest.getPassword());
		
		/* 
		 * Create a session for this user to get an ID to be used for routing requests.
		 * No data is stored in the session.
		 */
		request.getSession();
			
		LoginResponse authenticationResponse = authenticationService.login(authenticationRequest.getUsername(), authenticationRequest.getPassword());
		Cookie cookie = new Cookie("AUTHTOKEN", authenticationResponse.getAuthToken());
		response.addCookie(cookie);
		
		
		logger.debug("login: username = " + authenticationRequest.getUsername() + ", authtoken = " + authenticationResponse.getAuthToken());
		return authenticationResponse;// authToken and accountId;
	}

	@RequestMapping(value = "/logout", method = RequestMethod.GET)
	@ResponseStatus( HttpStatus.OK )
	@ResponseBody
	public void logout(HttpServletRequest request, HttpServletResponse response) {
		request.getSession().invalidate();
		
		String username = this.getSecurityUtil().getUsernameFromPrincipal();
		logger.info("logout username = " + username + ", authToken = " + this.getSecurityUtil().getAuthToken());
		try {
			authenticationService.logout(this.getSecurityUtil().getAuthToken());
		} catch (InvalidStateException e) {
			try {
				response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "User not authenticated");
			} catch (IOException e1) {
				// TODO Auto-generated catch block
				e1.printStackTrace();
			}
		}
	}
	
	@RequestMapping(value = "/login", method = RequestMethod.GET)
	@ResponseStatus( HttpStatus.METHOD_NOT_ALLOWED )
	public void get() {
		
	}


}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import com.vmware.weathervane.auction.rest.representation.LoginResponse;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public interface AuthenticationService {

	public LoginResponse login(String username, String password) throws AuthenticationException;		

	public void logout(String authToken) throws InvalidStateException;
		
}

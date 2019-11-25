/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;

public class LoginResponse implements Serializable {
	
	private static final long serialVersionUID = 1L;
	
	private Long id;
	private String authToken;
	private String username;

	public LoginResponse() {
		
	}
	
	public LoginResponse(Long id, String authToken, String username) {
		this.id = id;
		this.authToken = authToken;
		this.username = username;
	}
	
	public Long getId() {
		return id;
	}
	public void setId(Long id) {
		this.id = id;
	}

	public String getAuthToken() {
		return authToken;
	}


	public void setAuthtoken(String authToken) {
		this.authToken = authToken;
	}


	public String getUsername() {
		return username;
	}


	public void setUsername(String username) {
		this.username = username;
	}
	
}

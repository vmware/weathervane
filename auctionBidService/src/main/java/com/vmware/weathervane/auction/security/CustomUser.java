/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/*
 * Copyright 2002-2012 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 * 
 * Adapted from SpringTrader by Harold Rosenberg
 */
package com.vmware.weathervane.auction.security;

import java.util.Collection;

import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.userdetails.User;


/**
 *  Custom user object that includes accountId
 *  
 *  @author Brian Dussault 
 */

@SuppressWarnings("serial")
public class CustomUser extends User {
	

	private Long userId;
	private String authToken;
	
	public CustomUser(String username, String password, boolean isEnabled,
			Collection<? extends GrantedAuthority> authorities, Long accountId, String token) {
		super(username, password, isEnabled, true, true, true, authorities);
		this.userId = accountId;
		this.authToken = token;
	}

	
	public String getAuthToken() {
		return authToken;
	}

	public void setAccountId(Long accountId) {
		this.userId = accountId;
	}

	public Long getAccountId() {
		return userId;
	}

	@Override
	public String toString() {
		return "CustomUser [accountId=" + userId + ", authToken=" + authToken + "]";
	}

	
}

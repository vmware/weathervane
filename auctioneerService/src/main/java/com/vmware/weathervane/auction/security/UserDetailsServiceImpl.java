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
 */
package com.vmware.weathervane.auction.security;

import java.util.ArrayList;
import java.util.List;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.userdetails.User;
import org.springframework.security.core.userdetails.UserDetails;
import org.springframework.security.core.userdetails.UserDetailsService;
import org.springframework.security.core.userdetails.UsernameNotFoundException;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.UserService;

;

/**
 * UserDetailsServiceImpl provides authentication lookup service which validates
 * the http header token
 * 
 * @author Brian Dussault
 * 
 *         Adapted from nanotrader by Harold Rosenberg
 */
@Service
public class UserDetailsServiceImpl implements UserDetailsService {

	private static Logger logger = LoggerFactory
			.getLogger(UserDetailsServiceImpl.class);

	private static long userByAuthTokenGets = 0;


	@Inject
	@Named("userService")
	private UserService userService;		

	@Override
	public UserDetails loadUserByUsername(String token)
			throws UsernameNotFoundException {

		if (token == null) {
			logger.error("UserDetailsServiceImpl.loadUserByUsername(): User not found with null token");
			throw new UsernameNotFoundException(
					"UserDetailsServiceImpl.loadUserByUsername(): User not found with null token");
		}

		UserRepresentation theUser = null;
		userByAuthTokenGets++;
		logger.info("loadUserByUsername: userService looking up user by token = " + token);
		theUser = userService.getUserByAuthToken(token);
		
		logger.info("loadUserByUsername: userService returned user " + theUser + ", token = " + token);
		
		User user = new CustomUser(theUser.getUsername(), "unknown",
				theUser.isEnabled(), getAuthorities(theUser),
				theUser.getId(), token);
		if (logger.isDebugEnabled()) {
			logger.debug("UserDetailsServiceImpl.loadUserByUsername(): user="
					+ user + " username::token" + token);
		}

		return user;
	}

	private List<GrantedAuthority> getAuthorities(UserRepresentation theUser) {
		List<GrantedAuthority> authList = new ArrayList<GrantedAuthority>(1);
		
		authList.add(new SimpleGrantedAuthority(theUser.getAuthorities()));
		return authList;
	}

	public static long getUserByAuthTokenGets() {
		return userByAuthTokenGets;
	}

	public static void setUserByAuthTokenGets(long userByAuthTokenGets) {
		UserDetailsServiceImpl.userByAuthTokenGets = userByAuthTokenGets;
	}

}

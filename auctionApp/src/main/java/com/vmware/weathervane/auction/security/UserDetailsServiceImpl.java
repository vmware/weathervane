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

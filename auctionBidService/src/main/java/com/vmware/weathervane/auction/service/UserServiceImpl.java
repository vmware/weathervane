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
package com.vmware.weathervane.auction.service;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;

public class UserServiceImpl implements UserService {

	private static final Logger logger = LoggerFactory.getLogger(UserServiceImpl.class);

	private static long userByAuthTokenMisses = 0;

	@Inject
	@Named("userDao")
	UserDao userDao;

	
	public UserServiceImpl() {

	}

	@Override
	@Cacheable(value="authTokenCache")
	public UserRepresentation getUserByAuthToken(String authToken) {
		logger.info("getUserByAuthToken: Cache Miss authtoken = " + authToken);
		
		userByAuthTokenMisses++;
		User theUser = userDao.getUserByAuthToken(authToken);
		if (theUser == null) {
			UsernameNotFoundException exception = new UsernameNotFoundException(
					"UserServiceImpl.getUserByAuthToken(): User not found with token:"
							+ authToken); 
			logger.info("UserServiceImpl.getUserByAuthToken(): User not found with token:" + authToken + 
					", stack:");
			throw exception;
		} else if (!theUser.isLoggedin()) {
			UsernameNotFoundException exception = new UsernameNotFoundException(
					"UserServiceImpl.getUserByAuthToken(): User is not logged in with token:"
							+ authToken); 
			logger.info("UserServiceImpl.getUserByAuthToken(): User is not logged in with token:" + authToken );
			throw exception;
		}

		
		logger.debug("getUserByAuthToken(): User " + theUser.getEmail() + " found with token: " + authToken);
		return new UserRepresentation(theUser);
	}

	public void setUserDao(UserDao userDao) {
		this.userDao = userDao;
	}
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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

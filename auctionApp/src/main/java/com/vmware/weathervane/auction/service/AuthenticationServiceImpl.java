/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.util.UUID;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.repository.event.AttendanceRecordRepository;
import com.vmware.weathervane.auction.rest.representation.LoginResponse;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.exception.AuthenticationException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public class AuthenticationServiceImpl implements AuthenticationService {

	private static final Logger logger = LoggerFactory.getLogger(AuthenticationServiceImpl.class);
	
	@Inject
	@Named("userDao")
	UserDao userDao;

	@Inject
	AttendanceRecordRepository attendanceRecordRepository;
	
	
	@Inject
	CacheManager cacheManager;
	
	public AuthenticationServiceImpl() {

	}

	@Override
	@Transactional
	public LoginResponse login(String username, String password) throws AuthenticationException {
		
		LoginResponse loginResponse = null;
		User theUser = null;
		try {
			theUser = userDao.getUserByName(username);
		} catch (EmptyResultDataAccessException ex) {
			logger.warn("User " + username + " not found");
		}
		if ((theUser != null) && (theUser.getPassword().equals(password))) {
			String authToken = UUID.randomUUID().toString();
			theUser.setAuthToken(authToken);
			theUser.setLoggedin(true);
            loginResponse = new LoginResponse(theUser.getId(), theUser.getAuthToken(), theUser.getEmail());
            
            /*
             * Populate the cache here
             */
            cacheManager.getCache("authTokenCache").put(authToken, new UserRepresentation(theUser));
            
            logger.debug("Login succeeded for username = " + username + ", password = " + password + ", authToken = " + theUser.getAuthToken());
		} else {
	           logger.error("AuthenticationServiceImpl.login failed to find username=" + username + " password" + password);
	            throw new AuthenticationException("Login failed for user: " + username);
		}
		
		return loginResponse;
	}

	@Override
	@Transactional
	@CacheEvict(value="authTokenCache")
	public void logout(String authToken) throws InvalidStateException {
		logger.info("logout for user with authToken " + authToken);
		User theUser = userDao.getUserByAuthToken(authToken);
		if (theUser != null) {
	 		theUser.setLoggedin(false);
	 		theUser.setAuthToken(null); // remove token
			userDao.update(theUser);
			attendanceRecordRepository.leaveAuctionsForUser(theUser.getId());
		} else {
			throw new InvalidStateException("User not authenticated");
		}
				
	}
	
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import javax.inject.Inject;
import javax.inject.Named;
import javax.transaction.Transactional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.security.core.userdetails.UsernameNotFoundException;

import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.User.UserState;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.exception.DuplicateEntityException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public class UserServiceImpl implements UserService {

	private static final Logger logger = LoggerFactory.getLogger(UserServiceImpl.class);

	private static long userByAuthTokenMisses = 0;

	@Inject
	@Named("userDao")
	UserDao userDao;

	
	public UserServiceImpl() {

	}

	@Override
	public UserRepresentation getUserByName(String username) {
		User theUser = userDao.getUserByName(username);
		logger.debug("UserServiceImpl::getUserByName username=" + username + " theUser=" + theUser.toString());

		return new UserRepresentation(theUser);
	}

	@Override
	public UserRepresentation registerUser(UserRepresentation newUser) throws DuplicateEntityException {
		logger.debug("UserServiceImpl::registerUser");

		// Check on whether user is already registered
		boolean existing = true;
		try {
			userDao.getUserByName(newUser.getUsername());
			logger.warn("UserServiceImpl::registerUser User already exists");
			newUser.setState(UserState.DUPLICATE);
		} catch (EmptyResultDataAccessException ex) {
			logger.info("UserServiceImpl::registerUser EmptyResultDataAccessException");
			existing = false;
		}

		if (existing != false) {
			throw new DuplicateEntityException("Username is already registered");
		}

		// ToDo: Once financialInstition is implemented, check whether entered
		// financial information is correct

		User theUser = new User();
		theUser.setAuthorities(newUser.getAuthorities());
		theUser.setCreditLimit(newUser.getCreditLimit());
		theUser.setEmail(newUser.getUsername());
		theUser.setEnabled(true);
		theUser.setLoggedin(false);
		theUser.setFirstname(newUser.getFirstname());
		theUser.setLastname(newUser.getLastname());
		theUser.setPassword(newUser.getPassword());
		theUser.setState(UserState.REGISTERED);
		
		userDao.save(theUser);

		return new UserRepresentation(theUser);
	}

	@Override
	@Transactional
	public void deleteUser(UserRepresentation newUser) throws InvalidStateException {
		logger.debug("UserServiceImpl::registerUser");

		// Check on whether user is already registered
		boolean existing = false;
		User theUser = null;
		try {
			theUser = userDao.getUserByName(newUser.getUsername());
		} catch (EmptyResultDataAccessException ex) {
			logger.warn("UserServiceImpl::registerUser EmptyResultDataAccessException");
			existing = true;
		}

		if (existing == false) {
			throw new InvalidStateException("Username does not exist");
		}
		
		userDao.delete(theUser);

	}

	@Override
	public UserRepresentation updateUser(UserRepresentation theUser) throws DuplicateEntityException {
		logger.debug("UserServiceImpl::updateUser");
		
		User updateUser = new User();
		
		updateUser.setId(theUser.getId());
		updateUser.setAuthorities(theUser.getAuthorities());
		updateUser.setCreditLimit(theUser.getCreditLimit());
		updateUser.setEmail(theUser.getUsername());
		updateUser.setFirstname(theUser.getFirstname());
		updateUser.setLastname(theUser.getLastname());
		updateUser.setPassword(theUser.getPassword());

		try {
			updateUser = userDao.updateUser(updateUser);
		} catch (DataIntegrityViolationException ex) {
			throw new DuplicateEntityException(ex.getMessage());
		}
		return new UserRepresentation(updateUser);
	}

	@Override
	public UserRepresentation getUser(Long id) {

		logger.debug("UserServiceImpl::getUser id = " + id + "; intvalue = " + id.intValue());

		User theUser = userDao.get(id);
		return new UserRepresentation(theUser);
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

	@Override
	public long getUserByAuthTokenMisses() {
		return userByAuthTokenMisses;
	}
}

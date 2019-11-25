/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.controllers;

import javax.annotation.PreDestroy;
import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.CannotAcquireLockException;
import org.springframework.orm.ObjectOptimisticLockingFailureException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Controller;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestMethod;
import org.springframework.web.bind.annotation.ResponseBody;

import com.vmware.weathervane.auction.data.model.User.UserState;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.security.UserDetailsServiceImpl;
import com.vmware.weathervane.auction.service.UserService;
import com.vmware.weathervane.auction.service.exception.DuplicateEntityException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

@Controller
@RequestMapping(value="/user")
public class UserController extends BaseController {
	private static final Logger logger = LoggerFactory.getLogger(UserController.class);
		
	private UserService userService;
	
	public UserService getUserService() {
		return userService;
	}

	@Inject
	@Named("userService")
	public void setUserService(UserService userService) {
		this.userService = userService;
	}
		
	@Inject
	UserDetailsServiceImpl userDetailsServiceImpl;
	
	@PreDestroy
	private void printUserCacheStats() {
		double userByAuthTokenMissRate = userService.getUserByAuthTokenMisses() / (double) UserDetailsServiceImpl.getUserByAuthTokenGets();
		
		logger.warn("User Cache Stats: ");
		logger.warn("UserByAuthToken.  Gets = " + UserDetailsServiceImpl.getUserByAuthTokenGets() + ", misses = " + userService.getUserByAuthTokenMisses() + ", miss rate = " + userByAuthTokenMissRate);
	}

	@RequestMapping(method=RequestMethod.POST)
	public @ResponseBody UserRepresentation registerUser( @RequestBody UserRepresentation theUser, HttpServletResponse response) {
		logger.info("UserController::registerUser username = " + theUser.getUsername());
		
		// Check whether passwords are the same.  This check could be done in 
		// javascript in the Browser, but do here as well for safety.
		if (!theUser.getPassword().equals(theUser.getRepeatPassword())) {
			theUser.setState(UserState.NOPASSWORD);
			return theUser;
		} else {
			Boolean suceeded = false;
			while (!suceeded) {
				try {
					theUser = userService.registerUser(theUser);
					 suceeded = true;
				} catch (ObjectOptimisticLockingFailureException ex) {
					logger.info("UserController::registerUser got ObjectOptimisticLockingFailureException with message "
							+ ex.getMessage());
				} catch (CannotAcquireLockException ex) {
					logger.warn("UserController::registerUser got CannotAcquireLockException with message "
							+ ex.getMessage());

				} catch (DuplicateEntityException e) {
					theUser.setState(UserState.DUPLICATE);
					response.setStatus(HttpServletResponse.SC_CONFLICT);
					return theUser;
				}
			}

		}
								
		return theUser;
	}

	@RequestMapping(method=RequestMethod.DELETE)
	public @ResponseBody UserRepresentation deleteUser( @RequestBody UserRepresentation theUser, HttpServletResponse response) {
		logger.info("UserController::deleteUser username = " + theUser.getUsername());
		
		Boolean suceeded = false;
		while (!suceeded) {
			try {
				userService.deleteUser(theUser);
				suceeded = true;
			} catch (InvalidStateException e) {
				theUser.setState(UserState.INCOMPLETE);
				response.setStatus(HttpServletResponse.SC_CONFLICT);
				return theUser;
			}
		}
			
		return theUser;
	}
	
	@RequestMapping(value="/{id}", method=RequestMethod.GET)
	public @ResponseBody UserRepresentation getUser(@PathVariable long id, HttpServletResponse response) {
		UserRepresentation theUser = null;
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("UserController::getUser id = " + id + ", username = " + username);		
		try {
			this.getSecurityUtil().checkAccount(id);
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;	
		}
		
		try {
			theUser= userService.getUser(id);
		} catch (IndexOutOfBoundsException ex) {
			theUser = null;
			response.setStatus(HttpServletResponse.SC_NOT_FOUND);
			return null;
		}
		
		return theUser;

	}
	
	@RequestMapping(value="/{id}", method=RequestMethod.PUT)
	public @ResponseBody UserRepresentation updateUser( @PathVariable long id, @RequestBody UserRepresentation theUser, HttpServletResponse response) {
		String username = this.getSecurityUtil().getUsernameFromPrincipal();

		logger.info("UserController::updateUser username = " + username);
		
		try {
			this.getSecurityUtil().checkAccount(theUser.getId());
		} catch (AccessDeniedException ex) {
			response.setStatus(HttpServletResponse.SC_FORBIDDEN);
			return null;	
		}
		
		
		// Check whether passwords are the same.  This check could be done in 
		// javascript in the Browser, but do here as well for safety.
		if ((theUser.getPassword() == null)|| (theUser.getRepeatPassword() == null)) {
			response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
			theUser.setState(UserState.NOPASSWORD);			
		} else if (!theUser.getPassword().equals(theUser.getRepeatPassword())) {
			response.setStatus(HttpServletResponse.SC_BAD_REQUEST);
			theUser.setState(UserState.NOPASSWORD);
		} else {
			Boolean suceeded = false;
			while (!suceeded) {
				try {
					theUser = userService.updateUser(theUser);
					 suceeded = true;
				} catch (ObjectOptimisticLockingFailureException ex) {
					logger.info("UserController::updateUser got ObjectOptimisticLockingFailureException with message "
							+ ex.getMessage());
				} catch (CannotAcquireLockException ex) {
					logger.warn("UserController::updateUser got CannotAcquireLockException with message "
							+ ex.getMessage());
				} catch (DuplicateEntityException ex) {
					response.setStatus(HttpServletResponse.SC_CONFLICT);
					return null;
				}
			}

		}
								
		return theUser;
	}

}

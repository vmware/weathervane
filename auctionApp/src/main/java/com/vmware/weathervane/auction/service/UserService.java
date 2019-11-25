/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.exception.DuplicateEntityException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public interface UserService {

	/**
	 * @param username
	 * @return
	 */
	UserRepresentation getUserByName(String username);

	/**
	 * @param newUser
	 * @return
	 */
	UserRepresentation registerUser(UserRepresentation newUser)  throws DuplicateEntityException;

	/**
	 * @param id
	 * @return
	 */
	UserRepresentation getUser(Long id);

	public UserRepresentation getUserByAuthToken(String authToken);

	UserRepresentation updateUser(UserRepresentation newUser) throws DuplicateEntityException;

	long getUserByAuthTokenMisses();

	void deleteUser(UserRepresentation newUser) throws InvalidStateException;

}

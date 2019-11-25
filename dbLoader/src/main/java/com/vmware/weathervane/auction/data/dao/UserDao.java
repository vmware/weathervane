/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.List;

import com.vmware.weathervane.auction.data.model.User;

public interface UserDao extends GenericDao<User, Long> {
	public User getUserByName(String username);

	public User getUserByAuthToken(String authToken);

	public int clearAllAuthTokens();
	public int resetAllCreditLimits();

	public User updateUser(User updateUser);

	List<User> getLoggedInUsers();

	int clearAllLoggedIn();

}

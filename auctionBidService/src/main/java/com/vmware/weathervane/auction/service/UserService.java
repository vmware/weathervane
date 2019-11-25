/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;

public interface UserService {

	public UserRepresentation getUserByAuthToken(String authToken);

}

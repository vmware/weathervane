/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service.exception;

/**
 * @author Hal
 *
 */
public class AuthenticationException extends LiveAuctionServiceException {

	public AuthenticationException() {
		super();
	}
	
	public AuthenticationException(String msg) {
		super(msg);
	}

}

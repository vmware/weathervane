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
public class DuplicateEntityException extends LiveAuctionServiceException {

	public DuplicateEntityException() {
		super();
	}
	
	public DuplicateEntityException(String msg) {
		super(msg);
	}

}

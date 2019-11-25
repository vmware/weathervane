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
public class AuctionNoItemsException extends LiveAuctionServiceException {

	public AuctionNoItemsException() {
		super();
	}
	
	public AuctionNoItemsException(String msg) {
		super(msg);
	}

}

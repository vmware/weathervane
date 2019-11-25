/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.exception;

/**
 * @author Hal
 *
 */
public class DuplicateServiceException extends Exception {

	public DuplicateServiceException() {
		super();
	}
	
	public DuplicateServiceException(String msg) {
		super(msg);
	}

}

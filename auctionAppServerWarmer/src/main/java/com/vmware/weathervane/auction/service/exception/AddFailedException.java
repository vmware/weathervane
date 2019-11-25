/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.exception;

/**
 * @author Hal
 *
 */
public class AddFailedException extends Exception {

	public AddFailedException() {
		super();
	}
	
	public AddFailedException(String msg) {
		super(msg);
	}

}

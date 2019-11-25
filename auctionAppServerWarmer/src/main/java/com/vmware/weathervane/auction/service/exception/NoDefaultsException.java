/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.exception;

/**
 * @author Hal
 *
 */
public class NoDefaultsException extends Exception {

	public NoDefaultsException() {
		super();
	}
	
	public NoDefaultsException(String msg) {
		super(msg);
	}

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.exception;

/**
 * @author Hal
 *
 */
public class IllegalConfigurationException extends Exception {

	public IllegalConfigurationException() {
		super();
	}
	
	public IllegalConfigurationException(String msg) {
		super(msg);
	}

}

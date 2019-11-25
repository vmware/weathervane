/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.data.imageStore;

/**
 * @author Hal
 *
 */
public class NoSuchImageException extends Exception {

	public NoSuchImageException() {
		super();
	}
	
	public NoSuchImageException(String msg) {
		super(msg);
	}

}

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
public class NoBenchmarkInfoNeededException extends Exception {

	public NoBenchmarkInfoNeededException() {
		super();
	}
	
	public NoBenchmarkInfoNeededException(String msg) {
		super(msg);
	}

}

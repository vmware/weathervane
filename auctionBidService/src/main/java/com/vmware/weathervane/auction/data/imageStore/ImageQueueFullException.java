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
public class ImageQueueFullException extends Exception {

	public ImageQueueFullException() {
		super();
	}
	
	public ImageQueueFullException(String msg) {
		super(msg);
	}

}

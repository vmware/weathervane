/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.common.exceptions;

/**
 * @author Hal
 *
 */
public class DuplicateRunException extends RuntimeException {
	/**
	 * 
	 */
	private static final long serialVersionUID = 1L;

	public DuplicateRunException() {
		super();
	}
	
	public DuplicateRunException(String msg) {
		super(msg);
	}

}

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
public class OperationCancelledException extends RuntimeException {
	/**
	 * 
	 */
	private static final long serialVersionUID = 1L;

	public OperationCancelledException() {
		super();
	}
	
	public OperationCancelledException(String msg) {
		super(msg);
	}

}

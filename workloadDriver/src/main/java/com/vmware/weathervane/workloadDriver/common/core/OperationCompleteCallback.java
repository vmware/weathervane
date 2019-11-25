/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.common.core;

/**
 * This interface is used when registering a callback with an operation to be
 * called when the operation completes.
 * 
 * @author Hal
 * 
 */
public interface OperationCompleteCallback {
	void operationComplete();
	String getOperationCompleteCallbackName();
}

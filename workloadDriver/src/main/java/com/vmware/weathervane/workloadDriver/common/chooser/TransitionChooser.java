/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.chooser;

import com.vmware.weathervane.workloadDriver.common.core.Behavior;

/**
 * A TransitionChooser provides methods that help control both the path of operation
 * execution, and the selection of data to use when an operation executes.
 * 
 * @author hrosenbe
 *
 */
public interface TransitionChooser {

	/**
	 * This method is used by a Behavior's operationComplete method to 
	 * select which of the lastOperation's transition matrices to use when selecting
	 * the next operation.
	 * 
	 * @return The index of transition matrix to use when selecting next state
	 */
	public TransitionChooserResponse chooseTransition();
	
	/**
	 * Set the behavior for this transition chooser
	 * @param behavior
	 */
	public void setBehavior(Behavior behavior);
	
}

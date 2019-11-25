/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.common.chooser;

import java.util.Random;

import com.vmware.weathervane.workloadDriver.common.core.Behavior;

/**
 * 
 * The DefaultTransitionDecision class always chooses transition matrix 0.
 * Use this TransitionDecision for operations with only one transition matrix. 
 * 
 * @author hrosenbe
 *
 */
public class DefaultTransitionChooser implements TransitionChooser {

	protected String _name;
	
	private Behavior _behavior;
	
	protected Random _random;
	
	public DefaultTransitionChooser(Random random) {
		_random = random;
		_name = "Default Transition Chooser";
	}
	
	public String getName() {
		return _name;
	}

	public void setName(String _name) {
		this._name = _name;
	}
	
	@Override
	public String toString() {
		return this.getName();
	}

	@Override
	public TransitionChooserResponse chooseTransition() {
		return new TransitionChooserResponse(0, null, null, null);
	}

	protected Behavior getBehavior() {
		return _behavior;
	}

	@Override
	public void setBehavior(Behavior _behavior) {
		this._behavior = _behavior;
	}

}

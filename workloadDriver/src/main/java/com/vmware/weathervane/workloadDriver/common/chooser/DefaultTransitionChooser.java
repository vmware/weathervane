/*
Copyright (c) 2017 VMware, Inc. All Rights Reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
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

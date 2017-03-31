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
package com.vmware.weathervane.workloadDriver.common.chooser;

import java.util.List;
import java.util.UUID;

public class TransitionChooserResponse {

	int _chosenTransitionMatrix;
	List<UUID> _behaviorsToStopAtStart;
	List<UUID> _behaviorsToStopAtEnd;
	UUID _behaviorToUseAsDataSource;
	
	public TransitionChooserResponse(int chosenTransitionMatrix, List<UUID> behaviorsToStopAtStart,
			List<UUID> behaviorsToStopAtEnd, UUID behaviorToUseAsDataSource) {
		_chosenTransitionMatrix = chosenTransitionMatrix;
		_behaviorsToStopAtStart = behaviorsToStopAtStart;
		_behaviorsToStopAtEnd = behaviorsToStopAtEnd;
		_behaviorToUseAsDataSource = behaviorToUseAsDataSource;
	}
	
	public int getChosenTransitionMatrix() {
		return _chosenTransitionMatrix;
	}
	public void setChosenTransitionMatrix(int chosenTransitionMatrix) {
		this._chosenTransitionMatrix = chosenTransitionMatrix;
	}
	public List<UUID> getBehaviorsToStopAtStart() {
		return _behaviorsToStopAtStart;
	}

	public void setBehaviorsToStopAtStart(List<UUID> _behaviorsToStopAtStart) {
		this._behaviorsToStopAtStart = _behaviorsToStopAtStart;
	}

	public List<UUID> getBehaviorsToStopAtEnd() {
		return _behaviorsToStopAtEnd;
	}

	public void setBehaviorsToStopAtEnd(List<UUID> _behaviorsToStopAtEnd) {
		this._behaviorsToStopAtEnd = _behaviorsToStopAtEnd;
	}

	public UUID getBehaviorToUseAsDataSource() {
		return _behaviorToUseAsDataSource;
	}
	public void setBehaviorToUseAsDataSource(UUID behaviorToUseAsDataSource) {
		this._behaviorToUseAsDataSource = behaviorToUseAsDataSource;
	}

}

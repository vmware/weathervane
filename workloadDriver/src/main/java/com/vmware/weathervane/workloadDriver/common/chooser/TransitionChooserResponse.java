/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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

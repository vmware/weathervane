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
package com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers;

import java.util.List;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AvailableAsyncIdsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAvailableAsyncIds;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.common.chooser.DefaultTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooserResponse;

/**
 * 
 * 
 * @author hrosenbe
 * 
 */
public class OtherLogoutJoinTransitionChooser extends DefaultTransitionChooser implements NeedsActiveAuctions,
		NeedsAvailableAsyncIds {

	private static final Logger logger = LoggerFactory.getLogger(OtherLogoutJoinTransitionChooser.class);

	private ActiveAuctionProvider _liveAuctionProvider;
	private AvailableAsyncIdsProvider _availableAsyncIdsProvider;

	public OtherLogoutJoinTransitionChooser(Random random) {
		super(random);
		this._name = "Other-Logout-Join Transition Chooser";
	}

	@Override
	public TransitionChooserResponse chooseTransition() {
		UUID behaviorToUseAsDataSource = null;
		int selectedTransitionMatrix = 0;
		List<UUID> behaviorsToStopAtEnd = null;
		List<UUID> behaviorsToStopAtStart = null;

		List<UUID> activeSubBehaviors = getBehavior().getActiveSubBehaviors();
		logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() 
				+ " number of active subBehaviors =  " + activeSubBehaviors.size() + ", subbehaviorIDs: "
				+ getBehavior().getActiveSubBehaviorIdsString());

		/*
		 * Return 1 if there are no active auctions (Logout), Return 2 if not already
		 * attending the maximum, else return 0
		 */
		List<AuctionRepresentation> activeAuctions = _liveAuctionProvider.getActiveAuctions();
		if ((activeAuctions == null) || (activeAuctions.size() == 0)) {
			logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId()
					+ " Returning 1. Logout because there are no active auctions");
			selectedTransitionMatrix = 1;
		} else if (!_availableAsyncIdsProvider.isEmpty()) {
			/*
			 * Not attending max number of auctions. Join an auction
			 */
			selectedTransitionMatrix = 2;
		} else {
			logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() + " Returning 1.");
			selectedTransitionMatrix = 1;
		}

		TransitionChooserResponse response = new TransitionChooserResponse(selectedTransitionMatrix, behaviorsToStopAtStart, behaviorsToStopAtEnd, behaviorToUseAsDataSource);
		
		return response;
	}

	@Override
	public void registerAvailableAsyncIdsProvider(AvailableAsyncIdsProvider provider) {
		_availableAsyncIdsProvider = provider;
	}

	@Override
	public void registerActiveAuctionProvider(ActiveAuctionProvider provider) {
		logger.debug("registerActiveAuctionProvider");
		_liveAuctionProvider = provider;
	}

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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
			logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() + " Returning 2.");
			selectedTransitionMatrix = 2;
		} else {
			logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() + " Returning 0.");
			selectedTransitionMatrix = 0;
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

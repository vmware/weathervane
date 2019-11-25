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

import java.util.Random;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.common.chooser.DefaultTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooserResponse;

/**
 * 
 * 
 * @author hrosenbe
 *
 */
public class GetNextBidTransitionChooser extends DefaultTransitionChooser implements NeedsCurrentBid {

	private static final Logger logger = LoggerFactory.getLogger(GetNextBidTransitionChooser.class);

	private CurrentBidProvider _currentBidProvider;

	public GetNextBidTransitionChooser(Random random) {
		super(random);
		this._name = "Get Next Bid Transition Chooser";
	}
	
	@Override
	public TransitionChooserResponse chooseTransition() {
		// Choose the next transition Matrix
		int selectedTransitionMatrix = 2;

		// Get the bidding state from the current bid
		BidRepresentation currentBid = _currentBidProvider.getResponse();

		if (currentBid == null) {
			selectedTransitionMatrix = 2;
		} else {

			String biddingState = currentBid.getBiddingState().toString();

			if ((biddingState.equals("AUCTIONCOMPLETE"))
					|| (biddingState.equals("AUCTIONNOTACTIVE"))) {
				logger.debug("Auction " + currentBid.getAuctionId() + " is in state " + biddingState 
								+ " in chooseTransition for behavior " + getBehavior().getBehaviorId());
				selectedTransitionMatrix = 2;
			} else if (biddingState.equals("OPEN") || biddingState.equals("LASTCALL")) {
				selectedTransitionMatrix = 0;
			} else if (biddingState.equals("SOLD") || biddingState.equals("INFO")
					|| biddingState.equals("ITEMNOTACTIVE")) {
				selectedTransitionMatrix = 1;
			}
		}
		return new TransitionChooserResponse(selectedTransitionMatrix, null, null, null);
	}

	
	@Override
	public void registerCurrentBidProvider(CurrentBidProvider provider) {
		_currentBidProvider = provider;
	}

}

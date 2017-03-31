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

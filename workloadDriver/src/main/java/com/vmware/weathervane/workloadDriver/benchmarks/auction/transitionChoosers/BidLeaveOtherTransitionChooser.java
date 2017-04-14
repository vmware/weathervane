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

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionIdToLeaveListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAuctionIdToLeave;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsBidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBids;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.ItemRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.UserRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.BidStrategy;
import com.vmware.weathervane.workloadDriver.common.chooser.DefaultTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooserResponse;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.XHolderProvider;
import com.vmware.weathervane.workloadDriver.common.util.ResponseHolder;

/**
 * 
 * 
 * @author hrosenbe
 * 
 */
public class BidLeaveOtherTransitionChooser extends DefaultTransitionChooser implements NeedsCurrentBids,
		NeedsUserProfile, NeedsBidStrategy, NeedsCurrentItems, ContainsAuctionIdToLeave {

	private static final Logger logger = LoggerFactory.getLogger(BidLeaveOtherTransitionChooser.class);

	private CurrentBidsProvider _currentBidsProvider;
	private CurrentItemsProvider _currentItemsProvider;
	private UserProfileProvider _currentUserProfileProvider;
	private AuctionIdToLeaveListener _auctionIdToLeaveListener;
	
	private XHolderProvider<BidStrategy> _bidStrategyProvider;

	public BidLeaveOtherTransitionChooser(Random random) {
		super(random);
		this._name = "Bid-Leave-Other Transition Chooser";
	}

	/**
	 * The decision of which transition matrix to use is made as follows: - If
	 * any auction has ended, go to leaveAuction (return 1) - If any auction has
	 * bid state open or lastcall, and bidstrategy says bid, return 0 -
	 * otherwise, return 2
	 */
	@Override
	public TransitionChooserResponse chooseTransition() {
		 UUID behaviorToUseAsDataSource = null;
		 UUID behaviorToStopAtStart = null;
		int selectedTransitionMatrix = 0;
		List<UUID> behaviorsToStopAtEnd = null;
		List<UUID> behaviorsToStopAtStart = null;
		
		UserRepresentation userProfileRepresentation = _currentUserProfileProvider.getResponse();

		float creditLimit = userProfileRepresentation.getCreditLimit();
		String userId = userProfileRepresentation.getId().toString();

		boolean shouldBid = false;
		ItemRepresentation currentItem = null;
		BidRepresentation currentBid = null;

		List<UUID> activeSubBehaviors = getBehavior().getActiveSubBehaviors();
		
		/*
		 * Need to randomly order the list of attended auctions so 
		 * that all auctions have an equal chance of being bid on.
		 */
		List<UUID> randomizedUUIDs = new ArrayList<UUID>(activeSubBehaviors.size());
		for (UUID id : activeSubBehaviors) {
			randomizedUUIDs.add(id);
		}
		Collections.shuffle(randomizedUUIDs);
		
		for (UUID key : randomizedUUIDs) {

			ResponseHolder<String, BidRepresentation> currentBidHolder = _currentBidsProvider.getBidHolderForBehavior(key);
			currentBid = currentBidHolder.getParsedResponse();

			ResponseHolder<String, ItemRepresentation> currentItemHolder = _currentItemsProvider.getItemHolderForBehavior(key);
			currentItem = currentItemHolder.getParsedResponse();

			if ((currentBid == null) || (currentItem == null) || (currentBid.getUserId() == null)) {
				continue;
			}
			
			String bidderUserId = currentBid.getUserId().toString();
			double amount = currentBid.getAmount();
			String biddingState = currentBid.getBiddingState().name();
			String itemName = currentItem.getName();
			long auctionId = currentBid.getAuctionId();

			if (biddingState.equals("AUCTIONCOMPLETE") || biddingState.equals("AUCTIONNOTACTIVE")) {
				behaviorToStopAtStart = key;
				behaviorToUseAsDataSource = null;
				_auctionIdToLeaveListener.setAuctionIdToLeave(auctionId);
				break;
			} else {
				boolean strategyShouldBid = _bidStrategyProvider.getItem("bidStrategy").shouldBid(
						itemName, amount, creditLimit);
				if (!shouldBid && (biddingState.equals("LASTCALL") || biddingState.equals("OPEN"))
						&& (strategyShouldBid && !userId.equals(bidderUserId))) {
					shouldBid = true;
					behaviorToUseAsDataSource = key;
					break;
				}
			}
		}

		if (behaviorToStopAtStart != null) {
			logger.debug("chooseTransitionMatrix: Returning 1. Leaving auction that has completed.  Stopping BehaviorId = " + behaviorToStopAtStart);
			behaviorsToStopAtStart = new ArrayList<UUID>();
			behaviorsToStopAtStart.add(behaviorToStopAtStart);
			selectedTransitionMatrix = 1;
		} else if (shouldBid) {
			logger.debug("chooseTransitionMatrix: Returning 0. Should bid.  _toBidAsyncId = " + behaviorToUseAsDataSource);
			selectedTransitionMatrix = 0;
		} else {
			logger.debug("chooseTransitionMatrix: Returning 2. ");
			selectedTransitionMatrix = 2;
		}
				
		TransitionChooserResponse response = new TransitionChooserResponse(selectedTransitionMatrix, behaviorsToStopAtStart, behaviorsToStopAtEnd, behaviorToUseAsDataSource);
		
		return response;
	}

	@Override
	public void registerCurrentBidsProvider(CurrentBidsProvider provider) {
		_currentBidsProvider = provider;
	}

	@Override
	public void registerUserProfileProvider(UserProfileProvider provider) {
		_currentUserProfileProvider = provider;
	}

	@Override
	public void registerBidStrategyProvider(XHolderProvider<BidStrategy> provider) {
		_bidStrategyProvider = provider;
	}

	@Override
	public void registerCurrentItemsProvider(CurrentItemsProvider provider) {
		_currentItemsProvider = provider;
	}

	@Override
	public void registerAuctionIdToLeaveListener(AuctionIdToLeaveListener listener) {
		_auctionIdToLeaveListener = listener;
	}

	@Override
	public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig() {
		return null;
	}

}

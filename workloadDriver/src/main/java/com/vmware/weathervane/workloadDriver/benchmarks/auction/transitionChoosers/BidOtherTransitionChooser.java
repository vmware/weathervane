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

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

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
public class BidOtherTransitionChooser extends DefaultTransitionChooser implements NeedsCurrentBids,
		NeedsUserProfile, NeedsBidStrategy, NeedsCurrentItems {

	private static final Logger logger = LoggerFactory.getLogger(BidOtherTransitionChooser.class);

	private CurrentBidsProvider _currentBidsProvider;
	private CurrentItemsProvider _currentItemsProvider;
	private UserProfileProvider _currentUserProfileProvider;
	
	private XHolderProvider<BidStrategy> _bidStrategyProvider;

	public BidOtherTransitionChooser(Random random) {
		super(random);
		this._name = "Bid-Other Transition Chooser";
	}

	/**
	 * The decision of which transition matrix to use is made as follows: 
	 * - If any auction has bid state open or lastcall, and bidstrategy says bid, return 0 
	 * - otherwise, return 2
	 */
	@Override
	public TransitionChooserResponse chooseTransition() {
		 UUID behaviorToUseAsDataSource = null;
		int selectedTransitionMatrix = 0;
		
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

			boolean strategyShouldBid = _bidStrategyProvider.getItem("bidStrategy").shouldBid(
					itemName, amount, creditLimit);
			if ((biddingState.equals("LASTCALL") || biddingState.equals("OPEN"))
					&& (strategyShouldBid && !userId.equals(bidderUserId))) {
				shouldBid = true;
				behaviorToUseAsDataSource = key;
				break;
			}
			
		}

		if (shouldBid) {
			logger.debug("chooseTransitionMatrix: Returning 0. Should bid.  _toBidAsyncId = " + behaviorToUseAsDataSource);
			selectedTransitionMatrix = 0;
		} else {
			logger.debug("chooseTransitionMatrix: Returning 1. ");
			selectedTransitionMatrix = 1;
		}
				
		TransitionChooserResponse response = new TransitionChooserResponse(selectedTransitionMatrix, null, null, behaviorToUseAsDataSource);
		
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

}

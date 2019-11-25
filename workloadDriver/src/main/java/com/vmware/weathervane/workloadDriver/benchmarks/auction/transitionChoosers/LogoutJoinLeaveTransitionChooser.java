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
import java.util.List;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionIdToLeaveListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AvailableAsyncIdsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAuctionIdToLeave;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAvailableAsyncIds;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBids;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.common.chooser.DefaultTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooserResponse;
import com.vmware.weathervane.workloadDriver.common.util.ResponseHolder;

/**
 * 
 * 
 * @author hrosenbe
 * 
 */
public class LogoutJoinLeaveTransitionChooser extends DefaultTransitionChooser implements NeedsCurrentBids, NeedsActiveAuctions,
		NeedsAvailableAsyncIds, ContainsAuctionIdToLeave {

	private static final Logger logger = LoggerFactory.getLogger(LogoutJoinLeaveTransitionChooser.class);

	private CurrentBidsProvider _currentBidsProvider;
	private ActiveAuctionProvider _liveAuctionProvider;
	private AvailableAsyncIdsProvider _availableAsyncIdsProvider;
	private AuctionIdToLeaveListener _auctionIdToLeaveListener;

	public LogoutJoinLeaveTransitionChooser(Random random) {
		super(random);
		this._name = "Logout-Join-Leave Transition Chooser";
	}

	@Override
	public TransitionChooserResponse chooseTransition() {
		UUID behaviorToUseAsDataSource = null;
		int selectedTransitionMatrix = 0;
		List<UUID> behaviorsToStopAtEnd = null;
		List<UUID> behaviorsToStopAtStart = null;

		BidRepresentation currentBid = null;
		
		/*
		 * Check whether any auction has ended.  If so, then leave it. 
		 */
		List<UUID> activeSubBehaviors = getBehavior().getActiveSubBehaviors();
		logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() 
				+ " number of active subBehaviors =  " + activeSubBehaviors.size() + ", subbehaviorIDs: "
				+ getBehavior().getActiveSubBehaviorIdsString());

		for (UUID key : activeSubBehaviors) {
			ResponseHolder<String, BidRepresentation> currentBidHolder = _currentBidsProvider.getBidHolderForBehavior(key);
			currentBid = currentBidHolder.getParsedResponse();

			if ((currentBid == null) || (currentBid.getBiddingState() == null)) {
				continue;
			}

			String biddingState = currentBid.getBiddingState().name();
			long auctionId = currentBid.getAuctionId();

			if (biddingState.equals("AUCTIONCOMPLETE") || biddingState.equals("AUCTIONNOTACTIVE")) {
				behaviorsToStopAtStart = new ArrayList<UUID>();
				behaviorsToStopAtStart.add(key);
				_auctionIdToLeaveListener.setAuctionIdToLeave(auctionId);
				behaviorToUseAsDataSource = null;
				logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() 
						+ " Returning 2. Leaving auction that has completed.  Stopping BehaviorId = "
						+ key);

				break;
			}
		}

		if (behaviorsToStopAtStart != null) {
			selectedTransitionMatrix = 2;
		} else {
			/*
			 * Return 0 if there are no active auctions (Logout), Return 2 if
			 * already attending the maximum (Leave one of them), else return 1
			 */
			List<AuctionRepresentation> activeAuctions = _liveAuctionProvider.getActiveAuctions();
			if ((activeAuctions == null)
					|| (activeAuctions.size() == 0)) {
				logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() 
					+ " Returning 0. Logout because there are no active auctions");
				selectedTransitionMatrix = 0;
			} else if ((_availableAsyncIdsProvider.isEmpty()) && (activeSubBehaviors.size() > 0)) {
				/*
				 *  Attending max number of auctions. Pick an auction to leave
				 */
				int subbehaviorToLeave = _random.nextInt(activeSubBehaviors.size());
				UUID id = activeSubBehaviors.get(subbehaviorToLeave);
				behaviorsToStopAtStart = new ArrayList<UUID>();
				behaviorsToStopAtStart.add(id);

				ResponseHolder<String, BidRepresentation> currentBidHolder = _currentBidsProvider.getBidHolderForBehavior(id);
				try {
					currentBid = currentBidHolder.getParsedResponse();
					Long auctionId = currentBid.getAuctionId();
					_auctionIdToLeaveListener.setAuctionIdToLeave(auctionId);

					selectedTransitionMatrix = 2;
					logger.debug("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() + " Returning 2. Leaving auction  " + auctionId
							+ " because attending max. Stopping BehaviorId = " + id);
				} catch (NullPointerException e) {
					logger.warn("chooseTransitionMatrix for behavior " + getBehavior().getBehaviorId() + " Returning 0 due to nullPointerExcept when coosing auction to leave");
					selectedTransitionMatrix = 0;					
				}
			} else {
				logger.debug("chooseTransitionMatrix for behavior "
							+ getBehavior().getBehaviorId() + " Returning 1.");
				selectedTransitionMatrix = 1;
			}
		}

		TransitionChooserResponse response = new TransitionChooserResponse(selectedTransitionMatrix, behaviorsToStopAtStart, behaviorsToStopAtEnd, behaviorToUseAsDataSource);
		
		return response;
	}

	@Override
	public void registerCurrentBidsProvider(CurrentBidsProvider provider) {
		_currentBidsProvider = provider;
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

	@Override
	public void registerAuctionIdToLeaveListener(AuctionIdToLeaveListener listener) {
		_auctionIdToLeaveListener = listener;
	}

	@Override
	public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig() {
		return null;
	}


}

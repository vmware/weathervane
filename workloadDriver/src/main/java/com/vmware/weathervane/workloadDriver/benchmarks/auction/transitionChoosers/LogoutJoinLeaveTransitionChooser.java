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

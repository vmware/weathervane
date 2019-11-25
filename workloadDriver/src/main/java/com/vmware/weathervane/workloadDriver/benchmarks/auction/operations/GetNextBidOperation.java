/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.operations;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.BidRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.ItemRepresentation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.UserRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.exceptions.OperationFailedException;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetNextBidOperation extends AuctionOperation implements NeedsLoginResponse, NeedsCurrentAuction, NeedsCurrentItem,
		NeedsCurrentBid, ContainsCurrentBid, NeedsUserProfile {

	private LoginResponseProvider _loginResponseProvider;
	private CurrentAuctionProvider _currentAuctionProvider;
	private CurrentItemProvider _currentItemProvider;
	private CurrentBidListener _currentBidListener;
	private CurrentBidProvider _currentBidProvider;
	private UserProfileProvider _currentUserProfileProvider;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetNextBidOperation.class);

	public GetNextBidOperation( User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetNextBid";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			initialStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("GetNextBidOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void initialStep() throws Throwable {
		AuctionRepresentation theAuction = _currentAuctionProvider.getResponse();
		String auctionId = theAuction.getId().toString();
		_bindVarsMap.put("auctionId", auctionId);
		
		logger.info("getNextBidOperation initialStep getting current bid for behaviorID = " + this.getBehaviorId());
		ItemRepresentation currentItem = _currentItemProvider.getResponse();
		Long currentItemId = currentItem.getId();
		String itemId = currentItemId.toString();
		_bindVarsMap.put("itemId", itemId);

		BidRepresentation currentBid = null;
		try {
			currentBid = _currentBidProvider.getResponse();
			if ((currentBid == null) || (currentBid.getLastBidCount() == null)) {
				throw new OperationFailedException("Incomplete response received when retrieving current bid for auction " + auctionId);
			}
		} catch (NullPointerException e) {
			throw new OperationFailedException("Incomplete response received when retrieving current bid for auction " + auctionId);
		}
		String bidCount = currentBid.getLastBidCount().toString();
		_bindVarsMap.put("bidCount", bidCount);

		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("GetNextBidStep behaviorID = " + this.getBehaviorId());

		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentBidListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, new int[] { 408 }, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId());
		
		BidRepresentation currentBid = _currentBidProvider.getResponse();

		// Check for an error message in the bid, indicated by id==0.
		String bidId = currentBid.getId();
		if (bidId.equals("error")) {
			logger.warn("finalStep: nextBid reports an error.  message = " + currentBid.getMessage());
			throw new RuntimeException(currentBid.getMessage());
		}

		// If the current user had the winning bid for this item, we need to
		// update the available credit
		// limit in the userProfile
		UserRepresentation theUserProfile = _currentUserProfileProvider.getResponse();
		float creditLimit = theUserProfile.getCreditLimit();
		String userId = theUserProfile.getId().toString();
		String bidderUserId = currentBid.getUserId().toString();
		float amount = currentBid.getAmount();
		String biddingState = currentBid.getBiddingState().toString();
		
		if (biddingState.equals("SOLD") && userId.equals(bidderUserId)) {
			theUserProfile.setCreditLimit(creditLimit - amount);
		}

	}

	@Override
	public void registerCurrentAuctionProvider(CurrentAuctionProvider provider) {
		_currentAuctionProvider = provider;
	}

	@Override
	public void registerCurrentItemProvider(CurrentItemProvider provider) {
		_currentItemProvider = provider;
	}

	@Override
	public void registerCurrentBidListener(CurrentBidListener listener) {
		_currentBidListener = listener;
	}

	@Override
	public CurrentBidListenerConfig getCurrentBidListenerConfig() {
		return null;
	}

	@Override
	public void registerCurrentBidProvider(CurrentBidProvider provider) {
		_currentBidProvider = provider;
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerUserProfileProvider(UserProfileProvider provider) {
		_currentUserProfileProvider = provider;	
	}

}

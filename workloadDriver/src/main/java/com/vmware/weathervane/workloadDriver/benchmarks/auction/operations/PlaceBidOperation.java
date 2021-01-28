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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsBidStrategy;
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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.BidStrategy;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.XHolderProvider;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

public class PlaceBidOperation extends AuctionOperation implements NeedsLoginResponse, NeedsCurrentAuction, NeedsCurrentItem,
		NeedsCurrentBid, NeedsUserProfile, NeedsBidStrategy {

	private LoginResponseProvider _loginResponseProvider;
	private CurrentAuctionProvider _currentAuctionProvider;
	private CurrentItemProvider _currentItemProvider;
	private CurrentBidProvider _currentBidProvider;
	private UserProfileProvider _currentUserProfileProvider;
	private XHolderProvider<BidStrategy> _bidStrategyProvider;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Long _userId;

	private static final Logger logger = LoggerFactory.getLogger(PlaceBidOperation.class);

	public PlaceBidOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "PlaceBid";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_userId = _loginResponseProvider.getUserId();
			initialStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("PlaceBidOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void initialStep() throws Throwable {
		AuctionRepresentation theAuction = _currentAuctionProvider.getResponse();
		String auctionId = theAuction.getId().toString();

		ItemRepresentation currentItem = _currentItemProvider.getResponse();
		String itemId = currentItem.getId().toString();
		String itemName = currentItem.getName();

		BidRepresentation currentBid = _currentBidProvider.getResponse();
		double currentBidAmount = currentBid.getAmount();
		
		UserRepresentation theUser = _currentUserProfileProvider.getResponse();
		float creditLimit = theUser.getCreditLimit();

		BidStrategy bidStrategy = _bidStrategyProvider.getItem("bidStrategy");

		double myBidAmount = bidStrategy.bidAmount(itemName, currentBidAmount, creditLimit);

		SimpleUri uri = getOperationUri(UrlType.POST, 0);

		logger.debug("initialStep behaviorID = " + this.getBehaviorId());

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;
		Map<String, String> nameValuePairs = new HashMap<String, String>();
		nameValuePairs.put("amount", new Double(myBidAmount).toString());
		nameValuePairs.put("auctionId", auctionId);
		nameValuePairs.put("itemId", itemId);
		nameValuePairs.put("userId", _userId.toString());
		doHttpPostJson(uri, null, validResponseCodes, null, nameValuePairs, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId());

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
	public void registerBidStrategyProvider(XHolderProvider<BidStrategy> provider) {
		_bidStrategyProvider = provider;

	}

	@Override
	public void registerCurrentBidProvider(CurrentBidProvider provider) {
		_currentBidProvider = provider;
	}

	@Override
	public void registerUserProfileProvider(UserProfileProvider provider) {
		_currentUserProfileProvider = provider;
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

}

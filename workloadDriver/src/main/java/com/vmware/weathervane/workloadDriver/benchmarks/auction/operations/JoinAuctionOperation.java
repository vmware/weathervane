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
package com.vmware.weathervane.workloadDriver.benchmarks.auction.operations;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class JoinAuctionOperation extends AuctionOperation implements NeedsLoginResponse, NeedsActiveAuctions,
		ContainsCurrentAuction, ContainsCurrentItem, ContainsCurrentBid, NeedsAttendedAuctions,
		ContainsAttendedAuctions,  NeedsCurrentItem, NeedsCurrentBid {

	private ActiveAuctionProvider _activeAuctionProvider;
	private CurrentAuctionListener _currentAuctionListener;
	private CurrentItemListener _currentItemListener;
	private CurrentBidListener _currentBidListener;
	private AttendedAuctionsListener _attendedAuctionsListener;
	private AttendedAuctionsProvider _attendedAuctionsProvider;
	private LoginResponseProvider _loginResponseProvider;
	private CurrentItemProvider _currentItemProvider;
	private CurrentBidProvider _currentBidProvider;

	private Long _auctionId;
	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Long _userId;
	private List<String> _itemImageURLs;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(JoinAuctionOperation.class);

	public JoinAuctionOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "JoinAuction";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_authTokenHeaders.put("Accept", "application/json");
			_authTokenHeaders.put("Content-Type", "application/json");
			_userId = _loginResponseProvider.getUserId();
			joinAuctionStep();
			break;

		case 1:
			getAuctionDetailStep();
			break;

		case 2:
			getCurrentItemStep();
			break;

		case 3:
			getCurrentBidStep();
			break;

		case 4:
			logger.debug("Getting itemImage links from currentItemProvider");
			_itemImageURLs = _currentItemProvider.getItemImageLinks();
			if ((_itemImageURLs == null) || (_itemImageURLs.isEmpty())) {
				// No images.  Operation is finished
				logger.debug("No images for item.  _itemImageURLs = " + _itemImageURLs);
				finalStep();
				this.setOperationComplete(true);				
			} else {
				getItemThumbnailStep();
			}
			break;

		case 5:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("JoinAuctionOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void joinAuctionStep() throws Throwable {

		do {
			AuctionRepresentation anAuction = _activeAuctionProvider.getRandomActiveAuction();
			_auctionId = anAuction.getId();
			_bindVarsMap.put("auctionId", Long.toString(_auctionId));
			logger.debug("JoinAuctionOperation:initialStep behaviorID = " + this.getBehaviorId() + " Got AuctionId = " + _auctionId);
		} while (_attendedAuctionsProvider.contains(_auctionId));
		
		SimpleUri uri = getOperationUri(UrlType.POST, 0);

		logger.info("JoinAuctionOperation:initialStep behaviorID = " + this.getBehaviorId() 
				+ " joining auction " + _auctionId );

		int[] validResponseCodes = new int[] { 200 };
		int[] abortResponseCodes = new int[] { 410 };
		String[] mustContainText = null;
		
		Map<String, String> nameValuePairs = new HashMap<String, String>();
		nameValuePairs.put("userId", _userId.toString());
		nameValuePairs.put("auctionId", _auctionId.toString());
		doHttpPostJson(uri, null, validResponseCodes, abortResponseCodes, nameValuePairs, mustContainText, null, _authTokenHeaders);

	}

	public void getAuctionDetailStep() throws Throwable {

		_attendedAuctionsListener.addAttendedAuction(_auctionId);

		// Join auction must also get the current auction details, item, and bid
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("getAuctionDetailStep behaviorID = " + this.getBehaviorId() );

		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentAuctionListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, new int[] { 410 }, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}

	public void getCurrentItemStep() throws Throwable {

		// Join auction must also get the current item and bid for the auction
		SimpleUri uri = getOperationUri(UrlType.GET, 1);

		logger.info("getCurrentItemStep behaviorID = " + this.getBehaviorId());

		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentItemListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, new int[] { 410 }, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}

	public void getCurrentBidStep() throws Throwable {

		String itemId = _currentItemProvider.getId().toString();
		_bindVarsMap.put("itemId", itemId);

		// getting the next bid with a count of 0 always returns the most recent
		// bid.
		SimpleUri uri = getOperationUri(UrlType.GET, 2);

		logger.debug("getCurrentBidStep behaviorID = " + this.getBehaviorId());

		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentBidListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, new int[] { 410 }, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}
	

	public void getItemThumbnailStep() throws Throwable {

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;

		String imageUrl = _itemImageURLs.get(0);
		_bindVarsMap.put("imageUrl", imageUrl);
		_bindVarsMap.put("size", "THUMBNAIL");
		
		SimpleUri uri = getOperationUri(UrlType.GET, 3);
		
		logger.debug("getItemThumbnailStep: behaviorID = " + this.getBehaviorId() );
		_authTokenHeaders.put("Accept", "text/plain");

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {

		logger.debug("JoinAuctionOperation:finalStep behaviorID = " + this.getBehaviorId());

		String bidId = _currentBidProvider.getBidId();
		if (bidId.equals("error")) {
			throw new RuntimeException(_currentBidProvider.getMessage());
		}

	}

	@Override
	public void registerActiveAuctionProvider(ActiveAuctionProvider provider) {
		_activeAuctionProvider = provider;
	}

	@Override
	public void registerCurrentAuctionListener(CurrentAuctionListener listener) {
		_currentAuctionListener = listener;
	}

	@Override
	public CurrentAuctionListenerConfig getCurrentAuctionListenerConfig() {
		return null;
	}

	@Override
	public void registerCurrentItemListener(CurrentItemListener listener) {
		_currentItemListener = listener;
	}

	@Override
	public CurrentItemListenerConfig getCurrentItemListenerConfig() {
		return null;
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
	public void registerAttendedAuctionsListener(AttendedAuctionsListener listener) {
		_attendedAuctionsListener = listener;
	}

	@Override
	public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig() {
		return null;
	}

	@Override
	public void registerAttendedAuctionsProvider(AttendedAuctionsProvider provider) {
		_attendedAuctionsProvider = provider;
	}
	
	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerCurrentItemProvider(CurrentItemProvider provider) {
		_currentItemProvider = provider;
	}

	@Override
	public void registerCurrentBidProvider(CurrentBidProvider provider) {
		_currentBidProvider = provider;
	}

}

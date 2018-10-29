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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentBid;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentBidListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.CurrentItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsCurrentItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetCurrentItemOperation extends AuctionOperation implements NeedsLoginResponse, NeedsCurrentAuction,
		ContainsCurrentItem, ContainsCurrentBid, NeedsCurrentItem {

	private LoginResponseProvider _loginResponseProvider;
	private CurrentAuctionProvider _currentAuctionProvider;
	private CurrentItemListener _currentItemListener;
	private CurrentBidListener _currentBidListener;
	private CurrentItemProvider _currentItemProvider;

	String _auctionId;
	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private List<String> _itemImageURLs;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetCurrentItemOperation.class);

	public GetCurrentItemOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetCurrentItem";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			getCurrentItemStep();
			break;

		case 1:
			getCurrentBidStep();
			break;

		case 2:
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

		case 3:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("GetCurrentItemOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void getCurrentItemStep() throws Throwable {
		// ToDo: Need to put index and key someplace separate
		AuctionRepresentation theAuction = _currentAuctionProvider.getResponse();
		_auctionId = theAuction.getId().toString();
		_bindVarsMap.put("auctionId", _auctionId);

//		System.out.println("gci, " 
//				+ getUser().getTarget().getNumActiveUsers() + ", "
//				+ getUser().getOrderingId() + ", "
//				+ getUser().getGlobalOrderingId() + ", "
//				+ getUser().getUserName() + ", "
//				+ _auctionId 
//				);

		// Join auction must also get the current item and bid for the auction
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.info("getCurrentItemStep behaviorID = " + this.getBehaviorId() 
			+ ", User orderingId = " + this.getUser().getOrderingId());

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
		SimpleUri uri = getOperationUri(UrlType.GET, 1);

		logger.debug("getCurrentBidStep behaviorID = " + this.getBehaviorId() 
			+ ", User orderingId = " + this.getUser().getOrderingId());


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
		SimpleUri uri = getOperationUri(UrlType.GET, 2);

		logger.debug("getItemThumbnailStep behaviorID = " + this.getBehaviorId()
			+ ", User orderingId = " + this.getUser().getOrderingId());

		_authTokenHeaders.put("Accept", "text/plain");
		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("GetCurrentItemOperation:finalStep behaviorID = " + this.getBehaviorId()
			+ ", User orderingId = " + this.getUser().getOrderingId());

	}

	@Override
	public void registerCurrentAuctionProvider(CurrentAuctionProvider provider) {
		_currentAuctionProvider = provider;
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
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerCurrentItemProvider(CurrentItemProvider provider) {
		_currentItemProvider = provider;
	}


}

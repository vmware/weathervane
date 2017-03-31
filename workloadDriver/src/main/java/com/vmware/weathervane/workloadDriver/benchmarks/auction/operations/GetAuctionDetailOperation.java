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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAuctionItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAuctionItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetAuctionDetailOperation extends AuctionOperation implements NeedsLoginResponse, 
	NeedsActiveAuctions, ContainsAuctionItems, NeedsAuctionItems, NeedsPageSize {

	private LoginResponseProvider _loginResponsenProvider;
	private PageSizeProvider _pageSizeProvider;

	private ActiveAuctionProvider _activeAuctionProvider;
	private AuctionItemsListener _auctionItemsListener;
	private AuctionItemsProvider _auctionItemsProvider;
	
	private String _auctionId;
	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private List<String> _itemThumbnailURLs;
	private long _pageSize;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(JoinAuctionOperation.class);

	public GetAuctionDetailOperation( User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetAuctionDetail";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponsenProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_pageSize = _pageSizeProvider.getItem("pageSize");
			_bindVarsMap.put("pageSize", Long.toString(_pageSize));

			getAuctionDetailStep();
			break;

		case 1:
			getItemListStep();
			break;

		case 2:
			_itemThumbnailURLs = _auctionItemsProvider.getItemThumbnailLinks();
			if ((_itemThumbnailURLs == null) || (_itemThumbnailURLs.isEmpty())) {
				// No images.  Operation is finished
				logger.debug("No images for items.  _itemThumbnailURLs = " + _itemThumbnailURLs);
				finalStep();
				this.setOperationComplete(true);				
			} else {
				getItemThumbnailsStep();
			}
			break;

		case 3:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("GetAuctionDetailOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}


	public void getAuctionDetailStep() throws Throwable {
		AuctionRepresentation anAuction = _activeAuctionProvider.getRandomActiveAuction();
		_auctionId = anAuction.getId().toString();
		_bindVarsMap.put("auctionId", _auctionId);

		// Get the current auction details
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("getAuctionDetailStep behaviorID = " + this.getBehaviorId());

		String[] mustContainText = null;
		DataListener[] dataListeners = null;
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, null, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}

	public void getItemListStep() throws Throwable {

		// Join auction must also get the current item and bid for the auction
		SimpleUri uri = getOperationUri(UrlType.GET, 1);

		logger.debug("getItemListStep behaviorID = " + this.getBehaviorId());

		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _auctionItemsListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, new int[] { 200 }, null, false, true, mustContainText, dataListeners, _authTokenHeaders);

	}	

	public void getItemThumbnailsStep() throws Throwable {

		logger.debug("getItemThumbnailsStep: behaviorID = " + this.getBehaviorId() + " getting " + _itemThumbnailURLs.size() + " thumbnails.");
		_authTokenHeaders.put("Accept", "text/plain");
		_authTokenHeaders.put("Accept-Language", "en-us,en;q=0.5");

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;

		int numUrls = _itemThumbnailURLs.size();
		
		this.setGetRequestsOutstanding(numUrls);

		for (int i = 0; i < numUrls; i++) {

			_bindVarsMap.put("imageUrl", _itemThumbnailURLs.get(i));
			_bindVarsMap.put("size", "THUMBNAIL");
			SimpleUri uri = getOperationUri(UrlType.GET, 2);
			logger.debug("getItemThumbnailsStep: behaviorID = " + this.getBehaviorId());

			doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText,
					dataListeners, _authTokenHeaders);
		}
	}

	protected void finalStep() throws Throwable {

		logger.debug("finalStep behaviorID = " + this.getBehaviorId());
	}

	@Override
	public void registerActiveAuctionProvider(ActiveAuctionProvider provider) {
		_activeAuctionProvider = provider;
	}

	
	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponsenProvider = provider;
	}

	@Override
	public void registerPageSizeProvider(PageSizeProvider provider) {
		_pageSizeProvider = provider;
	}

	@Override
	public void registerAuctionItemsProvider(AuctionItemsProvider provider) {
		_auctionItemsProvider = provider;
	}

	@Override
	public void registerAuctionItemsListener(AuctionItemsListener listener) {
		_auctionItemsListener = listener;
	}

}

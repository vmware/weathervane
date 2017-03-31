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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsPurchaseHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPurchaseHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PurchaseHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PurchaseHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetPurchaseHistoryOperation extends AuctionOperation implements NeedsLoginResponse,
		NeedsPageSize, ContainsPurchaseHistoryInfo, NeedsPurchaseHistoryInfo {

	private LoginResponseProvider _loginResponseProvider;
	private PageSizeProvider _pageSizeProvider;

	private PurchaseHistoryInfoProvider _purchaseHistoryInfoProvider;
	private PurchaseHistoryInfoListener _purchaseHistoryInfoListener;

	private List<String> _itemThumbnailURLs;
	private String _authToken;
	private long _pageSize;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private long _currentPurchaseHistoryPage;
	private Long _userId;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetPurchaseHistoryOperation.class);

	public GetPurchaseHistoryOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetPurchaseHistory";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_pageSize = _pageSizeProvider.getItem("pageSize");
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_currentPurchaseHistoryPage = _purchaseHistoryInfoProvider.getCurrentPurchaseHistoryPage();
			_userId = _loginResponseProvider.getUserId();
			
			_bindVarsMap.put("userId", Long.toString(_userId));
			_bindVarsMap.put("pageSize", Long.toString(_pageSize));
			getPurchaseHistoryStep();
			break;


		case 1:
			_itemThumbnailURLs = _purchaseHistoryInfoProvider.getItemThumbnailLinks();
			if ((_itemThumbnailURLs == null) || (_itemThumbnailURLs.isEmpty())) {
				// No images.  Operation is finished
				logger.debug("No images for items.  _itemThumbnailURLs = " + _itemThumbnailURLs);
				finalStep();
				this.setOperationComplete(true);				
			} else {
				getItemThumbnailsStep();
			}
			break;

		case 2:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"GetPurchaseHistoryOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void getPurchaseHistoryStep() throws Throwable {
	
		/*
		 * Decide which page to get. It can be any random page, except that
		 * it cannot be the same as the last page retrieved. The
		 * totalPurchaseHistoryRecords provider handles this for us.
		 */
		long pageNumber = _purchaseHistoryInfoProvider.getRandomPurchaseHistoryRecordsPage(_pageSize, _currentPurchaseHistoryPage);
		_bindVarsMap.put("pageNumber", Long.toString(pageNumber));

		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _purchaseHistoryInfoListener };

		logger.debug("getPurchaseHistoryStep behaviorID = " + this.getBehaviorId() );
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

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
		_bindVarsMap.put("size", "THUMBNAIL");

		for (int i = 0; i < numUrls; i++) {
			Map<String, String> headers = new HashMap<String, String>(_authTokenHeaders);
			_bindVarsMap.put("imageUrl", _itemThumbnailURLs.get(i));
			SimpleUri uri = getOperationUri(UrlType.GET, 1);

			logger.debug("getItemThumbnailsStep: behaviorID = " + this.getBehaviorId());

			doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, headers);
		}
	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId()
				+ ". getPurchaseHistory response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerPurchaseHistoryInfoListener(
			PurchaseHistoryInfoListener listener) {
		_purchaseHistoryInfoListener = listener;
	}

	@Override
	public void registerPurchaseHistoryInfoProvider(
			PurchaseHistoryInfoProvider provider) {
		_purchaseHistoryInfoProvider = provider;
	}

	@Override
	public void registerPageSizeProvider(PageSizeProvider provider) {
		_pageSizeProvider = provider;
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

}

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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.BidHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.BidHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsBidHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsBidHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetBidHistoryOperation extends AuctionOperation implements NeedsLoginResponse,
		NeedsPageSize, NeedsBidHistoryInfo, ContainsBidHistoryInfo {

	private LoginResponseProvider _loginResponseProvider;
	private PageSizeProvider _pageSizeProvider;
	
	private BidHistoryInfoProvider _bidHistoryInfoProvider;
	private BidHistoryInfoListener _bidHistoryInfoListener;

	private String _authToken;
	private long _pageSize;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private long _currentBidHistoryPage;
	private Long _userId;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetBidHistoryOperation.class);

	public GetBidHistoryOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetBidHistory";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_pageSize = _pageSizeProvider.getItem("pageSize");
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_currentBidHistoryPage = _bidHistoryInfoProvider.getCurrentBidHistoryPage();
			_userId = _loginResponseProvider.getUserId();
			_bindVarsMap.put("userId", Long.toString(_userId));
			_bindVarsMap.put("pageSize", Long.toString(_pageSize));

			getBidHistoryStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"GetBidHistoryOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void getBidHistoryStep() throws Throwable {
	
		/*
		 * Decide which page to get. It can be any random page, except that
		 * it cannot be the same as the last page retrieved. The
		 * totalBidHistoryRecords provider handles this for us.
		 */
		long pageNumber = _bidHistoryInfoProvider.getRandomBidHistoryRecordsPage(_pageSize, _currentBidHistoryPage);
		_bindVarsMap.put("pageNumber", Long.toString(pageNumber));

		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _bidHistoryInfoListener};
		_authTokenHeaders.put("Accept", "application/json");

		logger.debug("getBidHistoryStep behaviorID = " + this.getBehaviorId());

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId()
				+ ". getBidHistory response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerBidHistoryInfoListener(
			BidHistoryInfoListener listener) {
		_bidHistoryInfoListener = listener;
	}

	@Override
	public void registerBidHistoryInfoProvider(
			BidHistoryInfoProvider provider) {
		_bidHistoryInfoProvider = provider;
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

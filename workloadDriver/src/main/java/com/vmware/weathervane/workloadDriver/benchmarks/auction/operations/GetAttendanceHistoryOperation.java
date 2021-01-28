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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendanceHistoryInfoListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendanceHistoryInfoProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAttendanceHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAttendanceHistoryInfo;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

public class GetAttendanceHistoryOperation extends AuctionOperation implements NeedsLoginResponse,
		NeedsPageSize, NeedsAttendanceHistoryInfo, ContainsAttendanceHistoryInfo {

	private LoginResponseProvider _loginResponseProvider;
	private PageSizeProvider _pageSizeProvider;
	
	private AttendanceHistoryInfoProvider _attendanceHistoryInfoProvider;
	private AttendanceHistoryInfoListener _attendanceHistoryInfoListener;

	private String _authToken;
	private long _pageSize;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private long _currentAttendanceHistoryPage;
	private Long _userId;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetAttendanceHistoryOperation.class);

	public GetAttendanceHistoryOperation( User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetAttendanceHistory";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_pageSize = _pageSizeProvider.getItem("pageSize");
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_currentAttendanceHistoryPage = _attendanceHistoryInfoProvider.getCurrentAttendanceHistoryPage();
			_userId = _loginResponseProvider.getUserId();
			_bindVarsMap.put("userId", Long.toString(_userId));
			_bindVarsMap.put("pageSize", Long.toString(_pageSize));

			getAttendanceHistoryStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"GetAttendanceHistoryOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void getAttendanceHistoryStep() throws Throwable {
	
		/*
		 * Decide which page to get. It can be any random page, except that
		 * it cannot be the same as the last page retrieved. The
		 * totalAttendanceHistoryRecords provider handles this for us.
		 */
		long pageNumber = _attendanceHistoryInfoProvider.getRandomAttendanceHistoryRecordsPage(_pageSize, _currentAttendanceHistoryPage);
		_bindVarsMap.put("pageNumber", Long.toString(pageNumber));

		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _attendanceHistoryInfoListener};
		_authTokenHeaders.put("Accept", "application/json");

		logger.debug("getAttendanceHistoryStep behaviorID = " + this.getBehaviorId());

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId()
				+ ". getAttendanceHistory response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerAttendanceHistoryInfoListener(
			AttendanceHistoryInfoListener listener) {
		_attendanceHistoryInfoListener = listener;
	}

	@Override
	public void registerAttendanceHistoryInfoProvider(
			AttendanceHistoryInfoProvider provider) {
		_attendanceHistoryInfoProvider = provider;
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

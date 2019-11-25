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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListenerConfig;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetUserProfileOperation extends AuctionOperation implements NeedsLoginResponse, 
	ContainsUserProfile {

	private UserProfileListener _currentUserProfileListener;
	private LoginResponseProvider _loginResponseProvider;

	private String _authToken;
	private Long _userId;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetUserProfileOperation.class);

	public GetUserProfileOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetUserProfile";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_userId = _loginResponseProvider.getUserId();
			_bindVarsMap.put("userId",  Long.toString(_userId));
			initialStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("GetUserProfileOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void initialStep() throws Throwable {
		
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("GetCurrentUserProfileOperation:initialStep behaviorID = " + this.getBehaviorId() );
		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentUserProfileListener };
		_authTokenHeaders.put("Accept", "application/json");

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("GetCurrentUserProfileOperation:finalStep behaviorID = " + this.getBehaviorId()
				+ ". response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerUserProfileListener(UserProfileListener listener) {
		_currentUserProfileListener = listener;
	}

	@Override
	public UserProfileListenerConfig getUserProfileListenerConfig() {
		return null;
	}
	
	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

}

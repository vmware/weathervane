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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class LogoutOperation extends AuctionOperation implements NeedsLoginResponse {

	private LoginResponseProvider _loginResponseProvider;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private String	_username;

	private static final Logger logger = LoggerFactory.getLogger(LogoutOperation.class);

	public LogoutOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "Logout";
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
			throw new RuntimeException("LogoutOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void initialStep() throws Throwable {
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.info("initialStep behaviorID = " + this.getBehaviorId() );
		int[] validResponseCodes = new int[] { 200 };
		_authTokenHeaders.put("Accept", "*/*");
		doHttpGet(uri, null, validResponseCodes, null, false, false, null, null, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId());
	}


	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

}

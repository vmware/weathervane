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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsDetailItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetImageForItemOperation extends AuctionOperation implements NeedsLoginResponse, NeedsDetailItem {

	private LoginResponseProvider _loginResponseProvider;
	private DetailItemProvider _detailItemProvider;
	
	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();

	private String _imageUrl;
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(GetImageForItemOperation.class);

	public GetImageForItemOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetImageForItem";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {

		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_imageUrl = _detailItemProvider.getRandomItemImageLink();
			if (_imageUrl == null) {
				// No images.  Operation is finished
				logger.warn("Called GetImageForItemOperation but item has no images");
				finalStep();
				this.setOperationComplete(true);				
			} else {
				getImageStep();
			}
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"GetImageForItemOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}

	public void getImageStep() throws Throwable {

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;

		_bindVarsMap.put("imageUrl", _imageUrl);
		_bindVarsMap.put("size", "FULL");
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("behaviorID = " + this.getBehaviorId() );
		_authTokenHeaders.put("Accept", "image/jpeg,image/png");

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners,
				_authTokenHeaders);

	}
	
	protected void finalStep() throws Throwable {
		logger.debug("behaviorID = " + this.getBehaviorId()
				+ ".  response status = " + getCurrentResponseStatus());
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerDetailItemProvider(DetailItemProvider provider) {
		_detailItemProvider = provider;
	}


}

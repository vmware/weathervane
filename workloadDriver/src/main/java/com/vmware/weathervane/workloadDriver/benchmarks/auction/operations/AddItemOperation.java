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
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AddedItemIdListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAddedItemId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class AddItemOperation extends AuctionOperation implements NeedsLoginResponse, ContainsAddedItemId {

	private LoginResponseProvider _loginResponseProvider;
	private AddedItemIdListener _addedItemIdListener;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	
	private static final Logger logger = LoggerFactory.getLogger(GetItemDetailOperation.class);

	public AddItemOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "AddItem";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			addItemStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"AddItemOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void addItemStep() throws Throwable {
			
		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.POST, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _addedItemIdListener };

		logger.debug("addItemStep: behaviorID = " + this.getBehaviorId());

		Map<String, String> nameValuePairs = new HashMap<String, String>();
		nameValuePairs.put("condition", "Fair");
		nameValuePairs.put("dateOfOrigin", "1964-02-09");
		nameValuePairs.put("longDescription", UUID.randomUUID().toString() + " " + UUID.randomUUID().toString());
		nameValuePairs.put("name", UUID.randomUUID().toString());
		nameValuePairs.put("startingBidAmount", "100.0");
		nameValuePairs.put("manufacturer", "Fake Co.");

		doHttpPostJson(uri, null, validResponseCodes, null, nameValuePairs, mustContainText, dataListeners, _authTokenHeaders);

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
	public void registerAddedItemIdListener(AddedItemIdListener listener) {
		_addedItemIdListener = listener;
	}

}

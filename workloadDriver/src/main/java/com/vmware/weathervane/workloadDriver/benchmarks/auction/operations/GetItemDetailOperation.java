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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionItemsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsDetailItem;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.DetailItemListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAuctionItems;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetItemDetailOperation extends AuctionOperation implements NeedsLoginResponse, 
	NeedsAuctionItems, ContainsDetailItem {

	private LoginResponseProvider _loginResponseProvider;
	private AuctionItemsProvider _auctionItemsProvider;
	private DetailItemListener _detailItemListener;

	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private Long _itemId;
	private List<String> _itemImageURLs;
	
	private static final Logger logger = LoggerFactory.getLogger(GetItemDetailOperation.class);

	public GetItemDetailOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetItemDetail";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_itemId = _auctionItemsProvider.getRandomItemId();
			_bindVarsMap.put("itemId", Long.toString(_itemId));

			getItemDetailStep();
			break;

		case 1:
			_itemImageURLs = _auctionItemsProvider.getItemThumbnailLinks();
			if ((_itemImageURLs == null) || (_itemImageURLs.isEmpty())) {
				// No images.  Operation is finished
				finalStep();
				this.setOperationComplete(true);				
			} else {
				getItemImagesStep();
			}
			break;

		case 2:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException(
					"GetItemDetailOperation: Unknown operation step "
							+ this.getNextOperationStep());
			}
	}


	public void getItemDetailStep() throws Throwable {
			
		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _detailItemListener};
		_authTokenHeaders.put("Accept", "application/json");

		logger.debug("getItemDetailStep behaviorID = " + this.getBehaviorId());

		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	public void getItemImagesStep() throws Throwable {

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;
		
		_authTokenHeaders.put("Accept", "text/plain");
		_authTokenHeaders.put("Accept-Language", "en-us,en;q=0.5");

		int numUrls = _itemImageURLs.size();
		
		this.setGetRequestsOutstanding(numUrls);
		_bindVarsMap.put("size", "PREVIEW");

		for (int i = 0; i < numUrls; i++) {
			_bindVarsMap.put("imageUrl", _itemImageURLs.get(i));
			SimpleUri uri = getOperationUri(UrlType.GET, 1);

			logger.debug("getItemImagesStep behaviorID = " + this.getBehaviorId() );

			doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);
		}
		
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
	public void registerDetailItemListener(DetailItemListener listener) {
		_detailItemListener = listener;
	}

	@Override
	public DetailItemListenerConfig getDetailItemListenerConfig() {
		return null;
	}

	@Override
	public void registerAuctionItemsProvider(AuctionItemsProvider provider) {
		_auctionItemsProvider = provider;
	}

}

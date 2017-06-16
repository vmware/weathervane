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
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ActiveAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsFirstAuctionId;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.FirstAuctionIdListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsActiveAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPageSize;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUsersPerAuction;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PageSizeProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UsersPerAuctionProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class GetActiveAuctionsOperation extends AuctionOperation implements
		NeedsLoginResponse, NeedsPageSize, NeedsActiveAuctions, ContainsActiveAuctions, 
		NeedsAttendedAuctions, ContainsFirstAuctionId {

	private LoginResponseProvider _loginResponseProvider;
	private PageSizeProvider _pageSizeProvider;
	private ActiveAuctionProvider _liveAuctionProvider;
	private ActiveAuctionListener _liveAuctionListener;	
	private FirstAuctionIdListener _firstAuctionIdListener;	
	private AttendedAuctionsProvider _attendedAuctionsProvider;

	private String _authToken;
	private int _pageSize;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private boolean _gotPageForUser = false;
	private long _pageFetched = 0;
	
	private static final Logger logger = LoggerFactory.getLogger(GetActiveAuctionsOperation.class);

	public GetActiveAuctionsOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "GetActiveAuctions";
	}

	@Override
	public void execute() throws Throwable {
		if (this.getNextOperationStep() == 0) {
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_pageSize = _pageSizeProvider.getItem("pageSize");
			_authTokenHeaders.put("API_TOKEN", _authToken);	
			_bindVarsMap.put("pageSize", Long.toString(_pageSize));
			_gotPageForUser = false;
			_pageFetched = 0;
		}
				
		/*
		 * Get a random page of active auctions.  If this is
		 * the first time we are getting a page, then first will get 
		 * page 0, then get another random page.  if the user is already 
		 * attending all auctions on the page, get another random page.
		 */
		
		// First determine whether we already have a page
		if (!_liveAuctionProvider.hasData()) {
			/*
			 * Need to get a page first so that we know how many active pages there are.
			 * We need this information to select a random page.
			 */
			logger.info("No activeAuction data yet, fetching page 0");
			getActiveAuctionsStep();
			return;
		} else if (_liveAuctionProvider.getTotalActiveAuctions() == 0) {
			logger.info("There are no active auctions.  Finish operation ");
			finalStep();
			this.setOperationComplete(true);
			return;
		} 
		
		if (_liveAuctionProvider.getCurrentActiveAuctionsPage() == 0) {
			/*
			 * Save the auctionId of the first auction for use in other operations.
			 * It is used when forming the ID of auctions to join in JoinAuction
			 */
			AuctionRepresentation firstAuction = _liveAuctionProvider.getActiveAuctions().get(0);
			_firstAuctionIdListener.setFirstAuctionId(firstAuction.getId());
		}
		
		/*
		 * Already have data.  Decide whether we fetched a new page.
		 * The initial fetch doesn't count as a new page because it
		 * isn't random across all possible pages.
		 */
		if (_gotPageForUser) {
			/*
			 * Got a new page.  Need to make sure that the user isn't already attending
			 * all auctions on the page.
			 */
			if (this.getNextOperationStep() > 4) {
				/*
				 * If we haven't found a page of auctions yet, then 
				 * give up.
				 */
				this.setOperationComplete(true);
			}
			
			boolean attendingAll = true;
			List<AuctionRepresentation> activeAuctions =  _liveAuctionProvider.getActiveAuctions();
			Set<Long> attendedAuctionIDs = _attendedAuctionsProvider.getAttendedAuctionIds();
			logger.debug("There are " + activeAuctions.size() + " active auctions and "
					+ attendedAuctionIDs.size() + " attended auctions: " + attendedAuctionIDs);
			for (AuctionRepresentation auctionRepresentation : activeAuctions) {
				if (!attendedAuctionIDs.contains(auctionRepresentation.getId())) {
					attendingAll = false;
					break;
				}
			}
			if (attendingAll) {
				/*
				 * User is attending all auctions on this page. Need to get a
				 * different page if there is one.
				 */
				logger.info("User is attending all auctions on page.  getting another page.");
				getActiveAuctionsStep();
			} else {
				logger.info("Final active auctions page fetched = " + _pageFetched);
				finalStep();
				this.setOperationComplete(true);
			}
		} else {
			/*
			 * Get a new page of active auctions
			 */
			getActiveAuctionsStep();
			_gotPageForUser = true;
		}
		
	}

	public void getActiveAuctionsStep() throws Throwable {
	
		/*
		 * Decide which page to get. It can be any random page.
		 */
		_pageFetched = _liveAuctionProvider.getRandomActiveAuctionsPage(_pageSize);
		_bindVarsMap.put("pageNumber", Long.toString(_pageFetched));

		/*
		 * Prepare the information for the GET
		 */
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] {  _liveAuctionListener };
		_authTokenHeaders.put("Accept", "application/json");

		logger.debug("GetActiveAuctionsOperation:getActiveAuctionsStep, operationStep = " + this.getNextOperationStep() 
				+ ", behaviorID = " + this.getBehaviorId());
		
		doHttpGet(uri, _bindVarsMap, validResponseCodes, null, false, false, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("GetActiveAuctionsOperation:finalStep behaviorID = " + this.getBehaviorId());
		_gotPageForUser = false;
	}

	@Override
	public void registerPageSizeProvider(PageSizeProvider provider) {
		_pageSizeProvider = provider;
	}

	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerActiveAuctionProvider(ActiveAuctionProvider provider) {
		_liveAuctionProvider = provider;
	}
	
	@Override
	public void registerAttendedAuctionsProvider(AttendedAuctionsProvider provider) {
		_attendedAuctionsProvider = provider;
	}

	@Override
	public void registerActiveAuctionListener(ActiveAuctionListener listener) {
		_liveAuctionListener = listener;		
	}

	@Override
	public ActiveAuctionListenerConfig getActiveAuctionListenerConfig() {
		return null;
	}
	
	@Override
	public void registerFirstAuctionIdListener(FirstAuctionIdListener listener) {
		_firstAuctionIdListener = listener;
	}

}

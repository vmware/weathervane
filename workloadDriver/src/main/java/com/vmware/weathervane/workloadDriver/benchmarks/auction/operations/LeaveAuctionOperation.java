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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AttendedAuctionsListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.AuctionIdToLeaveProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsAttendedAuctions;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsAuctionIdToLeave;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class LeaveAuctionOperation extends AuctionOperation implements NeedsLoginResponse, 
	NeedsAuctionIdToLeave, ContainsAttendedAuctions {

	private AttendedAuctionsListener _attendedAuctionsListener;
	private LoginResponseProvider _loginResponseProvider;
	private AuctionIdToLeaveProvider _auctionIdToLeaveProvider;

	private Long _auctionIdToLeave;
	private String _authToken;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(LeaveAuctionOperation.class);

	public LeaveAuctionOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "LeaveAuction";
	}

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			leaveAuctionStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("LeaveAuctionOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void leaveAuctionStep() throws Throwable {
		_auctionIdToLeave = _auctionIdToLeaveProvider.getItem("auctionIdToLeave");
		_bindVarsMap.put("auctionId", Long.toString(_auctionIdToLeave));
		SimpleUri uri = getOperationUri(UrlType.POST, 0);
		
		logger.debug("leaveAuctionStep behaviorID = " + this.getBehaviorId() + " leaving auction " + _auctionIdToLeave);

		int[] validResponseCodes = new int[] { 200 };
		int[] abortResponseCodes = new int[] { 409 };
		String[] mustContainText = null;
		_authTokenHeaders.put("Accept", "application/json");

		doHttpDelete(uri, _bindVarsMap, validResponseCodes, abortResponseCodes, mustContainText, null, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {

		logger.debug("finalStep behaviorID = " + this.getBehaviorId());

		_attendedAuctionsListener.removeAttendedAuction(_auctionIdToLeave);
	}

	@Override
	public void registerAttendedAuctionsListener(AttendedAuctionsListener listener) {
		_attendedAuctionsListener = listener;
	}

	@Override
	public AttendedAuctionsListenerConfig getAttendedAuctionsListenerConfig() {
		return null;
	}
	
	@Override
	public void registerLoginResponseProvider(LoginResponseProvider provider) {
		_loginResponseProvider = provider;
	}

	@Override
	public void registerAuctionIdToLeaveProvider(AuctionIdToLeaveProvider provider) {
		_auctionIdToLeaveProvider = provider;
	}

}

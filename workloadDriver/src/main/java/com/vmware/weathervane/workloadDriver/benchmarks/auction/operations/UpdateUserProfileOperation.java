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

import com.fasterxml.jackson.databind.ObjectMapper;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsUserProfile;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileListenerConfig;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.UserProfileProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.representation.UserRepresentation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;


public class UpdateUserProfileOperation extends AuctionOperation implements  NeedsLoginResponse, NeedsUserProfile,
ContainsUserProfile {

	private static ObjectMapper _objectMapper = new ObjectMapper();
	
	private UserProfileListener _currentUserProfileListener;
	private LoginResponseProvider _loginResponseProvider;
	private UserProfileProvider _userProfileProvider;

	private String _authToken;
	private Long _userId;
	private Map<String, String> _authTokenHeaders = new HashMap<String, String>();
	private Map<String, String> _bindVarsMap = new HashMap<String, String>();

	private static final Logger logger = LoggerFactory.getLogger(UpdateUserProfileOperation.class);

   
   public UpdateUserProfileOperation(User userState, Behavior behavior, Target target, StatsCollector statsCollector) {
	      super(userState, behavior, target, statsCollector);
   }

   @Override
   public String provideOperationName() {
      return "UpdateUserProfile";
   }


	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			// First get the information we will need for all of the steps.
			_authToken = _loginResponseProvider.getAuthToken();
			_authTokenHeaders.put("API_TOKEN", _authToken);
			_userId = _loginResponseProvider.getUserId();
			_bindVarsMap.put("userId", Long.toString(_userId));

			updateProfileStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("UpdateUserProfileOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void updateProfileStep() throws Throwable {
		
		SimpleUri uri = getOperationUri(UrlType.POST, 0);
		
		UserRepresentation theUser = _userProfileProvider.getResponse();

		theUser.setFirstname(UUID.randomUUID().toString());
		theUser.setPassword("password");
		theUser.setRepeatPassword("password");

		String userProfileJsonString = _objectMapper.writeValueAsString(theUser);

		logger.debug("updateProfileStep behaviorID = " + this.getBehaviorId());
		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _currentUserProfileListener };

		doHttpPutJsonString(uri, _bindVarsMap, validResponseCodes, null, userProfileJsonString, mustContainText, dataListeners, _authTokenHeaders);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId()
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

	@Override
	public void registerUserProfileProvider(UserProfileProvider provider) {
		_userProfileProvider = provider;
	}
}

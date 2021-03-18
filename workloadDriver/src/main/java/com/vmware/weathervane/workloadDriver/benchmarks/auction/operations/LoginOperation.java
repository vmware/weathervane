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
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ChoosesBidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.ContainsLoginResponse;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseListener;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPassword;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.NeedsPersonNames;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PasswordProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.PersonNameProvider;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.BidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.LowerRandomBidStrategy;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies.RandomBidStrategy;
import com.vmware.weathervane.workloadDriver.common.chooser.Chooser;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

public class LoginOperation extends AuctionOperation implements  NeedsPersonNames, NeedsPassword,
		ChoosesBidStrategy, ContainsLoginResponse {

	private static final Logger logger = LoggerFactory.getLogger(LoginOperation.class);
	
	private PersonNameProvider _personNameProvider;
	private PasswordProvider _passwordProvider;
	private LoginResponseListener _loginResponseListener;
	private Chooser<BidStrategy> _bidStrategyChooser;
	
	String _userName;

	public LoginOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "Login";
	}

	@Override
	public void execute() throws Throwable {
//		System.out.println("LoginOperation:execute for UUID = " + getBehaviorId() + " nextOperationStep = " + getNextOperationStep());
		switch (this.getNextOperationStep()) {
		case 0:
			loginStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("LoginOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	public void loginStep() throws Throwable {
		
		logger.info("LoginOperation:loginStep behaviorID = " + this.getBehaviorId() );

		_userName = _personNameProvider.getRandomPersonName();
		this.getUser().setUserName(_userName);
		
		logger.info("LoginOperation:loginStep behaviorID = " + this.getBehaviorId() + ", InitialStep userName =  " + _userName
				+ ", target = " + getTarget().getName() + ", userId = " + getUser().getId());

		// Choose a new bidding strategy to be used for the duration of this
		// user's login
		BidStrategy choice = null;
		if (this.getBehavior().getBehaviorSpec().getName().equals("auctionRevisedMainUser") 
				|| this.getBehavior().getBehaviorSpec().getName().equals("auctionMainUser2")) {
			choice = new LowerRandomBidStrategy();
		} else {
			choice = new RandomBidStrategy();
		}
		_bidStrategyChooser.setChosen(choice);

		logger.info("LoginOperation:loginStep behaviorID = " + this.getBehaviorId() + ", get password for userName =  " + _userName);
		String pwd = _passwordProvider.getPasswordForPerson(_userName);
		logger.info("LoginOperation:loginStep behaviorID = " + this.getBehaviorId() + ", Got password for userName =  " + _userName 
				+ ", password = " + pwd);

		SimpleUri uri = getOperationUri(UrlType.POST, 0);

		int[] validResponseCodes = new int[] { 201 };
		String[] mustContainText = null;
		DataListener[] dataListeners = new DataListener[] { _loginResponseListener };
		Map<String, String> nameValuePairs = new HashMap<String, String>();
		nameValuePairs.put("username", _userName);
		nameValuePairs.put("password", pwd);

		logger.debug("LoginOperation:InitialStep.  Doing POST, behaviorID = " + this.getBehaviorId());

		doHttpPostJson(uri, null, validResponseCodes, null, nameValuePairs, mustContainText, dataListeners, null);

	}

	protected void finalStep() throws Throwable {
		logger.debug("LoginOperation:finalStep behaviorID = " + this.getBehaviorId() + ". loginStep response status = "
				+ getCurrentResponseStatus());
	}

	@Override
	public void registerPersonNameProvider(PersonNameProvider provider) {
		_personNameProvider = provider;
	}

	@Override
	public void registerPasswordProvider(PasswordProvider provider) {
		_passwordProvider = provider;
	}

	@Override
	public void registerBidStrategyChooser(Chooser<BidStrategy> chooser) {
		this._bidStrategyChooser = chooser;
	}

	@Override
	public void registerLoginResponseListener(
			com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionStateManagerStructs.LoginResponseListener listener) {
		_loginResponseListener = listener;
	}

}

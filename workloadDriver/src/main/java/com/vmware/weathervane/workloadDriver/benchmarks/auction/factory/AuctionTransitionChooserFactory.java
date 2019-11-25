/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.factory;

import java.util.HashMap;
import java.util.Map;
import java.util.Random;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers.BidLeaveOtherTransitionChooser;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers.BidOtherTransitionChooser;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers.GetNextBidTransitionChooser;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers.LogoutJoinLeaveTransitionChooser;
import com.vmware.weathervane.workloadDriver.benchmarks.auction.transitionChoosers.OtherLogoutJoinTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.DefaultTransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooser;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.factory.TransitionChooserFactory;

public class AuctionTransitionChooserFactory implements TransitionChooserFactory {

	@Override
	public Map<String, TransitionChooser> getTransitionChoosers(Random random, Behavior behavior) {
		Map<String, TransitionChooser> nameToTCMap = new HashMap<String, TransitionChooser>();
	
		TransitionChooser chooser = new DefaultTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("Default", chooser);
		
		chooser = new LogoutJoinLeaveTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("LogoutJoinLeave", chooser);
		
		chooser = new BidLeaveOtherTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("BidLeaveOther", chooser);
		
		chooser = new OtherLogoutJoinTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("OtherLogoutJoin", chooser);
		
		chooser = new BidOtherTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("BidOther", chooser);
		
		chooser = new GetNextBidTransitionChooser(random);
		chooser.setBehavior(behavior);
		nameToTCMap.put("GetNextBid", chooser);
		
		return nameToTCMap;
	}

}

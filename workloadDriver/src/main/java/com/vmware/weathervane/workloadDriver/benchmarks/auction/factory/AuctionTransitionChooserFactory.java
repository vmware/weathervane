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

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.strategies;

import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.Strategy;

public interface BidStrategy extends Strategy {
	public boolean shouldBid(String itemName, double currentBid, double myCreditLimit);
	
	public double bidAmount(String itemName, double currentBid, double myCreditLimit);
	
}

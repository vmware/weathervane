/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.operations;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

import io.netty.buffer.ByteBuf;

public class AddItemToAuctionOperation extends AuctionOperation  {

   
   public AddItemToAuctionOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
   }

   @Override
   public String provideOperationName() {
      return "AddItemToAuction";
   }

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
//			System.out.println("NoOperation:execute: UserID = " + getUser().getId());
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("AddItemToAuctionOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

}

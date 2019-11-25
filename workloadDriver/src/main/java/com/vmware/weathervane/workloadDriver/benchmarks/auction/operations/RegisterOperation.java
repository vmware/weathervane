/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.operations;

import com.vmware.weathervane.workloadDriver.benchmarks.auction.common.AuctionOperation;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;


public class RegisterOperation extends AuctionOperation  {

   
   public RegisterOperation(User userState, Behavior behavior, 
				Target target, StatsCollector statsCollector) {
	   super(userState, behavior, target, statsCollector);
   }

   @Override
   public String provideOperationName() {
      return "Register";
   }

	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("RegisterOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

}

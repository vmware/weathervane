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
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.core.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

public class HomePageOperation extends AuctionOperation {

	private static final Logger logger = LoggerFactory.getLogger(HomePageOperation.class);

	public HomePageOperation(User userState, Behavior behavior, 
			Target target, StatsCollector statsCollector) {
		super(userState, behavior, target, statsCollector);
	}

	@Override
	public String provideOperationName() {
		return "HomePage";
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * com.vmware.weathervane.workloadDriver.common.core.Operation#executeOperation(java.util
	 * .UUID)
	 */
	@Override
	public void execute() throws Throwable {
		switch (this.getNextOperationStep()) {
		case 0:
			initialStep();
			break;

		case 1:
			finalStep();
			this.setOperationComplete(true);
			break;

		default:
			throw new RuntimeException("HomePageOperation: Unknown operation step "
					+ this.getNextOperationStep());
		}
	}

	protected void initialStep() throws Throwable {
		SimpleUri uri = getOperationUri(UrlType.GET, 0);

		logger.debug("initialStep behaviorID = " + this.getBehaviorId() );
		int[] validResponseCodes = new int[] { 200 };
		String[] mustContainText = null;
		DataListener[] dataListeners = null;
		Map<String, String> headers = new HashMap<String, String>();
		headers.put("Accept", "text/html");
		
		logger.debug("initialStep: calling doHttpGet with uri " + uri.getUriString());
		doHttpGet(uri, null, validResponseCodes, null, false, false, mustContainText, dataListeners, headers);

	}

	protected void finalStep() throws Throwable {
		logger.debug("finalStep behaviorID = " + this.getBehaviorId());

	}

}

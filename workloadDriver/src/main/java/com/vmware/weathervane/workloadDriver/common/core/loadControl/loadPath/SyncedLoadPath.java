/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.core.WorkloadStatus;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.UniformLoadInterval;

public abstract class SyncedLoadPath extends LoadPath {
	private static final Logger logger = LoggerFactory.getLogger(SyncedLoadPath.class);

	private String curIntervalName;
	
	@Override
	public void run() {
		logger.debug("run for run " + runName + ", workload " + workloadName + ", loadPath " + getName() );
		
		/*
		 * Check whether the just completed interval was the end of a stats interval
		 */
		if (getIsStatsInterval() && this.isStatsIntervalComplete()) {
			getStatsTracker().statsIntervalComplete();
		}
		
		// Notify the loadPath that the interval is complete
		IntervalCompleteResult result = this.intervalComplete(); 
		curIntervalName = result.getIntervalName();
		logger.debug("run for run {}, workload {}, loadPath {}: "
				+ "intervalComplete returned curIntervalName {}, decisionInterval {}, passed {}",
				runName, workloadName, getName(), curIntervalName, result.isDecisionInterval(),
				result.isPassed());
		
		if (result.isDecisionInterval()) {
			/*
			 * Post the result to the loadPathController
			 */
			loadPathController.postIntervalResult(getName(), curIntervalName, result.isPassed());
		} else {
			/*
			 * Invoke the steps to get the next interval directly
			 */
			this.intervalResult(curIntervalName, result.isPassed());
		}

	}
	
	@Override
	public void intervalResult(String intervalName, boolean intervalResult) {
		logger.debug("intervalResult for interval {} = {}", intervalName, intervalResult);
		
		if (!intervalName.equals(curIntervalName)) {
			/*
			 *  Got a result for the wrong interval.  Something
			 *  has gone wrong so we end things here.
			 */
			logger.warn("intervalResult: expecting result for interval {}, got result for interval {}", 
					curIntervalName, intervalName);
			WorkloadStatus status = new WorkloadStatus();
			status.setIntervalStatsSummaries(getIntervalStatsSummaries());
			status.setMaxPassUsers(0);
			status.setMaxPassIntervalName(null);
			status.setPassed(false);
			status.setLoadPathName(this.getName());

			workload.loadPathComplete(status);
			return;
		}
		
		UniformLoadInterval nextInterval = this.getNextIntervalSynced(intervalResult);
		logger.debug("intervalResult: nextInterval = " + nextInterval);
		long users = nextInterval.getUsers();

		/*
		 * Notify the workload, so that it can notify the statsIntervalSpec
		 * of the start number of users
		 */
		workload.setActiveUsers(users);

		/*
		 * Send messages to workloadService on driver nodes indicating new
		 * number of users to run.
		 */
		try {
			changeActiveUsers(users);
		} catch (Throwable t) {
			logger.warn("intervalResult: LoadPath {} got throwable when notifying hosts of change in active users: {}", 
							this.getName(), t.getMessage());
		}
		
		long wait = nextInterval.getDuration();
		logger.debug("intervalResult: interval duration is " + wait + " seconds");
		if (!isFinished() && (wait > 0)) {
			logger.debug("run: sleeping for  " + wait + " seconds");
			getExecutorService().schedule(this, wait, TimeUnit.SECONDS);
		}
	}

	protected abstract IntervalCompleteResult intervalComplete();

	protected abstract UniformLoadInterval getNextIntervalSynced(boolean passed);
	
	protected class IntervalCompleteResult {
		private String intervalName;
		private boolean decisionInterval;
		private boolean passed;
		public String getIntervalName() {
			return intervalName;
		}
		public void setIntervalName(String intervalName) {
			this.intervalName = intervalName;
		}
		public boolean isDecisionInterval() {
			return decisionInterval;
		}
		public void setDecisionInterval(boolean decisionInterval) {
			this.decisionInterval = decisionInterval;
		}
		public boolean isPassed() {
			return passed;
		}
		public void setPassed(boolean passed) {
			this.passed = passed;
		}
		
	}

}

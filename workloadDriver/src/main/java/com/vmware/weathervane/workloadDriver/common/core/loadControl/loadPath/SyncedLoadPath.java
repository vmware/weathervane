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
	private long nextIntervalWait;
	
	@Override
	public void run() {
		logger.info("run for run " + runName + ", workload " + workloadName + ", loadPath " + getName() 
		+ ", isStatsInterval " + getIsStatsInterval() + ", isStatsIntervalComplete " + isStatsIntervalComplete());
		
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
			this.changeInterval(curIntervalName, result.isPassed());
			this.startNextInterval();
		}

	}
	
	@Override
	public void changeInterval(String intervalName, boolean intervalResult) {
		logger.info("changeInterval for interval {} = {}", intervalName, intervalResult);
		
		if (!intervalName.equals(curIntervalName)) {
			/*
			 *  Got a result for the wrong interval.  Something
			 *  has gone wrong so we end things here.
			 */
			logger.warn("changeInterval: expecting result for interval {}, got result for interval {}", 
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
		logger.debug("changeInterval: nextInterval = " + nextInterval);
		long users = nextInterval.getUsers();
		nextIntervalWait = nextInterval.getDuration();

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
			logger.warn("changeInterval: LoadPath {} got throwable when notifying hosts of change in active users: {}", 
							this.getName(), t.getMessage());
		}
	}
	
	@Override
	public void startNextInterval() {
		logger.debug("startNextInterval: interval duration is " + nextIntervalWait + " seconds");
		if (!isFinished() && (nextIntervalWait > 0)) {
			logger.debug("startNextInterval: sleeping for  " + nextIntervalWait + " seconds");
			getExecutorService().schedule(this, nextIntervalWait, TimeUnit.SECONDS);
			// The interval really starts now
			getStatsTracker().setCurIntervalStartTime(System.currentTimeMillis());

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

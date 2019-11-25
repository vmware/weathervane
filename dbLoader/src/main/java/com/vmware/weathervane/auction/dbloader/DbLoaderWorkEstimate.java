/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.dbloader;

/**
 * This class is used to hold the per-user or per-item work estimates for the
 * DBLoader. The work is estimate of the number of seconds needed to load one
 * User or one Item (for history, future, and current items). These values are
 * used when estimating the remaining time required to finish loading the data
 * services.
 * 
 * @author Hal
 * 
 */
public class DbLoaderWorkEstimate {

	private double userWork;
	private double historyWork;
	private double futureWork;
	private double currentWork;

	public double getUserWork() {
		return userWork;
	}

	public void setUserWork(double userWork) {
		this.userWork = userWork;
	}

	public double getHistoryWork() {
		return historyWork;
	}

	public void setHistoryWork(double historyWork) {
		this.historyWork = historyWork;
	}

	public double getFutureWork() {
		return futureWork;
	}

	public void setFutureWork(double futureWork) {
		this.futureWork = futureWork;
	}

	public double getCurrentWork() {
		return currentWork;
	}

	public void setCurrentWork(double currentWork) {
		this.currentWork = currentWork;
	}
}

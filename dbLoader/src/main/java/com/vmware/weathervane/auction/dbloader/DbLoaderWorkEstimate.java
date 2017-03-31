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

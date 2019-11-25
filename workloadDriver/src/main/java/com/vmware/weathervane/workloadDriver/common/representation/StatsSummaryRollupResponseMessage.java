/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.representation;

import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

public class StatsSummaryRollupResponseMessage {

	private String status;
	private String message;
	private StatsSummaryRollup statsSummaryRollup;
	private Integer numSamplesReceived;
	private Integer numSamplesExpected;
	
	public StatsSummaryRollup getStatsSummaryRollup() {
		return statsSummaryRollup;
	}

	public void setStatsSummaryRollup(StatsSummaryRollup statsSummaryRollup) {
		this.statsSummaryRollup = statsSummaryRollup;
	}

	public Integer getNumSamplesReceived() {
		return numSamplesReceived;
	}

	public void setNumSamplesReceived(Integer numSamplesReceived) {
		this.numSamplesReceived = numSamplesReceived;
	}

	public Integer getNumSamplesExpected() {
		return numSamplesExpected;
	}

	public void setNumSamplesExpected(Integer numSamplesExpected) {
		this.numSamplesExpected = numSamplesExpected;
	}

	public String getStatus() {
		return status;
	}

	public void setStatus(String status) {
		this.status = status;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}

	@Override
	public String toString() {
		return "StatsSummaryResponseMessage: "
				+ "numSamplesReceived = " + numSamplesReceived
				+ ", numSamplesExpected = " + numSamplesExpected;
	}
	
}

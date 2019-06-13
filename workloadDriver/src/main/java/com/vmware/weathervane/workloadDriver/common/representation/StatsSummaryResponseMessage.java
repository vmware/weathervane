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
package com.vmware.weathervane.workloadDriver.common.representation;

import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummary;

public class StatsSummaryResponseMessage {

	private String status;
	private String message;
	private StatsSummary statsSummary;
	private String summaryText;
	private Integer numSamplesReceived;
	private Integer numSamplesExpected;
	
	public StatsSummary getStatsSummary() {
		return statsSummary;
	}

	public void setStatsSummary(StatsSummary statsSummary) {
		this.statsSummary = statsSummary;
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

	public String getSummaryText() {
		return summaryText;
	}

	public void setSummaryText(String summaryText) {
		this.summaryText = summaryText;
	}

	@Override
	public String toString() {
		return "StatsSummaryResponseMessage: "
				+ "numSamplesReceived = " + numSamplesReceived
				+ ", numSamplesExpected = " + numSamplesExpected;
	}
	
}

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
package com.vmware.weathervane.workloadDriver.common.statistics;

/* 
 * Class to hold calculated values for each operation 
 */
public class ComputedOpStatsSummary {
	private long successes = 0;
	private long failures = 0;
	private long rtFailures = 0;
	private boolean passed = true;
	private boolean passedRt = true;
	private boolean passedMixPct = true;
	private boolean passedFailurePct = true;
	private double throughput = 0;
	private double effectiveThroughput = 0;
	private double passingPct = 0;
	private double avgRt = 0;
	private double avgFailedRt = 0;
	private double avgPassedRt = 0;
	private double mixPct = 0;
	private double avgCycleTime = 0;
	
	public boolean isPassed() {
		return passed;
	}
	public void setPassed(boolean passed) {
		this.passed = passed;
	}
	public boolean isPassedRt() {
		return passedRt;
	}
	public void setPassedRt(boolean passedRt) {
		this.passedRt = passedRt;
	}
	public boolean isPassedMixPct() {
		return passedMixPct;
	}
	public void setPassedMixPct(boolean passedMixPct) {
		this.passedMixPct = passedMixPct;
	}
	public double getThroughput() {
		return throughput;
	}
	public void setThroughput(double throughput) {
		this.throughput = throughput;
	}
	public double getEffectiveThroughput() {
		return effectiveThroughput;
	}
	public void setEffectiveThroughput(double effectiveThroughput) {
		this.effectiveThroughput = effectiveThroughput;
	}
	public double getPassingPct() {
		return passingPct;
	}
	public void setPassingPct(double passingPct) {
		this.passingPct = passingPct;
	}
	public double getAvgRt() {
		return avgRt;
	}
	public void setAvgRt(double avgRt) {
		this.avgRt = avgRt;
	}
	public double getAvgFailedRt() {
		return avgFailedRt;
	}
	public void setAvgFailedRt(double avgFailedRt) {
		this.avgFailedRt = avgFailedRt;
	}
	public double getAvgPassedRt() {
		return avgPassedRt;
	}
	public void setAvgPassedRt(double avgPassedRt) {
		this.avgPassedRt = avgPassedRt;
	}
	public double getMixPct() {
		return mixPct;
	}
	public void setMixPct(double mixPct) {
		this.mixPct = mixPct;
	}
	public double getAvgCycleTime() {
		return avgCycleTime;
	}
	public void setAvgCycleTime(double avgCycleTime) {
		this.avgCycleTime = avgCycleTime;
	}

	public long getSuccesses() {
		return successes;
	}
	public void setSuccesses(long successes) {
		this.successes = successes;
	}
	public long getFailures() {
		return failures;
	}
	public void setFailures(long failures) {
		this.failures = failures;
	}
	public long getRtFailures() {
		return rtFailures;
	}
	public void setRtFailures(long rtFailures) {
		this.rtFailures = rtFailures;
	}
	public boolean isPassedFailurePct() {
		return passedFailurePct;
	}
	public void setPassedFailurePct(boolean passedFailurePct) {
		this.passedFailurePct = passedFailurePct;
	}
	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("passed = " + passed);
		retVal.append(", passedRt = " + passedRt);
		retVal.append(", passedMixPct = " + passedMixPct);
		retVal.append(", throughput = " + throughput);
		retVal.append(", effectiveThroughput = " + effectiveThroughput);
		retVal.append(", passingPct = " + passingPct);
		retVal.append(", avgRt = " + avgRt);
		retVal.append(", avgFailedRt = " + avgFailedRt);
		retVal.append(", mixPct = " + mixPct);
		retVal.append(", avgCycleTime = " + avgCycleTime);

		return retVal.toString();
	}
}
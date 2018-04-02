package com.vmware.weathervane.workloadDriver.common.statistics;

/* 
 * Class to hold calculated values for each operation 
 */
public class ComputedOpStatsSummary {
	private boolean passed = false;
	private boolean passedRt = false;
	private boolean passedMixPct = false;
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
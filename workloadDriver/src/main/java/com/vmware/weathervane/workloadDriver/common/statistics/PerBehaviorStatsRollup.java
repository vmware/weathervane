package com.vmware.weathervane.workloadDriver.common.statistics;

public class PerBehaviorStatsRollup {
	private long totalNumOps = 0;
	private long totalNumRTOps = 0;
	private long totalNumFailedRT = 0;
	private long totalNumFailed = 0;
	private long totalSteps = 0;
	private long totalRT = 0;
	private long totalCycleTime = 0;
	private double throughput = 0;
	private double effectiveThroughput = 0;
	private double stepsThroughput = 0;
	private double avgRT = 0;
	private double avgCycleTime = 0;
	private double pctPassing = 1;
	private boolean intervalPassed = true;
	private boolean intervalPassedRT = true;
	private boolean intervalPassedMix = true;
	private boolean intervalPassedFailure = true;
	
	public double getThroughput() {
		return throughput;
	}
	public double getEffectiveThroughput() {
		return effectiveThroughput;
	}
	public double getStepsThroughput() {
		return stepsThroughput;
	}
	public double getAvgRT() {
		return avgRT;
	}
	public double getAvgCycleTime() {
		return avgCycleTime;
	}
	public double getPctPassing() {
		return pctPassing;
	}
	public boolean isIntervalPassed() {
		return intervalPassed;
	}
	public boolean isIntervalPassedRT() {
		return intervalPassedRT;
	}
	public boolean isIntervalPassedMix() {
		return intervalPassedMix;
	}
	public boolean isIntervalPassedFailure() {
		return intervalPassedFailure;
	}
	public long getTotalNumOps() {
		return totalNumOps;
	}
	public void incrTotalNumOps(long totalNumOps) {
		this.totalNumOps += totalNumOps;
	}
	public long getTotalNumRTOps() {
		return totalNumRTOps;
	}
	public void incrTotalNumRTOps(long totalNumRTOps) {
		this.totalNumRTOps += totalNumRTOps;
	}
	public long getTotalNumFailedRT() {
		return totalNumFailedRT;
	}
	public void incrTotalNumFailedRT(long totalNumFailedRT) {
		this.totalNumFailedRT += totalNumFailedRT;
	}
	public long getTotalNumFailed() {
		return totalNumFailed;
	}
	public void incrTotalNumFailed(long totalNumFailed) {
		this.totalNumFailed += totalNumFailed;
	}
	public long getTotalSteps() {
		return totalSteps;
	}
	public void incrTotalSteps(long totalSteps) {
		this.totalSteps += totalSteps;
	}
	public long getTotalRT() {
		return totalRT;
	}
	public void incrTotalRT(long totalRT) {
		this.totalRT += totalRT;
	}
	public long getTotalCycleTime() {
		return totalCycleTime;
	}
	public void incrTotalCycleTime(long totalCycleTime) {
		this.totalCycleTime += totalCycleTime;
	}
	
	public void calcDerivedStats(double intervalDurationSec) {
		long totalNumSucessfulOps = totalNumOps - totalNumFailed - totalNumFailedRT;
		throughput = totalNumOps / (1.0 * intervalDurationSec);
		effectiveThroughput =totalNumSucessfulOps / (1.0 * intervalDurationSec);
		stepsThroughput = totalSteps / (1.0 * intervalDurationSec);
		if (totalNumRTOps > 0) {
			avgRT = (totalRT/1000.0) / (1.0 * totalNumRTOps);
		}
		
		if (totalNumOps > 0) {
			avgCycleTime = (totalCycleTime/1000.0)/(1.0 * totalNumOps);
		}
		
		if (totalNumOps > 0) {
			pctPassing = (totalNumOps - totalNumFailedRT) / (totalNumOps * 1.0);
		}
	}

}

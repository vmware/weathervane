/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics;

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class OperationStatsSummary {
	private static final Logger logger = LoggerFactory.getLogger(OperationStatsSummary.class);

	private int operationIndex = 0;
	private String operationName;
	
	private long totalNumOps = 0;
	private long totalNumRTOps = 0;
	private long totalNumFailedRT = 0;

	private long totalNumFailed = 0;
	private Map<String, Long> failureStringCounts = new HashMap<String, Long>();
	
	private long totalResponseTime = 0;
	private long totalFailedResponseTime = 0;
	private long totalPassedResponseTime = 0;
	public long minResponseTime				= Long.MAX_VALUE;
	public long maxResponseTime				= Long.MIN_VALUE;
	private long totalCycleTime = 0;

	private long totalSteps = 0;

	private long responseTimeLimit;	
	private double responseTimeLimitPercentile;	
	private boolean useResponseTime;
	private double requiredMixPct;
	private double mixPctTolerance;
	private double allowedFailurePercent;
		
	public OperationStatsSummary(String operationName, int operationIndex,
			long responseTimeLimit, double responseTimeLimitPercentile, 
			boolean useResponseTime, double requiredMixPct, double mixTolerance,
			double allowedFailurePercent) {
		logger.debug("Creating new operationStatsSummary: " + this);
		this.operationIndex = operationIndex;
		this.operationName = operationName;
		this.responseTimeLimit = responseTimeLimit;
		this.responseTimeLimitPercentile = responseTimeLimitPercentile;
		this.useResponseTime = useResponseTime;
		this.requiredMixPct = requiredMixPct;
		this.mixPctTolerance = mixTolerance;
		this.allowedFailurePercent = allowedFailurePercent;
		logger.debug("Created new operationStatsSummary: " + this);
	}

	public OperationStatsSummary() {
	}

	public void addStats(OperationStats operationStats) {
		logger.info("addStats: OperationStats = " + operationStats);

		/*
		 * Check the start and end times to make sure they were set properly
		 */
		if ((operationStats.getStartTime() <= 0) || (operationStats.getEndTime() <= 0)) {
			return;
		}
		
		totalNumOps++;

		long responseTime = operationStats.getEndTime() - operationStats.getStartTime() ;
		
		if (useResponseTime) {
			totalResponseTime += responseTime;
			totalNumRTOps++;
			if ((responseTime / 1000.0) > responseTimeLimit) {
				logger.debug("addStats: " + operationName + " failed response-time.  responseTime = " 
						+ responseTime + ", responseTimeLimit = " + responseTimeLimit);
				totalNumFailedRT++;
				totalFailedResponseTime += responseTime;
			} else {
				totalPassedResponseTime += responseTime;
			}
		}
		
		totalCycleTime += operationStats.getCycleTime();
		
		if (operationStats.isFailed()) {
			totalNumFailed++;
			Long failureStringCount = failureStringCounts.get(operationStats.getFailureString());
			if (failureStringCount == null) {
				failureStringCounts.put(operationStats.getFailureString(), 1L);
			} else {
				failureStringCounts.put(operationStats.getFailureString(), failureStringCount++);
			}
		}
		
		if (responseTime < minResponseTime) {
			minResponseTime = responseTime;
		}
		if (responseTime > maxResponseTime) {
			maxResponseTime = responseTime;
		}
		
		totalSteps += operationStats.getTotalSteps();
		
		logger.info("addStats: added OperationStats = " + operationStats);
	}

	public void merge(OperationStatsSummary that) {
		this.operationIndex = that.operationIndex;
		this.operationName = that.operationName;
		
		this.totalNumOps += that.totalNumOps;
		this.totalNumRTOps += that.totalNumRTOps;
		this.totalNumFailedRT += that.totalNumFailedRT;
		this.totalNumFailed += that.totalNumFailed;
		for (String failureString : that.getFailureStringCounts().keySet()) {
			if (this.failureStringCounts.containsKey(failureString)) {
				this.failureStringCounts.put(failureString, 
						this.failureStringCounts.get(failureString) + that.getFailureStringCounts().get(failureString));
			} else {
				this.failureStringCounts.put(failureString, that.getFailureStringCounts().get(failureString));
			}
		}
		
		this.totalResponseTime += that.totalResponseTime;
		this.totalFailedResponseTime += that.totalFailedResponseTime;
		this.totalPassedResponseTime += that.totalPassedResponseTime;
		if (that.minResponseTime < this.minResponseTime) {
			this.minResponseTime = that.minResponseTime;
		}
		if (that.maxResponseTime > this.maxResponseTime) {
			this.maxResponseTime = that.maxResponseTime;
		}
		
		this.totalCycleTime += that.totalCycleTime;
		
		this.totalSteps += that.getTotalSteps();

		this.responseTimeLimit = that.responseTimeLimit;
		this.responseTimeLimitPercentile = that.responseTimeLimitPercentile;
		this.allowedFailurePercent = that.allowedFailurePercent;
		this.useResponseTime = that.useResponseTime;
		this.requiredMixPct = that.requiredMixPct;
		this.mixPctTolerance = that.mixPctTolerance;
	}

	public void reset() {
		this.totalNumOps = 0;
		this.totalNumRTOps = 0;
		this.totalNumFailedRT = 0;
		this.totalNumFailed = 0;
		this.totalCycleTime = 0;
		
		failureStringCounts.clear();
		
		this.totalResponseTime = 0;
		this.totalFailedResponseTime = 0;
		this.totalPassedResponseTime = 0;
		this.minResponseTime = Long.MAX_VALUE;
		this.maxResponseTime = Long.MIN_VALUE;
		
		this.totalSteps = 0;

		
	}

	public int getOperationIndex() {
		return operationIndex;
	}

	public void setOperationIndex(int operationIndex) {
		this.operationIndex = operationIndex;
	}

	public String getOperationName() {
		return operationName;
	}

	public void setOperationName(String operationName) {
		this.operationName = operationName;
	}

	public long getTotalNumOps() {
		return totalNumOps;
	}

	public void setTotalNumOps(long totalNumOps) {
		this.totalNumOps = totalNumOps;
	}

	public long getTotalNumFailedRT() {
		return totalNumFailedRT;
	}

	public void setTotalNumFailedRT(long totalNumFailedRT) {
		this.totalNumFailedRT = totalNumFailedRT;
	}

	public long getTotalNumFailed() {
		return totalNumFailed;
	}

	public void setTotalNumFailed(long totalNumFailed) {
		this.totalNumFailed = totalNumFailed;
	}

	public Map<String, Long> getFailureStringCounts() {
		return failureStringCounts;
	}

	public void setFailureStringCounts(Map<String, Long> failureStringCount) {
		this.failureStringCounts = failureStringCount;
	}

	public long getTotalResponseTime() {
		return totalResponseTime;
	}

	public void setTotalResponseTime(long totalResponseTime) {
		this.totalResponseTime = totalResponseTime;
	}

	public long getMinResponseTime() {
		return minResponseTime;
	}

	public void setMinResponseTime(long minResponseTime) {
		this.minResponseTime = minResponseTime;
	}

	public long getMaxResponseTime() {
		return maxResponseTime;
	}

	public void setMaxResponseTime(long maxResponseTime) {
		this.maxResponseTime = maxResponseTime;
	}

	public long getTotalSteps() {
		return totalSteps;
	}

	public void setTotalSteps(long totalSteps) {
		this.totalSteps = totalSteps;
	}

	public long getResponseTimeLimit() {
		return responseTimeLimit;
	}

	public void setResponseTimeLimit(long responseTimeLimit) {
		this.responseTimeLimit = responseTimeLimit;
	}

	public boolean isUseResponseTime() {
		return useResponseTime;
	}

	public void setUseResponseTime(boolean useResponseTime) {
		this.useResponseTime = useResponseTime;
	}

	public double getRequiredMixPct() {
		return requiredMixPct;
	}

	public void setRequiredMixPct(double requiredMixPct) {
		this.requiredMixPct = requiredMixPct;
	}

	public double getMixPctTolerance() {
		return mixPctTolerance;
	}

	public void setMixPctTolerance(double mixPctTolerance) {
		this.mixPctTolerance = mixPctTolerance;
	}

	public double getResponseTimeLimitPercentile() {
		return responseTimeLimitPercentile;
	}

	public void setResponseTimeLimitPercentile(double responseTimeLimitPercentile) {
		this.responseTimeLimitPercentile = responseTimeLimitPercentile;
	}

	public long getTotalFailedResponseTime() {
		return totalFailedResponseTime;
	}

	public void setTotalFailedResponseTime(long totalFailedResponseTime) {
		this.totalFailedResponseTime = totalFailedResponseTime;
	}

	public long getTotalPassedResponseTime() {
		return totalPassedResponseTime;
	}

	public void setTotalPassedResponseTime(long totalPassedResponseTime) {
		this.totalPassedResponseTime = totalPassedResponseTime;
	}

	public long getTotalNumRTOps() {
		return totalNumRTOps;
	}

	public void setTotalNumRTOps(long totalNumRTOps) {
		this.totalNumRTOps = totalNumRTOps;
	}

	public long getTotalCycleTime() {
		return totalCycleTime;
	}

	public void setTotalCycleTime(long totalCycleTime) {
		this.totalCycleTime = totalCycleTime;
	}

	public boolean passedRt() {
		if (!useResponseTime) {
			return true;
		} else {
			double passingPct = (getTotalNumOps() - getTotalNumFailedRT()) /(getTotalNumOps() * 1.0);
			if ((passingPct * 100) >= getResponseTimeLimitPercentile()) {
				return true;
			} else {
				return false;
			}
		}
	}

	public boolean passedFailurePercent() {
		double failedPct = getTotalNumFailed() / (getTotalNumOps() * 1.0);
		if (failedPct > allowedFailurePercent) {
			return false;
		} else {
			return true;
		}
	}
	
	public boolean passedMixPct(long overallNumOps) {		
		logger.debug("passedMixPct overallNumOps = " + overallNumOps);
		double pct = getTotalNumOps() / (overallNumOps * 1.0);
		double mixPct = getRequiredMixPct() / 100.0;
		double minLimit = mixPct - (mixPct * getMixPctTolerance());
		double maxLimit = mixPct + (mixPct * getMixPctTolerance());
		
		if ((pct < minLimit) || (pct > maxLimit)) {
			logger.debug("passedMixPct failed for operation " + operationName + ", requiredMixPct = "
					+ getRequiredMixPct() + ", mixTolerence = " + getMixPctTolerance() + ", pct = " 
					+ pct + ", mixPct = " + mixPct + ", minLimit = " + minLimit 
					+ ", maxLimit = " + maxLimit  + ", totalNumOps = " + getTotalNumOps()
					+ ", ovarallNumOps " + overallNumOps);
			return false;
		} else {
			logger.debug("passedMixPct passed for operation " + operationName + ", requiredMixPct = "
					+ getRequiredMixPct() + ", mixTolerence = " + getMixPctTolerance() + ", pct = " 
					+ pct + ", mixPct = " + mixPct + ", minLimit = " + minLimit 
					+ ", maxLimit = " + maxLimit  + ", totalNumOps = " + getTotalNumOps()
					+ ", ovarallNumOps " + overallNumOps);
			return true;
		}
		
	}

	public double getAllowedFailurePercent() {
		return allowedFailurePercent;
	}

	public void setAllowedFailurePercent(double allowedFailurePercent) {
		this.allowedFailurePercent = allowedFailurePercent;
	}

	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("OperationStatsSummary for OpName: " + operationName);
		retVal.append(", totalNumOps = " + totalNumOps);
		retVal.append(", totalNumRTOps = " + totalNumRTOps);
		retVal.append(", totalNumFailed = " + totalNumFailed);
		retVal.append(", totalNumFailedRT = " + totalNumFailedRT);
		retVal.append(", totalResponseTime = " + totalResponseTime);
		retVal.append(", totalFailedResponseTime = " + totalFailedResponseTime);
		retVal.append(", totalPassedResponseTime = " + totalPassedResponseTime);
		retVal.append(", minResponseTime = " + minResponseTime);
		retVal.append(", maxResponseTime = " + maxResponseTime);
		retVal.append(", totalCycleTime = " + totalCycleTime);
		retVal.append(", totalSteps = " + totalSteps);
		retVal.append(", responseTimeLimit = " + responseTimeLimit);
		retVal.append(", responseTimeLimitPercentile = " + responseTimeLimitPercentile);
		retVal.append(", allowedFailurePercent = " + allowedFailurePercent);
		retVal.append(", useResponseTime = " + useResponseTime);
		retVal.append(", requiredMixPct = " + requiredMixPct);
		retVal.append(", mixPctTolerance = " + mixPctTolerance);
		return retVal.toString();
	}
}

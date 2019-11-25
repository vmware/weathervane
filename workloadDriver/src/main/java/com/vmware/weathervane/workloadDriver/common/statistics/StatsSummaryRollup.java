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

import java.util.HashMap;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/*
 * Classes to hold aggregation of stats across all operations.  Used to avoid recalculating
 */
public class StatsSummaryRollup {
	
	private String intervalName = null;
	private double intervalDurationSec = 0;
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
	private long startActiveUsers = -1;
	private long endActiveUsers = -1;

	private Map<String, ComputedOpStatsSummary> computedOpStatsSummaries = new HashMap<String, ComputedOpStatsSummary>();
	private static final Logger logger = LoggerFactory.getLogger(StatsSummaryRollup.class);

	public void doRollup(StatsSummary statsSummary) {			
		logger.info("doRollup: workload " + statsSummary.getWorkloadName() 
			+ ", target " + statsSummary.getTargetName() 
			+ ", host " + statsSummary.getHostName() 
			+ ", statsIntervalSpec " + statsSummary.getStatsIntervalSpecName());
		setIntervalDurationSec((statsSummary.getIntervalEndTime() - statsSummary.getIntervalStartTime()) / 1000.0);
		startActiveUsers = statsSummary.getStartActiveUsers();
		endActiveUsers = statsSummary.getEndActiveUsers();
		intervalName = statsSummary.getIntervalName();
		
		/*
		 * First calculate the overall metrics.  We need these to calculate some of the 
		 * per-op metrics
		 */
		Map<String, OperationStatsSummary> opNameToStatsMap = statsSummary.getOpNameToStatsMap();
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			totalNumOps += opStatsSummary.getTotalNumOps();
			totalNumRTOps += opStatsSummary.getTotalNumRTOps();
			totalNumFailedRT += opStatsSummary.getTotalNumFailedRT();
			totalNumFailed += opStatsSummary.getTotalNumFailed();
			totalCycleTime += opStatsSummary.getTotalCycleTime();
			setTotalSteps(getTotalSteps() + opStatsSummary.getTotalSteps());
			totalRT += opStatsSummary.getTotalResponseTime();
		}
		
	
		long totalNumSucessfulOps = totalNumOps - totalNumFailed - totalNumFailedRT;

		throughput = totalNumOps / (1.0 * getIntervalDurationSec());
		setEffectiveThroughput(totalNumSucessfulOps / (1.0 * getIntervalDurationSec()));
		setStepsThroughput(totalSteps / (1.0 * getIntervalDurationSec()));
		if (totalNumRTOps > 0) {
			avgRT = (totalRT/1000.0) / (1.0 * totalNumRTOps);
		}
		
		if (totalNumOps > 0) {
			this.avgCycleTime = (totalCycleTime/1000.0)/(1.0 * totalNumOps);
		}
		
		if (totalNumOps > 0) {
			pctPassing = (totalNumOps - totalNumFailedRT) / (totalNumOps * 1.0);
		}
		
		/*
		 * Now compute the per-operation stats
		 */
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			ComputedOpStatsSummary computedOpStatsSummary = new ComputedOpStatsSummary();
			getComputedOpStatsSummaries().put(opName, computedOpStatsSummary);
			if (opStatsSummary.getRequiredMixPct() > 0) {
				computedOpStatsSummary.setSuccesses(opStatsSummary.getTotalNumOps() 
						- opStatsSummary.getTotalNumFailed() - opStatsSummary.getTotalNumFailedRT());
				computedOpStatsSummary.setFailures(opStatsSummary.getTotalNumFailed());
				computedOpStatsSummary.setRtFailures(opStatsSummary.getTotalNumFailedRT());
				computedOpStatsSummary.setPassedRt(opStatsSummary.passedRt());
				computedOpStatsSummary.setPassedFailurePct(opStatsSummary.passedFailurePercent());
				boolean passedMixPct = opStatsSummary.passedMixPct(totalNumOps);
				if (!passedMixPct) {
					logger.info("doRollup: workload " + statsSummary.getWorkloadName() 
					+ ", target " + statsSummary.getTargetName() 
					+ ", host " + statsSummary.getHostName() 
					+ ", statsIntervalSpec " + statsSummary.getStatsIntervalSpecName()
							+ ", " + opName + " failed mix pct for this period");
				}
				computedOpStatsSummary.setPassedMixPct(passedMixPct);

				boolean opPassed = computedOpStatsSummary.isPassedRt() 
						&& computedOpStatsSummary.isPassedMixPct() 
						&& computedOpStatsSummary.isPassedFailurePct();
				computedOpStatsSummary.setPassed(opPassed);
				setIntervalPassed(isIntervalPassed() && opPassed);
				setIntervalPassedRT(isIntervalPassedRT() && computedOpStatsSummary.isPassedRt());
				setIntervalPassedMix(isIntervalPassedMix() && computedOpStatsSummary.isPassedMixPct());
				setIntervalPassedFailure(isIntervalPassedFailure() && computedOpStatsSummary.isPassedFailurePct());
				computedOpStatsSummary.setThroughput(opStatsSummary.getTotalNumOps() / (1.0 * getIntervalDurationSec()));
				computedOpStatsSummary.setMixPct(opStatsSummary.getTotalNumOps() / (1.0 * totalNumOps));
				computedOpStatsSummary.setEffectiveThroughput(
						(opStatsSummary.getTotalNumOps() - opStatsSummary.getTotalNumFailedRT()) / (1.0 * getIntervalDurationSec()));
				long totalNumSucessfulRTOps = opStatsSummary.getTotalNumRTOps() - opStatsSummary.getTotalNumFailedRT();

				if (opStatsSummary.getTotalNumRTOps() > 0) {
					computedOpStatsSummary.setPassingPct(totalNumSucessfulRTOps / (1.0 * opStatsSummary.getTotalNumRTOps()));
				}

				if (opStatsSummary.isUseResponseTime()) {
					if (opStatsSummary.getTotalNumRTOps() > 0) {
						computedOpStatsSummary.setAvgRt((opStatsSummary.getTotalResponseTime() / 1000.0) / (1.0 * opStatsSummary.getTotalNumRTOps()));
					}
					if (opStatsSummary.getTotalNumFailedRT() > 0) {
						computedOpStatsSummary
								.setAvgFailedRt((opStatsSummary.getTotalFailedResponseTime() / 1000.0) / (1.0 * opStatsSummary.getTotalNumFailedRT()));
					}
					if ((opStatsSummary.getTotalNumRTOps() - opStatsSummary.getTotalNumFailedRT()) > 0) {
						computedOpStatsSummary
								.setAvgPassedRt((opStatsSummary.getTotalPassedResponseTime() / 1000.0) / 
										(1.0 * (opStatsSummary.getTotalNumRTOps() - opStatsSummary.getTotalNumFailedRT())));
					}
				}

				if (opStatsSummary.getTotalNumOps() > 0) {
					computedOpStatsSummary.setAvgCycleTime((opStatsSummary.getTotalCycleTime() / 1000.0) / (1.0 * opStatsSummary.getTotalNumOps()));
				}
				
				logger.info("For operation " + opName + " opStatsSummary = " + opStatsSummary
						+ ", computedOpStatsSummary = " + computedOpStatsSummary);
			}
		}
	}

	public String getIntervalName() {
		return intervalName;
	}

	public void setIntervalName(String intervalName) {
		this.intervalName = intervalName;
	}

	public long getTotalNumOps() {
		return totalNumOps;
	}

	public void setTotalNumOps(long totalNumOps) {
		this.totalNumOps = totalNumOps;
	}

	public long getTotalNumRTOps() {
		return totalNumRTOps;
	}

	public void setTotalNumRTOps(long totalNumRTOps) {
		this.totalNumRTOps = totalNumRTOps;
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

	public long getTotalRT() {
		return totalRT;
	}

	public void setTotalRT(long totalRT) {
		this.totalRT = totalRT;
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

	public double getAvgRT() {
		return avgRT;
	}

	public void setAvgRT(double avgRT) {
		this.avgRT = avgRT;
	}

	public long getTotalSteps() {
		return totalSteps;
	}

	public void setTotalSteps(long totalSteps) {
		this.totalSteps = totalSteps;
	}

	public double getStepsThroughput() {
		return stepsThroughput;
	}

	public void setStepsThroughput(double stepsThroughput) {
		this.stepsThroughput = stepsThroughput;
	}

	public double getPctPassing() {
		return pctPassing;
	}

	public void setPctPassing(double pctPassing) {
		this.pctPassing = pctPassing;
	}

	public boolean isIntervalPassed() {
		return intervalPassed;
	}

	public void setIntervalPassed(boolean intervalPassed) {
		this.intervalPassed = intervalPassed;
	}

	public ComputedOpStatsSummary getComputedOpStatsSummary(String opName) {
		return getComputedOpStatsSummaries().get(opName);
	}

	public double getIntervalDurationSec() {
		return intervalDurationSec;
	}

	public void setIntervalDurationSec(double intervalDurationSec) {
		this.intervalDurationSec = intervalDurationSec;
	}

	public boolean isIntervalPassedRT() {
		return intervalPassedRT;
	}

	public void setIntervalPassedRT(boolean intervalPassedRT) {
		this.intervalPassedRT = intervalPassedRT;
	}

	public boolean isIntervalPassedMix() {
		return intervalPassedMix;
	}

	public void setIntervalPassedMix(boolean intervalPassedMix) {
		this.intervalPassedMix = intervalPassedMix;
	}

	public double getAvgCycleTime() {
		return avgCycleTime;
	}

	public void setAvgCycleTime(double avgCycleTime) {
		this.avgCycleTime = avgCycleTime;
	}

	public long getTotalCycleTime() {
		return totalCycleTime;
	}

	public void setTotalCycleTime(long totalCycleTime) {
		this.totalCycleTime = totalCycleTime;
	}
	
	public long getStartActiveUsers() {
		return startActiveUsers;
	}

	public void setStartActiveUsers(long startActiveUsers) {
		this.startActiveUsers = startActiveUsers;
	}

	public long getEndActiveUsers() {
		return endActiveUsers;
	}

	public void setEndActiveUsers(long endActiveUsers) {
		this.endActiveUsers = endActiveUsers;
	}

	public Map<String, ComputedOpStatsSummary> getComputedOpStatsSummaries() {
		return computedOpStatsSummaries;
	}

	public void setComputedOpStatsSummaries(Map<String, ComputedOpStatsSummary> computedOpStatsSummaries) {
		this.computedOpStatsSummaries = computedOpStatsSummaries;
	}

	public boolean isIntervalPassedFailure() {
		return intervalPassedFailure;
	}

	public void setIntervalPassedFailure(boolean intervalPassedFailure) {
		this.intervalPassedFailure = intervalPassedFailure;
	}

	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("StatsSummaryRollup: intervalDurationSec = " + intervalDurationSec);
		retVal.append(", totalNumRTOps = " + totalNumRTOps);
		retVal.append(", totalNumFailed = " + totalNumFailed);
		retVal.append(", totalNumFailedRT = " + totalNumFailedRT);
		retVal.append(", totalSteps = " + totalSteps);
		retVal.append(", totalRT = " + totalRT);
		retVal.append(", totalCycleTime = " + totalCycleTime);
		retVal.append(", throughput = " + throughput);
		retVal.append(", effectiveThroughput = " + effectiveThroughput);
		retVal.append(", stepsThroughput = " + stepsThroughput);
		retVal.append(", avgRT = " + avgRT);
		retVal.append(", avgCycleTime = " + avgCycleTime);
		retVal.append(", pctPassing = " + pctPassing);
		retVal.append(", intervalPassed = " + intervalPassed);
		retVal.append(", intervalPassedRT = " + intervalPassedRT);
		retVal.append(", intervalPassedFailure = " + intervalPassedFailure);
		retVal.append(", intervalPassedMix = " + intervalPassedMix + ": ");
		
		for (String opName: getComputedOpStatsSummaries().keySet()) {
			ComputedOpStatsSummary opSummary = getComputedOpStatsSummaries().get(opName);
			retVal.append("ComputedSummary for " + opName + ": " + opSummary + "; ");
		}			
		
		return retVal.toString();
	}
	
}

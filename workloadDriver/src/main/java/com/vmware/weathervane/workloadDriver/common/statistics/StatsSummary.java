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

import java.math.RoundingMode;
import java.text.DecimalFormat;
import java.text.NumberFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;

public class StatsSummary {
	private static final Logger logger = LoggerFactory.getLogger(StatsSummary.class);

	private String workloadName = null;
	private String targetName = null;
	private String hostName = null;
	private String statsIntervalSpecName = null;
	
	private String intervalName = null;
	private Long intervalStartTime = null;
	private Long intervalEndTime = null;

	private long startActiveUsers = -1;
	private long endActiveUsers = -1;
	
	private Boolean printSummary = null;
	private Boolean printIntervals = null;
	private Boolean printCsv = null;
	
	private Map<String, OperationStatsSummary> opNameToStatsMap = new HashMap<String, OperationStatsSummary>();
	
	@JsonIgnore
	private StatsSummaryRollup statsSummaryRollup = null;
	
	public StatsSummary() {}
	
	public StatsSummary(String workloadName, List<Operation> operations, BehaviorSpec behaviorSpec,
							String targetName, String hostname, String statsIntervalSpecName) {
		this.workloadName = workloadName;
		this.targetName = targetName;
		this.hostName = hostname;
		this.statsIntervalSpecName = statsIntervalSpecName;
		
		/*
		 * Initialize the opNameToStatsMap so that we always have a summary 
		 * for stats for every op, even if there have been no instances
		 */
		for (Operation op : operations) {
			String operationName = op.getOperationName();
			int operationIndex = op.getOperationIndex();
			long rtLimit = behaviorSpec.getResponseTimeLimit(operationIndex);
			double rtLimitPctile = behaviorSpec.getResponseTimeLimitPercentile(operationIndex);
			boolean useRt = behaviorSpec.getUseResponseTime(operationIndex);
			double rqdMixPct = behaviorSpec.getMixPercentage(operationIndex);
			double mixTolerance = behaviorSpec.getMixPercentageTolerance();
			opNameToStatsMap.put(operationName,
					new OperationStatsSummary(operationName, operationIndex, rtLimit,
							rtLimitPctile, useRt, rqdMixPct, mixTolerance));

		}
	}

	public void addStats(OperationStats operationStats) {
		logger.debug("addStats: " + operationStats );

		/* 
		 * Adding stats invalidates any rollup
		 */
		statsSummaryRollup = null;
				
		String operationName = operationStats.getOperationName();
		OperationStatsSummary operationStatsSummary = opNameToStatsMap.get(operationName);
		operationStatsSummary.addStats(operationStats);
	}

	public StatsSummary merge(StatsSummary that) {
		logger.debug("merge: merging " + that + " into " + this);
		/* 
		 * merging stats invalidates any rollup
		 */
		statsSummaryRollup = null;

		if (this.workloadName == null) {
			this.workloadName = that.workloadName;
		}
		if (this.targetName == null) {
			this.targetName = that.targetName;
		}
		if (this.hostName == null) {
			this.hostName = that.hostName;
		}
		if (this.statsIntervalSpecName == null) {
			this.statsIntervalSpecName = that.statsIntervalSpecName;
		}
		if (this.intervalName == null) {
			this.intervalName = that.intervalName;
		}
		Set<String> allOpNames = new HashSet<String>();
		allOpNames.addAll(this.opNameToStatsMap.keySet());
		allOpNames.addAll(that.getOpNameToStatsMap().keySet());
		
		
		for (String opName : allOpNames) {
			if (!this.opNameToStatsMap.containsKey(opName)) {
				this.opNameToStatsMap.put(opName, new OperationStatsSummary());
			}

			if (that.getOpNameToStatsMap().containsKey(opName)) {
					this.opNameToStatsMap.get(opName).merge(that.getOpNameToStatsMap().get(opName));
			}
		}
		
		if (this.startActiveUsers == -1) {
			this.startActiveUsers = that.startActiveUsers;
		}
		
		if (this.endActiveUsers == -1) {
			this.endActiveUsers = that.endActiveUsers;
		}
		
		if (this.intervalStartTime == null) {
			this.intervalStartTime = that.intervalStartTime;
		}
		
		if (this.intervalEndTime == null) {
			this.intervalEndTime = that.intervalEndTime;
		}
		
		if (this.printSummary == null) {
			this.printSummary = that.printSummary;
		}
		
		if (this.printIntervals == null) {
			this.printIntervals = that.printIntervals;
		}

		if (this.printCsv == null) {
			this.printCsv = that.printCsv;
		}

		return this;
	}

	public void reset() {
		startActiveUsers = -1;
		endActiveUsers = -1;
		for (OperationStatsSummary summary : opNameToStatsMap.values()) {
			summary.reset();
		}
	}
	
	public Map<String, OperationStatsSummary> getOpNameToStatsMap() {
		return opNameToStatsMap;
	}

	public String getWorkloadName() {
		return workloadName;
	}

	public void setWorkloadName(String workloadName) {
		this.workloadName = workloadName;
	}

	public String getTargetName() {
		return targetName;
	}

	public void setTargetName(String targetName) {
		this.targetName = targetName;
	}

	public String getStatsIntervalSpecName() {
		return statsIntervalSpecName;
	}

	public void setStatsIntervalSpecName(String statsIntervalSpecName) {
		this.statsIntervalSpecName = statsIntervalSpecName;
	}

	public void setOpNameToStatsMap(Map<String, OperationStatsSummary> opNameToStatsMap) {
		this.opNameToStatsMap = opNameToStatsMap;
	}

	public Long getIntervalStartTime() {
		return intervalStartTime;
	}

	public void setIntervalStartTime(Long intervalStartTime) {
		this.intervalStartTime = intervalStartTime;
	}

	public Long getIntervalEndTime() {
		return intervalEndTime;
	}

	public void setIntervalEndTime(Long intervalEndTime) {
		this.intervalEndTime = intervalEndTime;
	}

	public void setEndActiveUsers(Long activeUsers) {
		this.endActiveUsers = activeUsers;
	}

	public Long getEndActiveUsers() {
		return endActiveUsers;
	}

	public void setStartActiveUsers(Long activeUsers) {
		this.startActiveUsers = activeUsers;
	}

	public Long getStartActiveUsers() {
		return startActiveUsers;
	}

	public Boolean getPrintSummary() {
		return printSummary;
	}

	public void setPrintSummary(Boolean printSummary) {
		this.printSummary = printSummary;
	}


	public Boolean getPrintIntervals() {
		return printIntervals;
	}

	public void setPrintIntervals(Boolean printIntervals) {
		this.printIntervals = printIntervals;
	}

	public Boolean getPrintCsv() {
		return printCsv;
	}

	public void setPrintCsv(Boolean printCsv) {
		this.printCsv = printCsv;
	}

	public String getIntervalName() {
		return intervalName;
	}

	public void setIntervalName(String intervalName) {
		this.intervalName = intervalName;
	}

	public String getHostName() {
		return hostName;
	}

	public void setHostName(String hostName) {
		this.hostName = hostName;
	}

	@JsonIgnore
	public String getStatsIntervalHeader(boolean includeWorkload) {
		String outputFormat = "|%10s|%10s|%8s|%8s|%8s|%8s|%8s|%25s| %s";
		if (includeWorkload) {
			outputFormat = "|%10s" + outputFormat;
		}
		StringBuilder retVal = new StringBuilder();
		if (includeWorkload) {
			retVal.append(String.format(outputFormat, "Time", "Workload", "Active", "TP", "Avg RT", "Ops", "Ops",
					"Ops", "Per Operation: Operation:Total/FailedRT(RT-Limit/AvgRT/AvgFailingRT)", "Timestamp\n"));
			retVal.append(String.format(outputFormat, "(sec)", "", "Users", "(ops/s)", "(sec)", "Total", "Failed", "Fail RT", "", ""));
		} else {
			retVal.append(String.format(outputFormat, "Time", "Active", "TP", "Avg RT", "Ops", "Ops", "Ops",
					"Per Operation: Operation:Total/FailedRT(RT-Limit/AvgRT/AvgFailingRT)", "Timestamp\n"));
			retVal.append(String.format(outputFormat, "(sec)", "Users", "(ops/s)", "(sec)", "Total", "Failed", "Fail RT", "", ""));
		}

		return retVal.toString();
	}

	@JsonIgnore
	public String getStatsIntervalLine(boolean includeWorkload) {
		logger.debug("getStatsIntervalLine for statsSummary:" + this);
		NumberFormat doubleFormat2 = new DecimalFormat( "#0.00" );
		NumberFormat doubleFormat3 = new DecimalFormat( "#0.000" );
		doubleFormat2.setRoundingMode(RoundingMode.HALF_UP);
		doubleFormat3.setRoundingMode(RoundingMode.HALF_UP);

		String outputFormat = "|%10s|%10s|%8s|%8s|%8s|%8s|%8s|%25s| %s";
		if (includeWorkload) {
			outputFormat = "|%10s" + outputFormat;
		}
		SimpleDateFormat dateFormatter = new SimpleDateFormat("MMM d,yyyy HH:mm:ss z");
		String timestamp = dateFormatter.format(new Date());

		/*
		 * If the data hasn't already been computed (e.g. when printing in some other format),
		 * then rollup the data.
		 */
		if (statsSummaryRollup == null) {
			statsSummaryRollup = new StatsSummaryRollup();
			statsSummaryRollup.doRollup(this);
			logger.info("getStatsIntervalLine rollup:" + statsSummaryRollup);
		}
		

		/*
		 * Compute the stats aggregated over all of the operations
		 */
		StringBuilder allOpString = new StringBuilder();
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);

			allOpString.append(opName + ":" + opStatsSummary.getTotalNumOps() + "/" + 
					opStatsSummary.getTotalNumFailedRT() + "(" + 
					opStatsSummary.getResponseTimeLimit() 
					+ "/" + doubleFormat3.format(statsSummaryRollup.getComputedOpStatsSummary(opName).getAvgRt())
					+ "/" + doubleFormat3.format(statsSummaryRollup.getComputedOpStatsSummary(opName).getAvgFailedRt())
					+ "), ");
		}

		String throughput = doubleFormat2.format(statsSummaryRollup.getThroughput());
		String avgRT = doubleFormat3.format(statsSummaryRollup.getAvgRT());
	
		String retVal = null;
		if (includeWorkload) {
			retVal = String.format(outputFormat, this.getIntervalName(),
					this.getWorkloadName(), endActiveUsers,
					throughput, avgRT, statsSummaryRollup.getTotalNumOps(), statsSummaryRollup.getTotalNumFailed(),
					statsSummaryRollup.getTotalNumFailedRT(), allOpString, timestamp);
		} else {
			retVal = String.format(outputFormat, this.getIntervalName(), endActiveUsers,
					throughput, avgRT, statsSummaryRollup.getTotalNumOps(), statsSummaryRollup.getTotalNumFailed(),
					statsSummaryRollup.getTotalNumFailedRT(), allOpString, timestamp);			
		}
		return retVal;
	}

	@JsonIgnore
	public String getStatsCsvHeader() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("Interval Start, Interval End, Duration (s), Interval, Workload, Target, StatsInterval, Host, Start Users, End Users, TP (ops/s), Effective TP (ops/s),  Avg RT (sec)," +
						"Ops Total, Ops Failed, Ops Fail RT");

		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			retVal.append(", " + opName + " TP");
			retVal.append(", " + opName + " Effective TP");
			retVal.append(", " + opName + " Total Ops");
			retVal.append(", " + opName + " Ops Failed");
			retVal.append(", " + opName + " Ops Failed RT");
			retVal.append(", " + opName + " Percent Passing");
			retVal.append(", " + opName + " Average RT");
			retVal.append(", " + opName + " Average Failing RT");
			retVal.append(", " + opName + " Average CycleTime");
		}

		return retVal.toString();
	}

	@JsonIgnore
	public String getStatsCsvLine() {
		
		/*
		 * If the data hasn't already been computed (e.g. when printing in some other format),
		 * then rollup the data.
		 */
		if (statsSummaryRollup == null) {
			statsSummaryRollup = new StatsSummaryRollup();
			statsSummaryRollup.doRollup(this);
			logger.debug("getStatsCsvLine rollup:" + statsSummaryRollup);
		}

		StringBuilder retVal = new StringBuilder();
		SimpleDateFormat dateFormatter = new SimpleDateFormat("MMM d yyyy HH:mm:ss z");
		retVal.append(dateFormatter.format(intervalStartTime) 
					+ ", " + dateFormatter.format(intervalStartTime) 
					+ ", " + statsSummaryRollup.getIntervalDurationSec()
					+ ", " + intervalName
					+ ", " + workloadName 
					+ ", " + targetName 
					+ ", " + statsIntervalSpecName 
					+ ", " + hostName
					+ ", " + startActiveUsers
					+ ", " + endActiveUsers
					);

		NumberFormat doubleFormat2 = new DecimalFormat( "#0.00" );
		NumberFormat doubleFormat3 = new DecimalFormat( "#0.000" );
		doubleFormat2.setRoundingMode(RoundingMode.HALF_UP);
		doubleFormat3.setRoundingMode(RoundingMode.HALF_UP);
		StringBuilder allOpString = new StringBuilder();
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			ComputedOpStatsSummary computedOpStatsSummary = statsSummaryRollup.getComputedOpStatsSummary(opName);
			
			String throughput = doubleFormat2.format(computedOpStatsSummary.getThroughput());
			String throughputPassing = doubleFormat2.format(computedOpStatsSummary.getEffectiveThroughput());
			String passingPct = doubleFormat2.format(computedOpStatsSummary.getPassingPct());
			String avgRT = doubleFormat3.format(computedOpStatsSummary.getAvgRt());
			String avgFailedRT = doubleFormat3.format(computedOpStatsSummary.getAvgFailedRt());
			String avgCycleTime = doubleFormat2.format(computedOpStatsSummary.getAvgCycleTime());

			allOpString.append(", " + throughput
					+ ", " + throughputPassing
					+ ", " + opStatsSummary.getTotalNumOps()
					+ ", " + opStatsSummary.getTotalNumFailed()
					+ ", " + opStatsSummary.getTotalNumFailedRT()
					+ ", " + passingPct
					+ ", " + avgRT
					+ ", " + avgFailedRT
					+ ", " + avgCycleTime
					);

		}

		String throughput = doubleFormat2.format(statsSummaryRollup.getThroughput());
		String throughputPassing = doubleFormat2.format(statsSummaryRollup.getEffectiveThroughput());
		String avgRT = doubleFormat3.format(statsSummaryRollup.getAvgRT());

		
		retVal.append(", " + throughput
				+ ", " + throughputPassing
				+ ", " + avgRT
				+ ", " + statsSummaryRollup.getTotalNumOps()
				+ ", " + statsSummaryRollup.getTotalNumFailed()
				+ ", " + statsSummaryRollup.getTotalNumFailedRT()
				+ allOpString.toString()
				);
		
		return retVal.toString();
	}
	

	@JsonIgnore
	public String getAggregatedStatsCsvHeader() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("Interval Start, Interval End, Duration (s), Interval, " +
						"Pass," +
						"TP (ops/s), Effective TP (ops/s),  Avg RT (sec)," +
						"Ops Total, Ops Failed, Ops Fail RT");

		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			retVal.append(", " + opName + " TP");
			retVal.append(", " + opName + " Effective TP");
			retVal.append(", " + opName + " Total Ops");
			retVal.append(", " + opName + " Ops Failed");
			retVal.append(", " + opName + " Ops Failed RT");
			retVal.append(", " + opName + " Percent Passing");
			retVal.append(", " + opName + " Average RT");
			retVal.append(", " + opName + " Average Failing RT");
			retVal.append(", " + opName + " Average CycleTime");
		}

		return retVal.toString();
	}

	@JsonIgnore
	public String getAggregatedStatsCsvLine() {
		NumberFormat doubleFormat0 = new DecimalFormat( "#0" );
		NumberFormat doubleFormat2 = new DecimalFormat( "#0.00" );
		NumberFormat doubleFormat3 = new DecimalFormat( "#0.000" );
		doubleFormat0.setRoundingMode(RoundingMode.HALF_UP);
		doubleFormat2.setRoundingMode(RoundingMode.HALF_UP);
		doubleFormat3.setRoundingMode(RoundingMode.HALF_UP);

		/*
		 * If the data hasn't already been computed (e.g. when printing in some other format),
		 * then rollup the data.
		 */
		if (statsSummaryRollup == null) {
			statsSummaryRollup = new StatsSummaryRollup();
			statsSummaryRollup.doRollup(this);
			logger.debug("getAggregatedStatsCsvLine rollup:" + statsSummaryRollup);
		}

		StringBuilder retVal = new StringBuilder();
		SimpleDateFormat dateFormatter = new SimpleDateFormat("MMM d yyyy HH:mm:ss z");
		retVal.append(dateFormatter.format(intervalStartTime) 
					+ ", " + dateFormatter.format(intervalStartTime) 
					+ ", " + doubleFormat0.format(statsSummaryRollup.getIntervalDurationSec())
					+ ", " + intervalName 
					);
		
		retVal.append(
				", " + statsSummaryRollup.isIntervalPassed()
				);		

		/*
		 * Compute the stats aggregated over all of the operations
		 */
		StringBuilder allOpString = new StringBuilder();
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			ComputedOpStatsSummary computedOpStatsSummary = statsSummaryRollup.getComputedOpStatsSummary(opName);
			
			String throughput = doubleFormat2.format(computedOpStatsSummary.getThroughput());
			String throughputPassing = doubleFormat2.format(computedOpStatsSummary.getEffectiveThroughput());
			String passingPct = doubleFormat2.format(computedOpStatsSummary.getPassingPct());
			String avgRT = doubleFormat3.format(computedOpStatsSummary.getAvgRt());
			String avgFailedRT = doubleFormat3.format(computedOpStatsSummary.getAvgFailedRt());
			String avgCycleTime = doubleFormat2.format(computedOpStatsSummary.getAvgCycleTime());

			allOpString.append(", " + throughput
					+ ", " + throughputPassing
					+ ", " + opStatsSummary.getTotalNumOps()
					+ ", " + opStatsSummary.getTotalNumFailed()
					+ ", " + opStatsSummary.getTotalNumFailedRT()
					+ ", " + passingPct
					+ ", " + avgRT
					+ ", " + avgFailedRT
					+ ", " + avgCycleTime
					);

		}

		String throughput = doubleFormat2.format(statsSummaryRollup.getThroughput());
		String throughputPassing = doubleFormat2.format(statsSummaryRollup.getEffectiveThroughput());
		String avgRT = doubleFormat3.format(statsSummaryRollup.getAvgRT());

		
		retVal.append(", " + throughput
				+ ", " + throughputPassing
				+ ", " + avgRT
				+ ", " + statsSummaryRollup.getTotalNumOps()
				+ ", " + statsSummaryRollup.getTotalNumFailed()
				+ ", " + statsSummaryRollup.getTotalNumFailedRT()
				+ allOpString.toString()
				);
		
		return retVal.toString();
	}
	
	@JsonIgnore
	public String getStatsSummary() {
		logger.debug("getStatsSummary for statsSummary:" + this);

		/*
		 * If the data hasn't already been computed (e.g. when printing in some other format),
		 * then rollup the data.
		 */
		if (statsSummaryRollup == null) {
			statsSummaryRollup = new StatsSummaryRollup();
			statsSummaryRollup.doRollup(this);
			logger.debug("getStatsSummary rollup:" + statsSummaryRollup);
		}

		StringBuilder retVal = new StringBuilder();
		SimpleDateFormat dateFormatter = new SimpleDateFormat("MMM d,yyyy HH:mm:ss z");
		NumberFormat doubleFormat2 = new DecimalFormat( "#0.00" );
		NumberFormat doubleFormat3 = new DecimalFormat( "#0.000" );
		doubleFormat2.setRoundingMode(RoundingMode.HALF_UP);
		doubleFormat3.setRoundingMode(RoundingMode.HALF_UP);
		
		String opLineOutputFormat = "|%24s|%8s|%7s|%10s|%11s|%14s|%14s|%14s|%11s|%11s|%11s|%8s|%10s|%9s|%13s|\n";

		String throughput = doubleFormat2.format(statsSummaryRollup.getThroughput());
		String stepsThroughput = doubleFormat2.format(statsSummaryRollup.getStepsThroughput());
		String throughputPassing = doubleFormat2.format(statsSummaryRollup.getEffectiveThroughput());
		String avgRT = doubleFormat3.format(statsSummaryRollup.getAvgRT());

		retVal.append("Interval: " + intervalName + "\n");
		retVal.append("\tPassed: " + statsSummaryRollup.isIntervalPassed() + "\n");
		retVal.append("\tPassed Response-Time: " + statsSummaryRollup.isIntervalPassedRT() + "\n");
		retVal.append("\tPassed Mix Percentage: " + statsSummaryRollup.isIntervalPassedMix() + "\n");
		retVal.append("\tActive users at start: " + startActiveUsers + "\n");
		retVal.append("\tActive users at end: " + endActiveUsers + "\n");
		retVal.append("\tThroughput: " + throughput + " ops/sec\n");
		retVal.append("\tEffective Throughput: " + throughputPassing + " ops/sec\n");
		retVal.append("\tAverage Response-Time: " + avgRT + " sec\n");
		retVal.append("\tTotal Operations: " + statsSummaryRollup.getTotalNumOps() + "\n");
		retVal.append("\tTotal operations failing response-time: " + statsSummaryRollup.getTotalNumFailedRT() + "\n");
		retVal.append("\tTotal failed Operations: " + statsSummaryRollup.getTotalNumFailed() + "\n");
		retVal.append("\tHttp Operation Throughput: " + stepsThroughput + " ops/sec\n");
		retVal.append("\tOverall passing percentage: " + doubleFormat2.format(statsSummaryRollup.getPctPassing() * 100.0) + "%\n");
		retVal.append("\tInterval Duration (seconds): " + doubleFormat2.format(statsSummaryRollup.getIntervalDurationSec()) + "\n");
		retVal.append("\tInterval Start Time: " + dateFormatter.format(new Date(this.getIntervalStartTime())) + "\n");
		retVal.append("\tInterval End Time: " + dateFormatter.format(new Date(this.getIntervalEndTime())) + "\n");
		retVal.append(String.format(opLineOutputFormat, "Operation", "Passed?", "Passed", "Passed", "Throughput", "Avg Response-",
				"Min Response-", "Max Response-", "Avg Cycle-", "Effective", "Mix", "Pass RT", "Total", "Total", "Total"));
		retVal.append(String.format(opLineOutputFormat, "Name", "", "RT?", "Mix Pct?", "(Ops/Sec)", "Time (Sec)"
				, "Time (Sec)", "Time (Sec)", "Time (Sec)", "Throughput", "Percentage", "Percent", "Ops", "Failures", "RT Failures"));
		
		for (String opName : opNameToStatsMap.keySet()) {
			OperationStatsSummary opStatsSummary = opNameToStatsMap.get(opName);
			ComputedOpStatsSummary computedOpStatsSummary = statsSummaryRollup.getComputedOpStatsSummary(opName);
			if (opStatsSummary.getTotalNumOps()  > 0) {
				retVal.append(String.format(opLineOutputFormat, opName, computedOpStatsSummary.isPassed(), computedOpStatsSummary.isPassedRt(),
						computedOpStatsSummary.isPassedMixPct(), doubleFormat2.format(computedOpStatsSummary.getThroughput()),
						doubleFormat3.format(computedOpStatsSummary.getAvgRt()), doubleFormat2.format(opStatsSummary.getMinResponseTime() / 1000.0),
						doubleFormat2.format(opStatsSummary.getMaxResponseTime() / 1000.0), 
						doubleFormat3.format(computedOpStatsSummary.getAvgCycleTime()),
						doubleFormat2.format(computedOpStatsSummary.getEffectiveThroughput()),
						doubleFormat2.format(computedOpStatsSummary.getMixPct() * 100),
						doubleFormat2.format(computedOpStatsSummary.getPassingPct() * 100),
						opStatsSummary.getTotalNumOps(), opStatsSummary.getTotalNumFailed(), opStatsSummary.getTotalNumFailedRT()
						));
			}
			
		}
		
		return retVal.toString();
	}
	
	public StatsSummaryRollup getStatsSummaryRollup() {
		if (statsSummaryRollup == null) {
			statsSummaryRollup = new StatsSummaryRollup();
			statsSummaryRollup.doRollup(this);
			logger.debug("getStatsSummaryRollup rollup:" + statsSummaryRollup);
		}

		return statsSummaryRollup;
	}

	@Override
	public String toString() {
		StringBuilder retVal = new StringBuilder();
		retVal.append("StatsSummary: workload = " + workloadName + ", target = " + targetName);
		retVal.append(", statsIntervalSpecName = " + statsIntervalSpecName);
		retVal.append(", intervalName = " + intervalName);
		retVal.append(", hostName = " + hostName);
		retVal.append(", intervalStartTime = " + intervalStartTime);
		retVal.append(", intervalEndTime = " + intervalEndTime);
		retVal.append(", printSummary = " + printSummary);
		retVal.append(", printIntervals = " + printIntervals);
		retVal.append(", printCsv = " + printCsv);
		for (OperationStatsSummary opSummary : opNameToStatsMap.values()) {
			retVal.append("; " + opSummary.toString());
		}
		
		return retVal.toString();
	}	

}

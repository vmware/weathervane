/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics.statsCollector;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath.LoadPath;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.OperationStats;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummary;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.StatsIntervalSpec;

public class PerTargetStatsCollector implements StatsCollector {
	private static final Logger logger = LoggerFactory.getLogger(PerTargetStatsCollector.class);

	private static final RestTemplate restTemplate = new RestTemplate();

	private String workloadName;
	
	private List<String> targetNames = null;
	
	private List<Operation> operations = null;
	
	private Map<String, Map<String, StatsSummary>> specNameToTargetToIntervalStatsMap 
									= new HashMap<String, Map<String, StatsSummary>>();
	
	private Map<String, StatsSummary> targetToCurrentStatsMap = new HashMap<String, StatsSummary>();
		
	private List<StatsIntervalSpec> statsIntervalSpecs = null;
	
	private BehaviorSpec behaviorSpec = null;
	
	private String masterHostName;
	private String localHostname;

	private String runName;

	private LoadPath loadPath;
	
	private ExecutorService executorService = null;
	
	public PerTargetStatsCollector(List<StatsIntervalSpec> statsIntervalSpecs, LoadPath loadPath, List<Operation> operations, String runName, String workloadName, String masterHostName, 
								String localHostname, BehaviorSpec behaviorSpec) {
		this.runName = runName;
		this.workloadName = workloadName;
		this.masterHostName = masterHostName;
		this.localHostname = localHostname;
		this.operations = operations;
		this.behaviorSpec = behaviorSpec;
		this.statsIntervalSpecs = statsIntervalSpecs;
		this.loadPath = loadPath;
		
		executorService = Executors.newCachedThreadPool();

		/*
		 * A collector gets a message for each interval it uses.  The
		 * message triggers the roll-up of stats for that interval
		 */
		for (StatsIntervalSpec spec : this.statsIntervalSpecs) {
			specNameToTargetToIntervalStatsMap.put(spec.getName(), new HashMap<String, StatsSummary>());			
		}
		specNameToTargetToIntervalStatsMap.put(loadPath.getName(), new HashMap<String, StatsSummary>());			
		
	}
	
	@Override
	public void submitOperationStats(OperationStats operationStats) {
		logger.debug("submitOperationStats: " + operationStats);
		String targetName = operationStats.getTargetName();
		
		StatsSummary currentStats = null;
		synchronized (targetToCurrentStatsMap) {
			if (!targetToCurrentStatsMap.containsKey(targetName)) {
				logger.debug("submitOperationStats: didn't have a targetToCurrentStats summary for target " + targetName);
				StatsSummary newStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec,
															targetName, localHostname, null);
				targetToCurrentStatsMap.put(targetName, newStatsSummary);
			}
			currentStats = targetToCurrentStatsMap.get(targetName);
		}
		currentStats.addStats(operationStats);
	}

	/**
	 * Roll the current stats for each target up into the interval stats for
	 * all intervalSpecs.
	 * For the intervalSpec that actually ended, send the rollup to the stats service
	 * on the master node and reset the stats.
	 */
	@Override
	public synchronized void statsIntervalComplete(StatsIntervalCompleteMessage completeMessage) {
		logger.debug("statsIntervalComplete: " + completeMessage);

		/*
		 * First take the current stats map and replace it with a fresh map so that we don't start
		 * counting results from the new interval
		 */
		Map<String, StatsSummary> curPeriodTargetToCurrentStatsMap = null;
		synchronized (targetToCurrentStatsMap) {
			logger.info("statsIntervalComplete: Swapping targetToCurrentStatsMap");
			curPeriodTargetToCurrentStatsMap = targetToCurrentStatsMap;
			targetToCurrentStatsMap = new HashMap<String, StatsSummary>();
			for (String targetName : targetNames) {
				StatsSummary newStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec,
																targetName, localHostname, null);
				targetToCurrentStatsMap.put(targetName, newStatsSummary);
			}

		}
		
		/*
		 * Now merge the current stats into every active interval
		 */
		for (String targetName : curPeriodTargetToCurrentStatsMap.keySet()) {
			logger.info("statsIntervalComplete: Merging curStats for target " + targetName); 
			StatsSummary curPeriodTargetStatsSummary = curPeriodTargetToCurrentStatsMap.get(targetName);

			for (StatsIntervalSpec spec : statsIntervalSpecs) {
				String specName = spec.getName();
				Map<String, StatsSummary> specTargetToCurrentStatsMap = specNameToTargetToIntervalStatsMap.get(specName);
				logger.info("statsIntervalComplete: Merging curStats for target " + targetName + 
						" into targetStats for spec " + specName);
				
				StatsSummary targetStatsSummary = specTargetToCurrentStatsMap.get(targetName);
				if (targetStatsSummary == null) {
					targetStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec,
													targetName, localHostname, specName);
					targetStatsSummary.setPrintSummary(spec.getPrintSummary());
					targetStatsSummary.setPrintIntervals(spec.getPrintIntervals());
					targetStatsSummary.setPrintCsv(spec.getPrintCsv());
					specTargetToCurrentStatsMap.put(targetName, targetStatsSummary);
					logger.info("statsIntervalComplete: Created a new StatsSummary for spec " + specName
							+ " and target " + targetName + ": " + targetStatsSummary);
				} 
				targetStatsSummary.merge(curPeriodTargetStatsSummary);
			}
			
			// Do the same thing for the loadPath intervals
			String loadPathName = loadPath.getName();
			Map<String, StatsSummary> specTargetToCurrentStatsMap = specNameToTargetToIntervalStatsMap.get(loadPathName);
			logger.info("statsIntervalComplete: Merging curStats for target " + targetName + 
					" into targetStats for spec " + loadPathName);
			
			StatsSummary targetStatsSummary = specTargetToCurrentStatsMap.get(targetName);
			if (targetStatsSummary == null) {
				targetStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec,
												targetName, localHostname, loadPathName);
				targetStatsSummary.setPrintSummary(loadPath.getPrintSummary());
				targetStatsSummary.setPrintIntervals(loadPath.getPrintIntervals());
				targetStatsSummary.setPrintCsv(loadPath.getPrintCsv());
				specTargetToCurrentStatsMap.put(targetName, targetStatsSummary);
				logger.info("statsIntervalComplete: Created a new StatsSummary for spec " + loadPathName
						+ " and target " + targetName + ": " + targetStatsSummary);
			} 
			targetStatsSummary.merge(curPeriodTargetStatsSummary);
		}
		
		/*
		 * For the spec that actually completed an interval, send the stats to the statsService
		 * and reset the collected stats
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		String completedSpecName = completeMessage.getCompletedSpecName();
		logger.info("Preparing to send target summaries for spec " + completedSpecName);
		List<Future<?>> sfList = new ArrayList<>();
		Map<String, StatsSummary> specTargetToCurrentStatsMap = specNameToTargetToIntervalStatsMap.get(completedSpecName);
		for (String targetName : specTargetToCurrentStatsMap.keySet()) {
			sfList.add(executorService.submit(
					new SendTargetSummaryRunner(specTargetToCurrentStatsMap.get(targetName), 
							requestHeaders, completedSpecName, targetName, completeMessage)));
		}
	}
	
	private class SendTargetSummaryRunner implements Runnable {
		private StatsSummary targetStatsSummary;
		private HttpHeaders requestHeaders;
		private String completedSpecName;
		private String targetName;
		private StatsIntervalCompleteMessage completeMessage;

		public SendTargetSummaryRunner(StatsSummary targetStatsSummary,
				HttpHeaders requestHeaders, String completedSpecName, String targetName,
				StatsIntervalCompleteMessage completeMessage) {
			this.targetStatsSummary = targetStatsSummary;
			this.requestHeaders = requestHeaders;
			this.completedSpecName = completedSpecName;
			this.targetName = targetName;
			this.completeMessage = completeMessage;
		}


		@Override
		public void run() {
			targetStatsSummary.setIntervalStartTime(completeMessage.getCurIntervalStartTime());
			targetStatsSummary.setIntervalEndTime(completeMessage.getLastIntervalEndTime());
			targetStatsSummary.setIntervalName(completeMessage.getCurIntervalName());
			targetStatsSummary.setEndActiveUsers(completeMessage.getIntervalEndUsers());
			targetStatsSummary.setStartActiveUsers(completeMessage.getIntervalStartUsers());

			logger.info("statsIntervalComplete: Sending target summary for spec " + completedSpecName
						+ " and target " + targetName + ", summary = " + targetStatsSummary);
			/*
			 * Send the stats summary
			 */
			HttpEntity<StatsSummary> statsEntity = new HttpEntity<StatsSummary>(targetStatsSummary, requestHeaders);
			String url = "http://" + masterHostName + "/stats/run/" + runName;
			logger.info("statsIntervalComplete: Sending target summary for spec " + completedSpecName
					+ " and target " + targetName + " to url " + url);

			ResponseEntity<BasicResponse> responseEntity 
					= restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting statsSummary to " + url);
			}

			logger.info("statsIntervalComplete: sent target summary for spec " + completedSpecName
					+ " and target " + targetName + ", summary = " + targetStatsSummary + ". Resetting stats");
			targetStatsSummary.reset();								
		}
		
	}
	
	@Override
	public void setTargetNames(List<String> targetNames) {
		this.targetNames = targetNames;
	}
	
	public String getWorkloadName() {
		return workloadName;
	}

	public void setWorkloadName(String workloadName) {
		this.workloadName = workloadName;
	}

	public String getLocalHostname() {
		return localHostname;
	}

	public void setLocalHostname(String localHostname) {
		this.localHostname = localHostname;
	}

	public List<String> getTargetNames() {
		return targetNames;
	}	

}

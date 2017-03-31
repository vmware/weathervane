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
import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import com.vmware.weathervane.workloadDriver.common.core.Operation;
import com.vmware.weathervane.workloadDriver.common.core.BehaviorSpec;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.statistics.statsIntervalSpec.StatsIntervalSpec;

public class StatsCollector implements StatsIntervalCompleteCallback {
	private static final Logger logger = LoggerFactory.getLogger(StatsCollector.class);

	private String workloadName;

	private List<String> targetNames = null;
	
	private List<Operation> operations = null;
	
	private Map<String, Map<String, StatsSummary>> specNameToTargetToIntervalStatsMap 
									= new HashMap<String, Map<String, StatsSummary>>();
	
	private Map<String, StatsSummary> targetToCurrentStatsMap = new HashMap<String, StatsSummary>();
		
	private Map<String, StatsIntervalSpec> statsIntervalSpecs = new HashMap<String, StatsIntervalSpec>();
	
	private BehaviorSpec behaviorSpec = null;
	
	private RestTemplate restTemplate = new RestTemplate();
	private String masterHostName;
	private int masterPortNumber;
	private String localHostname;
	
	public StatsCollector(List<StatsIntervalSpec> specs, List<Operation> operations, String workloadName, String masterHostName, 
								int masterPortNumber, String localHostname, BehaviorSpec behaviorSpec) {
		this.workloadName = workloadName;
		this.masterHostName = masterHostName;
		this.masterPortNumber = masterPortNumber;
		this.localHostname = localHostname;
		this.operations = operations;
		this.behaviorSpec = behaviorSpec;

		/*
		 * A collector registers a callback for each interval it uses.  The
		 * callback triggers the roll-up of stats for that interval
		 */
		for (StatsIntervalSpec spec : specs) {
			String specName =  spec.getName();
			logger.debug("StatsCollector registerStatsIntervalCompleteCallback for statsIntervalSpec " + specName);
			spec.registerStatsIntervalCompleteCallback(this);
			specNameToTargetToIntervalStatsMap.put(specName, new HashMap<String, StatsSummary>());
			
			/*
			 * Save the info about the specs
			 */
			statsIntervalSpecs.put(specName, spec);
		}
		
	}
	
	
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
	public synchronized void statsIntervalComplete(StatsIntervalSpec statsIntervalSpec) {
		logger.debug("statsIntervalComplete: " + statsIntervalSpec);

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

			for (String specName : specNameToTargetToIntervalStatsMap.keySet()) {
				Map<String, StatsSummary> specTargetToCurrentStatsMap = specNameToTargetToIntervalStatsMap.get(specName);
				logger.info("statsIntervalComplete: Merging curStats for target " + targetName + 
						" into targetStats for spec " + specName);
				
				StatsSummary targetStatsSummary = specTargetToCurrentStatsMap.get(targetName);
				if (targetStatsSummary == null) {
					targetStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec,
													targetName, localHostname, specName);
					targetStatsSummary.setPrintSummary(statsIntervalSpecs.get(specName).getPrintSummary());
					targetStatsSummary.setPrintIntervals(statsIntervalSpecs.get(specName).getPrintIntervals());
					targetStatsSummary.setPrintCsv(statsIntervalSpecs.get(specName).getPrintCsv());
					specTargetToCurrentStatsMap.put(targetName, targetStatsSummary);
					logger.info("statsIntervalComplete: Created a new StatsSummary for spec " + specName
							+ " and target " + targetName + ": " + targetStatsSummary);
				} 
				targetStatsSummary.merge(curPeriodTargetStatsSummary);
			}
		}
		
		/*
		 * For the spec that actually completed an interval, send the stats to the statsService
		 * and reset the collected stats
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		String completedSpecName = statsIntervalSpec.getName();
		logger.info("Preparing to send target summaries for spec " + completedSpecName);
		Map<String, StatsSummary> specTargetToCurrentStatsMap = specNameToTargetToIntervalStatsMap.get(completedSpecName);
		for (String targetName : specTargetToCurrentStatsMap.keySet()) {

			StatsSummary targetStatsSummary = specTargetToCurrentStatsMap.get(targetName);
			targetStatsSummary.setIntervalStartTime(statsIntervalSpec.getCurIntervalStartTime());
			targetStatsSummary.setIntervalEndTime(statsIntervalSpec.getLastIntervalEndTime());
			targetStatsSummary.setIntervalName(statsIntervalSpec.getCurIntervalName());

			logger.info("statsIntervalComplete: Sending target summary for spec " + completedSpecName
					+ " and target " + targetName + ", summary = " + targetStatsSummary);

			/*
			 * Send the stats summary
			 */
			HttpEntity<StatsSummary> statsEntity = new HttpEntity<StatsSummary>(targetStatsSummary, requestHeaders);
			String url = "http://" + masterHostName + ":" + masterPortNumber + "/stats";
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

	private void initializeTargetToCurrentStatsMap(List<String> targetNames) {
		logger.debug("initializeTargetToCurrentStatsMap");
		synchronized (targetToCurrentStatsMap) {
			targetToCurrentStatsMap.clear();
			for (String targetName : targetNames) {
				logger.debug("initializeTargetToCurrentStatsMap: adding stats summary for target " + targetName);
				StatsSummary newStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec, 
													targetName, localHostname, null);
				targetToCurrentStatsMap.put(targetName, newStatsSummary);
			}
		}		
	}
	
	public void setTargetNames(List<String> targetNames) {
		this.targetNames = targetNames;
		initializeTargetToCurrentStatsMap(targetNames);
	}
	

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics.statsCollector;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.locks.ReentrantReadWriteLock;

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

public class PerWorkloadStatsCollector implements StatsCollector {
	private static final Logger logger = LoggerFactory.getLogger(PerWorkloadStatsCollector.class);

	private static final RestTemplate restTemplate = new RestTemplate();

	private String workloadName;
	
	private List<String> targetNames = null;
	
	private List<Operation> operations = null;
	
	ReentrantReadWriteLock curStatsRWLock = new ReentrantReadWriteLock(true);
	private List<OperationStats> curStatsList = new ArrayList<>();
	
	private Map<String, StatsSummary> specNameToIntervalStatsMap = new HashMap<String, StatsSummary>();
	
	private List<StatsIntervalSpec> statsIntervalSpecs = null;
	
	private BehaviorSpec behaviorSpec = null;
	
	private String masterHostName;
	private String localHostname;

	private String runName;

	private LoadPath loadPath;
		
	public PerWorkloadStatsCollector(List<StatsIntervalSpec> statsIntervalSpecs, LoadPath loadPath, List<Operation> operations, String runName, String workloadName, String masterHostName, 
								String localHostname, BehaviorSpec behaviorSpec) {
		this.runName = runName;
		this.workloadName = workloadName;
		this.masterHostName = masterHostName;
		this.localHostname = localHostname;
		this.operations = operations;
		this.behaviorSpec = behaviorSpec;
		this.statsIntervalSpecs = statsIntervalSpecs;
		this.loadPath = loadPath;
				
		/*
		 * A collector gets a message for each interval it uses.  The
		 * message triggers the roll-up of stats for that interval.  Intervals
		 * include those for each StatsCollector, as well as the intervals defined
		 * by the LoadPath.
		 */
		for (StatsIntervalSpec spec : this.statsIntervalSpecs) {
			StatsSummary specStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec, 
					"all", localHostname, spec.getName());
			specStatsSummary.setPrintSummary(spec.getPrintSummary());
			specStatsSummary.setPrintIntervals(spec.getPrintIntervals());
			specStatsSummary.setPrintCsv(spec.getPrintCsv());
			specNameToIntervalStatsMap.put(spec.getName(), specStatsSummary);
		}
		StatsSummary lpStatsSummary = new StatsSummary(workloadName, operations, behaviorSpec, 
				"all", localHostname, loadPath.getName());
		lpStatsSummary.setPrintSummary(loadPath.getPrintSummary());
		lpStatsSummary.setPrintIntervals(loadPath.getPrintIntervals());
		lpStatsSummary.setPrintCsv(loadPath.getPrintCsv());		
		specNameToIntervalStatsMap.put(loadPath.getName(),lpStatsSummary);		
	}
	
	@Override
	public void submitOperationStats(OperationStats operationStats) {
		logger.debug("submitOperationStats: " + operationStats);
		
		/*
		 * Add the operationStats to the list of current stats for this period.
		 * The read lock prevents the list from being replaced while this sample
		 * is added.  The list is replaced when a statsInterval completes.
		 */
		curStatsRWLock.readLock().lock();
		logger.debug("submitOperationStats locked readLock: " + operationStats);
		try {
			if (operationStats != null) {
				curStatsList.add(operationStats);
			} else {
				logger.warn("submitOperationStats for workload {}, received null operationStats", workloadName);
			}
		} finally {
			curStatsRWLock.readLock().unlock();
			logger.debug("submitOperationStats unlocked readLock: " + operationStats);
		}
	}

	/**
	 * Roll the current stats for each target up into the interval stats for
	 * all intervalSpecs.
	 * For the intervalSpec that actually ended, send the rollup to the stats service
	 * on the master node and reset the stats.
	 */
	@Override
	public synchronized void statsIntervalComplete(StatsIntervalCompleteMessage completeMessage) {
		logger.info("statsIntervalComplete for workload {}: {}", workloadName, completeMessage);

		/*
		 * First take the current stats list and replace it with a fresh list so that we don't start
		 * counting results from the new interval
		 */
		List<OperationStats> curPeriodOpStats;
		curStatsRWLock.writeLock().lock();
		logger.info("statsIntervalComplete: Got writeLock" + completeMessage);
		try {
			curPeriodOpStats = curStatsList;
			curStatsList = new ArrayList<>();
		} finally {
			curStatsRWLock.writeLock().unlock();
		}
		logger.info("statsIntervalComplete: Released writeLock" + completeMessage);

		/*
		 * Compute a StatsSummary for the operationStats in this interval, ignoring
		 * operations that started before this interval or ended after.
		 */
		logger.info("statsIntervalComplete processing curPeriodOpStats.  Number of samples is {}", curPeriodOpStats.size());
		long intervalStartTime = completeMessage.getCurIntervalStartTime();
		long intervalEndTime = completeMessage.getLastIntervalEndTime();
		StatsSummary curIntervalStatsSummary = 
				new StatsSummary(workloadName, operations, behaviorSpec, "all", localHostname, "");
		for (OperationStats operationStats : curPeriodOpStats) {
			if (operationStats == null) {
				logger.warn("statsIntervalComplete: caught null operationStats.");
				continue;
			}
			curIntervalStatsSummary.addStats(operationStats);
		}

		/*
		 * Now merge the current stats into every active statsInterval
		 */
		for (StatsIntervalSpec spec : statsIntervalSpecs) {
			String specName = spec.getName();
			StatsSummary specStats = specNameToIntervalStatsMap.get(specName);
			logger.info("statsIntervalComplete: Merging curStats into stats for spec " + specName);
			specStats.merge(curIntervalStatsSummary);
		}

		// Do the same thing for the loadPath interval
		String loadPathName = loadPath.getName();
		StatsSummary lpStats = specNameToIntervalStatsMap.get(loadPathName);
		logger.info("statsIntervalComplete: Merging curStats into stats for loadPath " + loadPathName);
		lpStats.merge(curIntervalStatsSummary);
		
		/*
		 * For the spec that actually completed an interval, send the stats to the statsService
		 * and reset the collected stats
		 */
		String completedSpecName = completeMessage.getCompletedSpecName();
		StatsSummary completedStats = specNameToIntervalStatsMap.get(completedSpecName);
		completedStats.setIntervalStartTime(intervalStartTime);
		completedStats.setIntervalEndTime(intervalEndTime);
		completedStats.setIntervalName(completeMessage.getCurIntervalName());
		completedStats.setEndActiveUsers(completeMessage.getIntervalEndUsers());
		completedStats.setStartActiveUsers(completeMessage.getIntervalStartUsers());
		completedStats.setHostName(localHostname);
		
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);
		HttpEntity<StatsSummary> statsEntity = new HttpEntity<StatsSummary>(completedStats, requestHeaders);
		String url = "http://" + masterHostName + "/stats/run/" + runName;
		logger.info("statsIntervalComplete: Sending target summary for spec " + completedSpecName
				+ " to url " + url);

		boolean succeeded = false;
		int tries = 5;
		while (!succeeded && (tries > 0)) {
			ResponseEntity<BasicResponse> responseEntity = null;
			try {
				tries--;
				logger.debug("statsIntervalComplete: Starting HTTP Post to {}", url);
				responseEntity = restTemplate.exchange(url, HttpMethod.POST, statsEntity, BasicResponse.class);
				logger.debug("statsIntervalComplete: Completed HTTP Post to {}", url);
			} catch (Throwable t) {
					logger.warn("statsIntervalComplete: Got throwable when posting to url {}: {}", 
							url, t.getMessage());
					if (tries == 0) {
						// Give up and rethrow the exception
						throw t;
					}
			}
			
			if (responseEntity != null) {
				BasicResponse response = responseEntity.getBody();
				if (responseEntity.getStatusCode() != HttpStatus.OK) {
					logger.warn("Error sending stats message to " + url);
				} else {
					succeeded = true;
				}
			}
		}

		logger.info("statsIntervalComplete: sent summary for spec " + completedSpecName + " to url " + url + ". Resetting stats");
		completedStats.reset();								
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

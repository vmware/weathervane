/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.statistics;

import java.io.BufferedWriter;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.Writer;
import java.util.ArrayDeque;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Queue;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.workloadDriver.common.representation.InitializeRunStatsMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryResponseMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryRollupResponseMessage;

@Service
public class StatsServiceImpl implements StatsService {
	private static final Logger logger = LoggerFactory.getLogger(StatsServiceImpl.class);

	private long curPeriod = 0;
	
	private Map<String, List<String>> runNameToHostsListMap = new HashMap<>();
	private Map<String, String> runNameToStatsOutputDirName = new HashMap<>();
	private Map<String, Map<String, Integer>> runNameToWorkloadNameToNumTargetsMap = new HashMap<>();
	private Map<String, Boolean> runNameToIsPerTargetStatsMap = new HashMap<>();

	/*
	 * Writers for csv files.
	 * workload -> (statsIntervalSpec -> Writer)
	 */
	private Map<String, Map<String, Writer>> workloadAllSamplesCsvWriters 
										= new HashMap<String, Map<String, Writer>>();
	private Map<String, Map<String, Writer>> workloadAggregatedCsvWriters 
		= new HashMap<String, Map<String, Writer>>();
	private Map<String, Map<String, Writer>> workloadSummaryWriters 
		= new HashMap<String, Map<String, Writer>>();
	
	/**
	 * Overall aggregated stats
	 * workload -> (intervalSpec -> (intervalName -> StatsSummary))
	 */
	private Map<String, Map<String, Map<String, StatsSummary>>> aggregatedStatsSummaries 
							= new HashMap<String, Map<String, Map<String, StatsSummary>>>();
	
	/**
	 * The number of samples that we have received for each workload for each stats 
	 * spec and interval.
	 * workload -> (intervalSpec -> (intervalName -> receivedSampleCount))
	 */
	private Map<String, Map<String, Map<String, Integer>>>  receivedSamplesPerSpecAndInterval 
												= new HashMap<String, Map<String, Map<String, Integer>>>(); 
	
	private Map<String, Boolean> statsIntervalSpecPrintSummary = new HashMap<String, Boolean>();
	
	private Map<String, Map<String, Queue<String>>> workloadToStatsSpecToIntervalOrder = new HashMap<String, Map<String, Queue<String>>>();

	
	@Override
	public synchronized void postStatsSummary(String runName, StatsSummary statsSummary) throws IOException {
		String workloadName = statsSummary.getWorkloadName();
		String statsIntervalSpecName = statsSummary.getStatsIntervalSpecName();
		String intervalName = statsSummary.getIntervalName();
		String targetName = statsSummary.getTargetName();
		logger.info("postStatsSummary for runName = " + runName + ", workloadName = " + workloadName +
				", targetName = " + targetName + ", specName = " + statsIntervalSpecName + ", intervalName = " + intervalName);
		boolean isPerTarget = runNameToIsPerTargetStatsMap.get(runName);
		Map<String, Integer> workloadNameToNumTargetsMap = runNameToWorkloadNameToNumTargetsMap.get(runName);
		
		if (statsSummary.getPrintSummary()) {
			/*
			 * Store the interval name so that we can print the intervals out in
			 * the order that they occurred
			 */
			Map<String, Queue<String>> statsSpecToIntervalOrder = workloadToStatsSpecToIntervalOrder.get(workloadName);
			if (statsSpecToIntervalOrder == null) {
				statsSpecToIntervalOrder = new HashMap<String, Queue<String>>();
				logger.debug("postStatsSummary: Creating new statsSpecToIntervalOrder for workload " + workloadName);
				workloadToStatsSpecToIntervalOrder.put(workloadName, statsSpecToIntervalOrder);
			}
			Queue<String> intervalOrderQueue = statsSpecToIntervalOrder.get(statsIntervalSpecName);
			if (intervalOrderQueue == null) {
				intervalOrderQueue = new ArrayDeque<String>();
				logger.debug("postStatsSummary: Creating new intervalOrderQueue for statsIntervalSpec " + statsIntervalSpecName);
				statsSpecToIntervalOrder.put(statsIntervalSpecName, intervalOrderQueue);
			}
			if ((!intervalName.equals(intervalOrderQueue.peek())) && (!intervalOrderQueue.contains(intervalName))) {
				logger.debug("postStatsSummary: Adding interval name " + intervalName + " to intervalOrderQueue for workload " + workloadName
						+ " and statsIntervalSpec " + statsIntervalSpecName);
				intervalOrderQueue.add(intervalName);
			}
		}

		if (statsSummary.getPrintIntervals() || statsSummary.getPrintCsv() || statsSummary.getPrintSummary()) {		
			/*
			 * Aggregate the stats 
			 */
			Map<String, Map<String, StatsSummary>> workloadAggregatedStats = aggregatedStatsSummaries.get(workloadName);
			Map<String, Map<String, Integer>> workloadSamplesReceived = receivedSamplesPerSpecAndInterval.get(workloadName);
			if (workloadAggregatedStats == null) {
				workloadAggregatedStats = new HashMap<String, Map<String, StatsSummary>>();
				aggregatedStatsSummaries.put(workloadName, workloadAggregatedStats);
				
				workloadSamplesReceived = new HashMap<String, Map<String, Integer>>();
				receivedSamplesPerSpecAndInterval.put(workloadName, workloadSamplesReceived);
			}
			
			Map<String, StatsSummary> specAggregatedStats = workloadAggregatedStats.get(statsIntervalSpecName);
			Map<String, Integer> specSamplesReceived = workloadSamplesReceived.get(statsIntervalSpecName);
			if (specAggregatedStats == null) {
				specAggregatedStats = new HashMap<String, StatsSummary>();
				workloadAggregatedStats.put(statsIntervalSpecName, specAggregatedStats);
				specSamplesReceived = new HashMap<String, Integer>();
				workloadSamplesReceived.put(statsIntervalSpecName, specSamplesReceived);
			}
			StatsSummary intervalAggregatedStats = specAggregatedStats.get(intervalName);
			Integer intervalSamplesReceived = specSamplesReceived.get(intervalName);
			if (intervalAggregatedStats == null) {
				intervalAggregatedStats = new StatsSummary();
				specAggregatedStats.put(intervalName, statsSummary);
				intervalSamplesReceived = new Integer(0);
			}
			
			/* 
			 * Merge in the new sample
			 */
			intervalAggregatedStats.merge(statsSummary);
			intervalSamplesReceived += 1;
			specSamplesReceived.put(intervalName, intervalSamplesReceived);
			
			/*
			 * Check whether we have received all of the samples for this interval.
			 * If isPerTarget is true, then we should have received numHosts * workload->numTargets
			 * otherwise, we just need to receive numHosts samples 
			 */
			List<String> hosts = runNameToHostsListMap.get(runName);
			int numSamplesExpected = hosts.size();
			if (isPerTarget) {
				numSamplesExpected *= workloadNameToNumTargetsMap.get(workloadName);
			}
			String statsOutputDirName = runNameToStatsOutputDirName.get(runName);
			if (intervalSamplesReceived < numSamplesExpected) {
				logger.debug("postStatsSummary: This is sample " + intervalSamplesReceived + ". Haven't received all samples for workload " + workloadName
						+ ", statsIntervalSpec " + statsIntervalSpecName + ", and interval " + intervalName);
				/*
				 * Haven't received all of the samples. If printCsv is true,
				 * print the summary line to the allSamples file
				 */
				if (statsSummary.getPrintCsv()) {
					Map<String, Writer> specToAllSamplesWriterMap = workloadAllSamplesCsvWriters.get(workloadName);
					if (specToAllSamplesWriterMap == null) {
						specToAllSamplesWriterMap = new HashMap<String, Writer>();
						workloadAllSamplesCsvWriters.put(workloadName, specToAllSamplesWriterMap);
					}
					Writer allSamplesWriter = specToAllSamplesWriterMap.get(statsIntervalSpecName);
					if (allSamplesWriter == null) {
						allSamplesWriter = new BufferedWriter(new OutputStreamWriter(
								new FileOutputStream(statsOutputDirName + "/" + workloadName + "-" + statsIntervalSpecName + "-allSamples.csv"), "utf-8"));
						specToAllSamplesWriterMap.put(statsIntervalSpecName, allSamplesWriter);
						allSamplesWriter.write(statsSummary.getStatsCsvHeader() + "\n");
					}
					allSamplesWriter.write(statsSummary.getStatsCsvLine() + "\n");
				}
				
			} else {
				logger.debug("postStatsSummary: This is sample " + intervalSamplesReceived + ". Received all samples for workload " + workloadName
						+ ", statsIntervalSpec " + statsIntervalSpecName 
						+ ", and interval " + intervalName);
				
				if (intervalAggregatedStats.getPrintCsv()) {
					Map<String, Writer> specToAllSamplesWriterMap = workloadAllSamplesCsvWriters.get(workloadName);
					if (specToAllSamplesWriterMap == null) {
						specToAllSamplesWriterMap = new HashMap<String, Writer>();
						workloadAllSamplesCsvWriters.put(workloadName, specToAllSamplesWriterMap);
					}
					Writer allSamplesWriter = specToAllSamplesWriterMap.get(statsIntervalSpecName);
					if (allSamplesWriter == null) {
						allSamplesWriter = new BufferedWriter(new OutputStreamWriter(
								new FileOutputStream(statsOutputDirName + "/" + workloadName + "-" + statsIntervalSpecName + "-allSamples.csv"), "utf-8"));
						specToAllSamplesWriterMap.put(statsIntervalSpecName, allSamplesWriter);
						allSamplesWriter.write(statsSummary.getStatsCsvHeader() + "\n");
					}
					allSamplesWriter.write(statsSummary.getStatsCsvLine() + "\n");

					Map<String, Writer> specToAggregatedWriterMap = workloadAggregatedCsvWriters.get(workloadName);
					if (specToAggregatedWriterMap == null) {
						specToAggregatedWriterMap = new HashMap<String, Writer>();
						workloadAggregatedCsvWriters.put(workloadName, specToAggregatedWriterMap);
					}
					Writer aggregatedWriter = specToAggregatedWriterMap.get(statsIntervalSpecName);
					if (aggregatedWriter == null) {
						aggregatedWriter = new BufferedWriter(new OutputStreamWriter(
								new FileOutputStream(statsOutputDirName + "/" + workloadName + "-" + statsIntervalSpecName + ".csv"), "utf-8"));
						aggregatedWriter.write(intervalAggregatedStats.getAggregatedStatsCsvHeader() + "\n");
						specToAggregatedWriterMap.put(statsIntervalSpecName, aggregatedWriter);
					}
					aggregatedWriter.write(intervalAggregatedStats.getAggregatedStatsCsvLine() + "\n");
				}

				if (intervalAggregatedStats.getPrintIntervals()) {

					boolean includeWorkload = true;
					if (workloadNameToNumTargetsMap.keySet().size() == 1) {
						includeWorkload = false;
					}
					if (((curPeriod % 20) == 0) || (curPeriod == 0)) {
						System.out.println(intervalAggregatedStats.getStatsIntervalHeader(includeWorkload));
					}

					System.out.println(intervalAggregatedStats.getStatsIntervalLine(includeWorkload));			
					curPeriod++;
				}
				
				if (!statsSummary.getPrintSummary()) {
					/*
					 * Don't need to save this aggregate for an end-of-run summary, so
					 * clean up
					 */
					specAggregatedStats.remove(intervalName);
					specSamplesReceived.remove(intervalName);
					statsIntervalSpecPrintSummary.put(statsIntervalSpecName, false);
				} else {
					statsIntervalSpecPrintSummary.put(statsIntervalSpecName, true);
					
					Map<String, Writer> specToSummaryWriterMap = workloadSummaryWriters.get(workloadName);
					if (specToSummaryWriterMap == null) {
						specToSummaryWriterMap = new HashMap<String, Writer>();
						workloadSummaryWriters.put(workloadName, specToSummaryWriterMap);
					}
					Writer summaryWriter = specToSummaryWriterMap.get(statsIntervalSpecName);
					if (summaryWriter == null) {
						summaryWriter = new BufferedWriter(new OutputStreamWriter(
								new FileOutputStream(statsOutputDirName + "/" + workloadName + "-" + statsIntervalSpecName + "-summary.txt"), "utf-8"));
						specToSummaryWriterMap.put(statsIntervalSpecName, summaryWriter);
					}
					summaryWriter.write(intervalAggregatedStats.getStatsSummary() + "\n");
					summaryWriter.flush();

				}

			}
			
		}
				
	}

	@Override
	public StatsSummaryResponseMessage getStatsSummary(String runName, String workloadName, String specName,
			String intervalName) {
		boolean isPerTarget = runNameToIsPerTargetStatsMap.get(runName);
		int numSamplesExpected = runNameToHostsListMap.get(runName).size();
		if (isPerTarget) {
			numSamplesExpected *= runNameToWorkloadNameToNumTargetsMap.get(runName).get(workloadName);
		}

		StatsSummaryResponseMessage statsSummaryResponseMessage = new StatsSummaryResponseMessage();
		statsSummaryResponseMessage.setNumSamplesExpected(numSamplesExpected);
		statsSummaryResponseMessage.setNumSamplesReceived(0);
		statsSummaryResponseMessage.setStatsSummary(null);
		
		Map<String, Map<String, StatsSummary>> workloadAggregatedStats = aggregatedStatsSummaries.get(workloadName);
		Map<String, Map<String, Integer>> workloadSamplesReceived = receivedSamplesPerSpecAndInterval.get(workloadName);
		if (workloadAggregatedStats != null) {
			Map<String, StatsSummary> specAggregatedStats = workloadAggregatedStats.get(specName);
			Map<String, Integer> specSamplesReceived = workloadSamplesReceived.get(specName);
			if (specAggregatedStats != null) {
				StatsSummary intervalAggregatedStats = specAggregatedStats.get(intervalName);
				Integer intervalSamplesReceived = specSamplesReceived.get(intervalName);
				if (intervalAggregatedStats != null) {
					statsSummaryResponseMessage.setNumSamplesReceived(intervalSamplesReceived);
					statsSummaryResponseMessage.setStatsSummary(intervalAggregatedStats);
					statsSummaryResponseMessage.setSummaryText(intervalAggregatedStats.getStatsSummary());
				}
			}
		}
		
		return statsSummaryResponseMessage;
	}
	
	@Override
	public StatsSummaryRollupResponseMessage getStatsSummaryRollup(String runName, String workloadName, String specName,
			String intervalName) {
		logger.info("getStatsSummaryRollup for runName = " + runName + ", workloadName = " + workloadName + 
				", specName = " + specName + ", intervalName = " + intervalName);				
		boolean isPerTarget = runNameToIsPerTargetStatsMap.get(runName);
		int numSamplesExpected = runNameToHostsListMap.get(runName).size();
		if (isPerTarget) {
			numSamplesExpected *= runNameToWorkloadNameToNumTargetsMap.get(runName).get(workloadName);
		}
		
		StatsSummaryRollupResponseMessage responseMessage = new StatsSummaryRollupResponseMessage();
		responseMessage.setNumSamplesExpected(numSamplesExpected);
		responseMessage.setNumSamplesReceived(0);
		responseMessage.setStatsSummaryRollup(null);
		
		Map<String, Map<String, StatsSummary>> workloadAggregatedStats = aggregatedStatsSummaries.get(workloadName);
		Map<String, Map<String, Integer>> workloadSamplesReceived = receivedSamplesPerSpecAndInterval.get(workloadName);
		if (workloadAggregatedStats != null) {
			Map<String, StatsSummary> specAggregatedStats = workloadAggregatedStats.get(specName);
			Map<String, Integer> specSamplesReceived = workloadSamplesReceived.get(specName);
			if (specAggregatedStats != null) {
				StatsSummary intervalAggregatedStats = specAggregatedStats.get(intervalName);
				Integer intervalSamplesReceived = specSamplesReceived.get(intervalName);
				if (intervalAggregatedStats != null) {
					responseMessage.setNumSamplesReceived(intervalSamplesReceived);
					responseMessage.setStatsSummaryRollup(intervalAggregatedStats.getStatsSummaryRollup());
				} else {
					logger.info("getStatsSummaryRollup intervalAggregatedStats == null");				
				}
			} else {
				logger.info("getStatsSummaryRollup specAggregatedStats == null");				
			}
		} else {
			logger.info("getStatsSummaryRollup workloadSamplesReceived == null");
		}
		
		return responseMessage;
	}
	
	@Override
	public void initializeRun(String runName, InitializeRunStatsMessage initializeRunStatsMessage) {
		logger.info("initializeRun runName = " + runName + ", statsOutputDirName = " + initializeRunStatsMessage.getStatsOutputDirName());

		runNameToHostsListMap.put(runName, initializeRunStatsMessage.getHosts());

		runNameToStatsOutputDirName.put(runName, 
				initializeRunStatsMessage.getStatsOutputDirName());
		
		runNameToWorkloadNameToNumTargetsMap.put(runName, initializeRunStatsMessage.getWorkloadNameToNumTargetsMap());
		
		runNameToIsPerTargetStatsMap.put(runName, initializeRunStatsMessage.getIsPerTargetStats());
	}
	
	@Override
	public void runStarted(String runName) {
		
	}

	@Override
	public void runComplete(String runName) throws IOException {
		logger.info("runComplete runName = " + runName);
		/*
		 * Print the summaries for all of the workloads and statsIntervalSpecs
		 */
		String statsOutputDirName = runNameToStatsOutputDirName.get(runName);
		if (statsOutputDirName == null) {
			logger.debug("runComplete statsOutputDirName is null. All pairs:");
			for (String key : runNameToStatsOutputDirName.keySet()) {
				logger.debug("\tkey = " + key + " : value = " + runNameToStatsOutputDirName.get(key));
			}
		}
		for (String workloadName : aggregatedStatsSummaries.keySet()) {
			logger.debug("runComplete for run " + runName + ", processing workload " + workloadName);
			Map<String, Queue<String>> statsSpecToIntervalOrder = workloadToStatsSpecToIntervalOrder.get(workloadName);
			System.out.println("Summary Statistics for workload " + workloadName);
			for (String specName : aggregatedStatsSummaries.get(workloadName).keySet()) {
				Queue<String> intervalOrderQueue = statsSpecToIntervalOrder.get(specName);
				if (!statsIntervalSpecPrintSummary.containsKey(specName) || !statsIntervalSpecPrintSummary.get(specName)) {
					continue;
				}
				System.out.println("StatsIntervalSpec: " + specName);
				while (!intervalOrderQueue.isEmpty()) {
					String intervalName = intervalOrderQueue.poll();
					StatsSummary stats = aggregatedStatsSummaries.get(workloadName).get(specName).get(intervalName);
					String summary = stats.getStatsSummary();
					System.out.println(summary);
				}
			}
		}
		
		/*
		 * Close all of the open csvWriters
		 */
		for (Map<String, Writer> specToWriterMap : workloadAllSamplesCsvWriters.values()) {
			for (Writer writer : specToWriterMap.values()) {
				writer.flush();
				writer.close();
			}
		}
		for (Map<String, Writer> specToWriterMap : workloadAggregatedCsvWriters.values()) {
			for (Writer writer : specToWriterMap.values()) {
				writer.flush();
				writer.close();
			}
		}
		for (Map<String, Writer> specToWriterMap : workloadSummaryWriters.values()) {
			for (Writer writer : specToWriterMap.values()) {
				writer.flush();
				writer.close();
			}
		}
		
	}

}

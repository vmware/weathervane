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
package com.vmware.weathervane.workloadDriver.common.web.service;

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
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummary;

@Service
public class StatsServiceImpl implements StatsService {
	private static final Logger logger = LoggerFactory.getLogger(StatsServiceImpl.class);

	private long curPeriod = 0;
	
	private Map<String, List<String>> runNameToHostsListMap = new HashMap<String, List<String>>();
	private Map<String, String> runNameToStatsOutputDirName = new HashMap<String, String>();
	private Map<String, Map<String, Integer>> runNameToWorkloadNameToNumTargetsMap = new HashMap<String, Map<String, Integer>>();
	
	/*
	 * Writers for csv files.
	 * workload -> (statsIntervalSpec -> Writer)
	 */
	private Map<String, Map<String, Writer>> workloadAllSamplesCsvWriters 
										= new HashMap<String, Map<String, Writer>>();
	private Map<String, Map<String, Writer>> workloadAggregatedCsvWriters 
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
		logger.debug("postStatsSummary for run " + runName + ": " + statsSummary.toString());
		String workloadName = statsSummary.getWorkloadName();
		String statsIntervalSpecName = statsSummary.getStatsIntervalSpecName();
		String intervalName = statsSummary.getIntervalName();
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
			 * We should have received numHosts * workload->numTargets
			 */
			List<String> hosts = runNameToHostsListMap.get(runName);
			String statsOutputDirName = runNameToStatsOutputDirName.get(runName);
			if (intervalSamplesReceived < (hosts.size() * workloadNameToNumTargetsMap.get(workloadName))) {
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
						specToAggregatedWriterMap.put(statsIntervalSpecName, aggregatedWriter);
						aggregatedWriter.write(intervalAggregatedStats.getAggregatedStatsCsvHeader() + "\n");
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
				}

			}
			
		}
				
	}

	@Override
	public void initializeRun(String runName, InitializeRunStatsMessage initializeRunStatsMessage) {
		logger.debug("initializeRun runName = " + runName + ", statsOutputDirName = " + initializeRunStatsMessage.getStatsOutputDirName());

		runNameToHostsListMap.put(runName, initializeRunStatsMessage.getHosts());

		runNameToStatsOutputDirName.put(runName, 
				initializeRunStatsMessage.getStatsOutputDirName());
		
		runNameToWorkloadNameToNumTargetsMap.put(runName, initializeRunStatsMessage.getWorkloadNameToNumTargetsMap());
	}
	
	@Override
	public void runStarted(String runName) {
		
	}

	@Override
	public void runComplete(String runName) throws IOException {
		logger.debug("runComplete runName = " + runName);
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
				Writer summaryWriter = new BufferedWriter(new OutputStreamWriter(
						new FileOutputStream(statsOutputDirName + "/" + workloadName + "-" + specName + "-summary.txt"), "utf-8"));
				while (!intervalOrderQueue.isEmpty()) {
					String intervalName = intervalOrderQueue.poll();
					StatsSummary stats = aggregatedStatsSummaries.get(workloadName).get(specName).get(intervalName);
					String summary = stats.getStatsSummary();
					System.out.println(summary);
					summaryWriter.write(summary + "\n");
				}
				summaryWriter.close();
			}
		}
		
		/*
		 * Close all of the open csvWriters
		 */
		for (Map<String, Writer> specToWriterMap : workloadAllSamplesCsvWriters.values()) {
			for (Writer writer : specToWriterMap.values()) {
				writer.close();
			}
		}
		for (Map<String, Writer> specToWriterMap : workloadAggregatedCsvWriters.values()) {
			for (Writer writer : specToWriterMap.values()) {
				writer.close();
			}
		}
		
	}

}

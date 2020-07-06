/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPath;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.workloadDriver.common.core.Workload;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.RampLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadInterval.UniformLoadInterval;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathController;
import com.vmware.weathervane.workloadDriver.common.core.loadControl.loadPathController.LoadPathIntervalResultWatcher;
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsSummaryRollupResponseMessage;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsSummaryRollup;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ 
	@Type(value = IntervalLoadPath.class, name = "interval"), 
	@Type(value = FindMaxLoadPath.class, name = "findmax"), 
	@Type(value = SyncedFindMaxLoadPath.class, name = "syncedfindmax"), 
	@Type(value = FixedLoadPath.class, name = "fixed"), 
	@Type(value = RampToMaxLoadPath.class, name = "ramptomax")
})
public abstract class LoadPath implements Runnable, LoadPathIntervalResultWatcher {
	private static final Logger logger = LoggerFactory.getLogger(LoadPath.class);

	private String name;

	/*
	 * isStatsInterval indicates that we should treat the load intervals of
	 * this load path as stats intervals as well.
	 */
	private Boolean isStatsInterval;
	
	private Boolean printSummary;
	private Boolean printIntervals;
	private Boolean printCsv;

	protected RampLoadInterval curStatusInterval;

	@JsonIgnore
	public abstract UniformLoadInterval getNextInterval();

	@JsonIgnore
	public abstract boolean isStatsIntervalComplete();

	@JsonIgnore
	public abstract UniformLoadInterval getCurStatsInterval();

	@JsonIgnore
	private long numActiveUsers;
	
	@JsonIgnore
	private boolean finished = false;

	@JsonIgnore
	private List<String> hosts;

	@JsonIgnore
	protected String statsHostName = null;

	@JsonIgnore
	protected String runName = null;

	@JsonIgnore
	protected String workloadName = null;

	@JsonIgnore
	protected Workload workload = null;

	@JsonIgnore
	protected LoadPathController loadPathController = null;

	@JsonIgnore
	private ScheduledExecutorService executorService = null;
	
	@JsonIgnore
	protected RestTemplate restTemplate = null;

	@JsonIgnore
	protected int portNumber;	
	
	@JsonIgnore
	private StatsIntervalTracker statsTracker = null;

	@JsonIgnore
	protected List<StatsSummaryRollup> intervalStatsSummaries = new ArrayList<StatsSummaryRollup>();

	public void initialize(String runName, String workloadName, Workload workload, 
			LoadPathController loadPathController,  List<String> hosts, String statsHostName, 
			int portNumber, RestTemplate restTemplate, 
			ScheduledExecutorService executorService) {
		logger.debug("initialize for run " + runName + ", workload " + workloadName + ", loadPath " + name );
		this.runName = runName;
		this.workloadName = workloadName;
		this.workload = workload;
		this.loadPathController = loadPathController;
		loadPathController.registerIntervalResultCallback(name, this);
		this.executorService = executorService;
		this.hosts = hosts;
		this.statsHostName = statsHostName;
		this.portNumber = portNumber;
		this.restTemplate = restTemplate;
	}

	public void start() {
		logger.debug("start for run " + runName + ", workload " + workloadName + ", loadPath " + name );

		if (getIsStatsInterval()) {
			/*
			 * This loadPath should also generate statsIntervalComplete messages
			 * for every interval in the load path. Start a watcher to send the
			 * appropriate messages
			 */
			logger.debug("start: Creating statsWatcher");
			statsTracker = new StatsIntervalTracker();
		}

		getExecutorService().execute(this);

	}

	public void stop() {
		finished = true;
	}

	@Override
	public void run() {
		logger.debug("run for run " + runName + ", workload " + workloadName + ", loadPath " + name );
		
		/*
		 * Check whether the just completed interval was the end of a stats interval
		 */
		if (getIsStatsInterval() && this.isStatsIntervalComplete()) {
			getStatsTracker().statsIntervalComplete();
		}
		
		UniformLoadInterval nextInterval = this.getNextInterval();
		logger.debug("run nextInterval = " + nextInterval);
		long users = nextInterval.getUsers();

		/*
		 * Notify the workload, so that it can notify the statsIntervalSpec
		 * of the start number of users
		 */
		workload.setActiveUsers(users);

		/*
		 * Send messages to workloadService on driver nodes indicating new
		 * number of users to run.
		 */
		try {
			changeActiveUsers(users);
		} catch (Throwable t) {
			logger.warn("LoadPath {} got throwable when notifying hosts of change in active users: {}", 
							this.getName(), t.getMessage());
		}
		
		long wait = nextInterval.getDuration();
		logger.debug("run: interval duration is " + wait + " seconds");
		if (!isFinished() && (wait > 0)) {
			logger.debug("run: sleeping for  " + wait + " seconds");
			getExecutorService().schedule(this, wait, TimeUnit.SECONDS);
		}
	}

	public void changeActiveUsers(long numUsers) {
		logger.debug("changeActiveUsers for loadPath {} to {}", name, numUsers);
		numActiveUsers = numUsers;
		for (String hostname : hosts) {
			/*
			 * Send the changeusers message for the workload to the host
			 */
			ChangeUsersMessage changeUsersMessage = new ChangeUsersMessage();
			changeUsersMessage.setActiveUsers(numUsers);

			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);

			HttpEntity<ChangeUsersMessage> msgEntity = new HttpEntity<ChangeUsersMessage>(changeUsersMessage,
					requestHeaders);
			String url = "http://" + hostname + ":" + portNumber + "/driver/run/" + runName + "/workload/" + workloadName + "/users";
			
			boolean succeeded = false;
			int tries = 5;
			while (!succeeded && (tries > 0)) {
				ResponseEntity<BasicResponse> responseEntity = null;
				try {
					tries--;
					responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,	BasicResponse.class);
				} catch (Throwable t) {
					if (tries > 0) {
						logger.warn("changeActiveUsers: LoadPath {} got throwable when notifying host {} of change in active users: {}", 
								hostname, this.getName(), t.getMessage());
					} else {
						throw t;
					}
				}
				
				if (responseEntity != null) {
					BasicResponse response = responseEntity.getBody();
					if (responseEntity.getStatusCode() != HttpStatus.OK) {
						logger.error("Error posting changeUsers message to " + url);
					} else {
						succeeded = true;
					}
				}
			}
		}

	}

	protected StatsSummaryRollup fetchStatsSummaryRollup(String intervalNum) {
		/*
		 * Get the statsSummaryRollup for the previous interval over all hosts and targets
		 */
		HttpHeaders requestHeaders = new HttpHeaders();
		requestHeaders.setContentType(MediaType.APPLICATION_JSON);

		String url = "http://" + statsHostName + ":" + portNumber + "/stats/run/" + runName + "/workload/" + workloadName 
				+ "/specName/" + getName() + "/intervalName/" + intervalNum +"/rollup";
		logger.debug("fetchStatsSummaryRollup  getting rollup from " + statsHostName + ", url = " + url);
		
		/*
		 * Need to keep getting rollup for the interval until the stats server
		 * has received the statsSummary from all of the nodes
		 */
		StatsSummaryRollupResponseMessage response = null;
		boolean responseReady = false;
		int retries = 24;
		while (!responseReady && (retries > 0)) {
			ResponseEntity<StatsSummaryRollupResponseMessage> responseEntity = restTemplate.getForEntity(url, StatsSummaryRollupResponseMessage.class);
			response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("fetchStatsSummaryRollup: Error getting interval stats for " + url);
				return null;
			}

			if (response.getNumSamplesExpected().equals(response.getNumSamplesReceived())) {
				logger.debug("fetchStatsSummaryRollup: Stats server has processed all samples");
				responseReady = true;
			} else {
				logger.debug("fetchStatsSummaryRollup: Stats server has not processed all samples.  expected = " + response.getNumSamplesExpected() 
				+ ", received = " + response.getNumSamplesReceived());
				try {
					Thread.sleep(500);
				} catch (InterruptedException e) {
				}
			}
			retries--;
		}

		if ((response == null) || (retries == 0)) {
			logger.warn("fetchStatsSummaryRollup: Did not get a valid response.  Returning false");
			return null;
		} else {
			return response.getStatsSummaryRollup();
		}
	}

	@Override
	public void intervalResult(String intervalName, boolean intervalResult) {
		/*
		 * Base implementation for loadPath types that don't use the global
		 * interval result.  We just log the result.
		 */
		logger.debug("intervalResult for interval {} = {}", intervalName, intervalResult);
	}

	protected class StatsIntervalTracker {

		private long curIntervalStartTime = System.currentTimeMillis();
		private long intervalStartUsers = 0;

		public void statsIntervalComplete() {

			UniformLoadInterval nextInterval = getCurStatsInterval();
			long intervalEndUsers = nextInterval.getUsers();
			long lastIntervalEndTime = System.currentTimeMillis();
			logger.debug("StatsIntervalWatcher run intervalStartUsers = " + intervalStartUsers + ", intervalEndUsers = " + intervalEndUsers);

			/*
			 * Send messages to workloadService on driver nodes that interval has completed.
			 */
			for (String hostname : hosts) {
				/*
				 * Send the statsIntervalComplete message for the workload to the host
				 */
				StatsIntervalCompleteMessage statsIntervalCompleteMessage = new StatsIntervalCompleteMessage();
				statsIntervalCompleteMessage.setCompletedSpecName(name);
				statsIntervalCompleteMessage.setCurIntervalName(nextInterval.getName());
				statsIntervalCompleteMessage.setCurIntervalStartTime(curIntervalStartTime);
				statsIntervalCompleteMessage.setLastIntervalEndTime(lastIntervalEndTime);
				statsIntervalCompleteMessage.setIntervalStartUsers(intervalStartUsers);
				statsIntervalCompleteMessage.setIntervalEndUsers(intervalEndUsers);

				HttpHeaders requestHeaders = new HttpHeaders();
				requestHeaders.setContentType(MediaType.APPLICATION_JSON);

				HttpEntity<StatsIntervalCompleteMessage> msgEntity = new HttpEntity<StatsIntervalCompleteMessage>(
						statsIntervalCompleteMessage, requestHeaders);
				String url = "http://" + hostname + ":" + portNumber + "/driver/run/" + runName + "/workload/"
						+ workloadName + "/statsIntervalComplete";
				logger.debug("StatsIntervalWatcher run sending statsIntervalComplete message for run " + runName
						+ ", workload " + workloadName + " to host " + hostname + ", url = " + url);
				ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
						BasicResponse.class);

				BasicResponse response = responseEntity.getBody();
				if (responseEntity.getStatusCode() != HttpStatus.OK) {
					logger.error("Error posting statsIntervalComplete message to " + url);
				} else {
					logger.debug("StatsIntervalWatcher run sent statsIntervalComplete message for run " + runName
							+ ", workload " + workloadName + " to host " + hostname);
				}
			}
			intervalStartUsers = intervalEndUsers;
			curIntervalStartTime = lastIntervalEndTime;
		}
	}

	protected List<UniformLoadInterval> generateRampIntervals(String intervalName, long duration, long timeStep,
							long startUsers, long endUsers) {
		List<UniformLoadInterval> uniformIntervals = new ArrayList<UniformLoadInterval>();
		/*
		 * When calculating the change in users per interval, need to subtract
		 * one interval since the first interval is at startUsers
		 */
		long numIntervals = (long) Math.ceil(duration / (timeStep * 1.0));
		long usersPerInterval = (long) Math.ceil(Math.abs(endUsers - startUsers) / ((numIntervals - 1) * 1.0));
		if (endUsers < startUsers) {
			usersPerInterval *= -1;
		}

		long totalDuration = 0;
		for (long i = 0; i < numIntervals; i++) {
			long curUsers = startUsers + (i * usersPerInterval);
			if (endUsers < startUsers) {
				if (curUsers < endUsers) {
					curUsers = endUsers;
				}
			} else {
				if (curUsers > endUsers) {
					curUsers = endUsers;
				}
			}

			if ((totalDuration + timeStep) > duration) {
				timeStep = duration - totalDuration;
				if (timeStep <= 0) {
					break;
				}
			}

			UniformLoadInterval newInterval = new UniformLoadInterval(curUsers, timeStep);

			newInterval.setName(intervalName + i);
			uniformIntervals.add(newInterval);

			totalDuration += timeStep;

		}
		
		return uniformIntervals;

	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public List<String> getHosts() {
		return hosts;
	}

	public void setHosts(List<String> hosts) {
		this.hosts = hosts;
	}

	public Boolean getIsStatsInterval() {
		return isStatsInterval;
	}

	public void setIsStatsInterval(Boolean isStatsInterval) {
		this.isStatsInterval = isStatsInterval;
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

	public long getNumActiveUsers() {
		return numActiveUsers;
	}

	public void setNumActiveUsers(long numActiveUsers) {
		this.numActiveUsers = numActiveUsers;
	}

	public List<StatsSummaryRollup> getIntervalStatsSummaries() {
		return intervalStatsSummaries;
	}

	public void setIntervalStatsSummaries(List<StatsSummaryRollup> intervalStatsSummaries) {
		this.intervalStatsSummaries = intervalStatsSummaries;
	}

	public boolean isFinished() {
		return finished;
	}

	public RampLoadInterval getCurStatusInterval() {
		return curStatusInterval;
	}

	public void setCurStatusInterval(RampLoadInterval curStatusInterval) {
		this.curStatusInterval = curStatusInterval;
	}

	public StatsIntervalTracker getStatsTracker() {
		return statsTracker;
	}

	public ScheduledExecutorService getExecutorService() {
		return executorService;
	}

}

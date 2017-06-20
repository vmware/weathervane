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
package com.vmware.weathervane.workloadDriver.common.model.loadPath;

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
import com.vmware.weathervane.workloadDriver.common.representation.BasicResponse;
import com.vmware.weathervane.workloadDriver.common.representation.ChangeUsersMessage;
import com.vmware.weathervane.workloadDriver.common.representation.StatsIntervalCompleteMessage;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ 
	@Type(value = IntervalLoadPath.class, name = "interval"), 
	@Type(value = FindMaxLoadPath.class, name = "findmax"), 
	@Type(value = FixedLoadPath.class, name = "fixed"), 
	@Type(value = RampToMaxLoadPath.class, name = "ramptomax")
})
public abstract class LoadPath implements Runnable {
	private static final Logger logger = LoggerFactory.getLogger(LoadPath.class);

	private String name;

	private Boolean isStatsInterval;
	private Boolean printSummary;
	private Boolean printIntervals;
	private Boolean printCsv;

	@JsonIgnore
	public abstract UniformLoadInterval getNextInterval();

	@JsonIgnore
	public abstract LoadInterval getNextStatsInterval();

	@JsonIgnore
	private long numActiveUsers;
	
	@JsonIgnore
	private boolean finished = false;

	@JsonIgnore
	private List<String> hosts;

	@JsonIgnore
	private String runName = null;

	@JsonIgnore
	private String workloadName = null;

	@JsonIgnore
	private ScheduledExecutorService executorService = null;
	
	@JsonIgnore
	private RestTemplate restTemplate = null;

	@JsonIgnore
	private int portNumber;

	public void initialize(String runName, String workloadName, List<String> hosts, int portNumber, RestTemplate restTemplate, 
			ScheduledExecutorService executorService) {
		logger.debug("initialize for run " + runName + ", workload " + workloadName + ", loadPath " + name );
		this.runName = runName;
		this.workloadName = workloadName;
		this.executorService = executorService;
		this.hosts = hosts;
		this.portNumber = portNumber;
		this.restTemplate = restTemplate;
	}

	public void start() {
		logger.debug("start for run " + runName + ", workload " + workloadName + ", loadPath " + name );
		executorService.execute(this);

		if (isStatsInterval) {
			/*
			 * This loadPath should also generate statsIntervalComplete messages
			 * for every interval in the load path. Start a watcher to send the
			 * appropriate messages
			 */
			StatsIntervalWatcher statsWatcher = new StatsIntervalWatcher();
		}
	}

	public void stop() {
		finished = true;
	}

	@Override
	public void run() {
		logger.debug("run for run " + runName + ", workload " + workloadName + ", loadPath " + name );
		UniformLoadInterval nextInterval = this.getNextInterval();
		logger.debug("run nextInterval = " + nextInterval);
		/*
		 * Send messages to workloadService on driver nodes indicating new
		 * number of users to run.
		 */
		changeActiveUsers(nextInterval.getUsers());

		long wait = nextInterval.getDuration();
		if (!isFinished() && (wait > 0)) {
			executorService.schedule(this, wait, TimeUnit.SECONDS);
		}

	}

	private long adjustUserCount(long originalUserCount, int nodeNumber) {

		long adjustedUserCount = originalUserCount / hosts.size();

		/*
		 * Add an additional user from the remainder for the first
		 * usersRemaining nodes
		 */
		long usersRemaining = originalUserCount - (hosts.size() * adjustedUserCount);
		if (usersRemaining > nodeNumber) {
			adjustedUserCount++;
		}

		return adjustedUserCount;
	}

	public void changeActiveUsers(long numUsers) {

		numActiveUsers = numUsers;
		int nodeNumber = 0;
		for (String hostname : hosts) {
			long adjustedUsers = adjustUserCount(numActiveUsers, nodeNumber);
			
			/*
			 * Send the changeusers message for the workload to the host
			 */
			ChangeUsersMessage changeUsersMessage = new ChangeUsersMessage();
			changeUsersMessage.setActiveUsers(adjustedUsers);

			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);

			HttpEntity<ChangeUsersMessage> msgEntity = new HttpEntity<ChangeUsersMessage>(changeUsersMessage,
					requestHeaders);
			String url = "http://" + hostname + ":" + portNumber + "/driver/run/" + runName + "/workload/" + workloadName + "/users";
			ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
					BasicResponse.class);

			BasicResponse response = responseEntity.getBody();
			if (responseEntity.getStatusCode() != HttpStatus.OK) {
				logger.error("Error posting changeUsers message to " + url);
			}


			nodeNumber++;
		}

	}

	protected class StatsIntervalWatcher implements Runnable {

		private String curIntervalName = "";
		private long curIntervalStartTime;
		private long lastIntervalEndTime;
		
		public StatsIntervalWatcher() {
			LoadInterval nextInterval = getNextStatsInterval();
			long wait = nextInterval.getDuration();
			curIntervalName = nextInterval.getName();
			logger.debug("StatsIntervalWatcher: Initial interval has wait of " + wait + " seconds and name " + curIntervalName);
			
			if (!isFinished() && (wait > 0)) {
				executorService.schedule(this, wait, TimeUnit.SECONDS);
			}
			lastIntervalEndTime = curIntervalStartTime = System.currentTimeMillis();
		}

		@Override
		public void run() {
			logger.debug("StatsIntervalWatcher run");
			lastIntervalEndTime = System.currentTimeMillis();
			/*
			 * Send messages to workloadService on driver nodes that interval
			 * has completed. 
			 */
			for (String hostname : hosts) {
				/*
				 * Send the statsIntervalComplete message for the workload to the host
				 */
				StatsIntervalCompleteMessage statsIntervalCompleteMessage = new StatsIntervalCompleteMessage();
				statsIntervalCompleteMessage.setCompletedSpecName(name);
				statsIntervalCompleteMessage.setCurIntervalName(curIntervalName);
				statsIntervalCompleteMessage.setCurIntervalStartTime(curIntervalStartTime);
				statsIntervalCompleteMessage.setLastIntervalEndTime(lastIntervalEndTime);
				
				HttpHeaders requestHeaders = new HttpHeaders();
				requestHeaders.setContentType(MediaType.APPLICATION_JSON);

				HttpEntity<StatsIntervalCompleteMessage> msgEntity 
					= new HttpEntity<StatsIntervalCompleteMessage>(statsIntervalCompleteMessage,
						requestHeaders);
				String url = "http://" + hostname + ":" + portNumber + "/driver/run/" + runName + "/workload/" + workloadName + "/statsIntervalComplete";
				logger.debug("StatsIntervalWatcher run sending statsIntervalComplete message for run " + runName + ", workload " + workloadName 
						+ " to host " + hostname + ", url = " + url);
				ResponseEntity<BasicResponse> responseEntity = restTemplate.exchange(url, HttpMethod.POST, msgEntity,
						BasicResponse.class);

				BasicResponse response = responseEntity.getBody();
				if (responseEntity.getStatusCode() != HttpStatus.OK) {
					logger.error("Error posting statsIntervalComplete message to " + url);
				}
			}

			
			LoadInterval nextInterval = getNextStatsInterval();
			long wait = nextInterval.getDuration();
			curIntervalName = nextInterval.getName();
			logger.debug("StatsIntervalWatcher: Next interval has wait of " + wait + " seconds and name " + curIntervalName);

			if (!isFinished() && (wait > 0)) {
				executorService.schedule(this, wait, TimeUnit.SECONDS);
			}

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

	public boolean isFinished() {
		return finished;
	}

}

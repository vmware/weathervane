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
package com.vmware.weathervane.workloadDriver.common.model.target;

import java.util.Queue;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.atomic.AtomicLong;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.workloadDriver.common.core.LoadProfileChangeCallback;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.factory.UserFactory;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ @Type(value = HttpTarget.class, name = "http")
})
public abstract class Target {
	private static final Logger logger = LoggerFactory.getLogger(Target.class);
	
	private String name;

	@JsonIgnore
	private String workloadName;

	@JsonIgnore
	private Integer nodeNumber;
	
	@JsonIgnore
	private Integer numNodes;
	
	@JsonIgnore
	private Queue<LoadProfileChangeCallback> loadProfileChangeCallbacks = new ConcurrentLinkedQueue<LoadProfileChangeCallback>();

	/*
	 * userIds are unique among all targets
	 */
	@JsonIgnore
	private static AtomicLong userIdCounter = new AtomicLong(1);

	/*
	 * Ordering IDs are per-target
	 */
	@JsonIgnore
	private long orderingIdCounter = 1L;
	
	@JsonIgnore
	private boolean finished = false;

	@JsonIgnore
	private long numActiveUsers = 0;

	@JsonIgnore
	private UserFactory userFactory;

	@JsonIgnore
	private StatsCollector statsCollector;
	
	public void initialize(String workloadName,	long maxUsers, Integer nodeNumber, Integer numNodes, 
				UserFactory userFactory, StatsCollector statsCollector) {
		this.workloadName = workloadName;
		this.nodeNumber = nodeNumber;
		this.numNodes = numNodes;
		this.userFactory = userFactory;	
		this.statsCollector = statsCollector;

		for (long i = 1; i <= maxUsers; i++) {
			long userId = userIdCounter.getAndIncrement();
			long orderingId = orderingIdCounter++;
			long globalOrderingId = (nodeNumber + 1) + ((orderingId - 1) * numNodes);
			User user = getUserFactory().createUser(userId, orderingId, globalOrderingId, this);
			user.setStatsCollector(getStatsCollector());
			this.registerLoadProfileChangeCallback(user);
			
		}

	}
		
	public void stop() {
		logger.debug("Stopping Target ");				
		finished = true;
		
		logger.debug("run finished");				
		synchronized (loadProfileChangeCallbacks) {
			logger.debug("Calling loadProfilesComplete callbacks");
			for (LoadProfileChangeCallback callbackObject : loadProfileChangeCallbacks) {
				callbackObject.loadProfilesComplete();
			}
		}

	}
	
	
	/**
	 * This method is used to register a callback for changes in the load
	 * profile
	 */
	public boolean registerLoadProfileChangeCallback(LoadProfileChangeCallback _callbackObject) {
		boolean success;
		synchronized (loadProfileChangeCallbacks) {
			logger.debug("Registering a loadProfileChanged callback for " + _callbackObject);
			success = loadProfileChangeCallbacks.add(_callbackObject);
		}
		return success;
	}

	/**
	 * Remove a callback from the list of objects to be notified when the load
	 * profile for this track changes.
	 */
	public boolean removeLoadProfileChangeCallback(LoadProfileChangeCallback _callbackObject) {
		boolean success;
		synchronized (loadProfileChangeCallbacks) {
			logger.debug("Removing a loadProfileChanged callback for " + _callbackObject);
			success = loadProfileChangeCallbacks.remove(_callbackObject);
		}
		return success;
	}

	public void setUserLoad(long numUsers) {
		logger.info("setUserLoad for target " + this.name + " to " + numUsers + " users.");
		numActiveUsers = numUsers;

		// Call loadProfileChange callback for existing users
		synchronized (loadProfileChangeCallbacks) {
			logger.info("Calling loadProfileChanged callbacks");
			for (LoadProfileChangeCallback callbackObject : loadProfileChangeCallbacks) {
				callbackObject.loadProfileChanged(numUsers);
			}
			logger.info("Called loadProfileChanged callbacks");
		}
		
		logger.info("setUserLoad for target " + this.name + " exiting");

	}

	@JsonIgnore
	public long getNumActiveUsers() {
		return numActiveUsers ;
	}

	public String getWorkloadName() {
		return workloadName;
	}

	public void setWorkloadName(String workloadName) {
		this.workloadName = workloadName;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public UserFactory getUserFactory() {
		return userFactory;
	}

	public StatsCollector getStatsCollector() {
		return statsCollector;
	}

}

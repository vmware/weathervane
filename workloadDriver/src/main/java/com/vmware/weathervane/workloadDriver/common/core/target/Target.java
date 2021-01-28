/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.core.target;

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
import com.vmware.weathervane.workloadDriver.common.statistics.statsCollector.StatsCollector;

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
	private Integer targetNumber;
	
	@JsonIgnore
	private Integer numTargets;
	
	@JsonIgnore
	private Long maxUsers;

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
			Integer targetNumber, Integer numTargets, UserFactory userFactory, StatsCollector statsCollector) {
		this.workloadName = workloadName;
		this.nodeNumber = nodeNumber;
		this.numNodes = numNodes;
		this.setTargetNumber(targetNumber);
		this.setNumTargets(numTargets);
		this.userFactory = userFactory;	
		this.statsCollector = statsCollector;
		this.maxUsers = maxUsers;
		
		/*
		 * Determine how many users to create based on maxUsers, the number of nodes,
		 * the number of targets per node, and the targetNumber and nodeNumber of this
		 * target.
		 * In order to properly compute unique global ordering IDs that correspond to the 
		 * ordering of users, we first create the same number of users per target, and 
		 * then create any users in the remainder of maxUsers / (numNodes * numTargets)
		 */
		int targetOrderingId = targetNumber + (nodeNumber * numTargets);
		long usersPerTarget = maxUsers / (numNodes * numTargets);
		long excessUsers = maxUsers % (numNodes * numTargets);
		long usersToCreate = usersPerTarget;
		if (targetOrderingId < excessUsers) {
			usersToCreate++;
		}

		int numOtherTargets = (numNodes * numTargets) - 1;
		logger.info("initialize: Target " + name + " numOtherTargets = " + numOtherTargets + ", targetOrderingId = " + targetOrderingId + ", maxUsers = " + maxUsers);
		for (long i = 1; i <= usersToCreate; i++) {
			long userId = userIdCounter.getAndIncrement();
			long orderingId = orderingIdCounter++;
			long targetStep = (orderingId - 1) * numOtherTargets;
			long globalOrderingId = orderingId + targetOrderingId + targetStep;
			logger.info("initialize: Target " + name + " creating User with userId = " + userId + ", orderingId = " + orderingId + ", globalOrderingId = " + globalOrderingId );
			User user = getUserFactory().createUser(userId, orderingId, globalOrderingId, this);
			user.setStatsCollector(statsCollector);
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
		logger.debug("setUserLoad for target " + this.name + " to " + numUsers + " users.");
		numActiveUsers = numUsers;

		// Call loadProfileChange callback for existing users
		synchronized (loadProfileChangeCallbacks) {
			logger.debug("Calling loadProfileChanged callbacks");
			for (LoadProfileChangeCallback callbackObject : loadProfileChangeCallbacks) {
				callbackObject.loadProfileChanged(numUsers);
			}
			logger.debug("Called loadProfileChanged callbacks");
		}
		
		logger.debug("setUserLoad for target " + this.name + " exiting");

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

	public Integer getTargetNumber() {
		return targetNumber;
	}

	public void setTargetNumber(Integer targetNumber) {
		this.targetNumber = targetNumber;
	}

	public Integer getNumTargets() {
		return numTargets;
	}

	public void setNumTargets(Integer numTargets) {
		this.numTargets = numTargets;
	}

	public UserFactory getUserFactory() {
		return userFactory;
	}
}

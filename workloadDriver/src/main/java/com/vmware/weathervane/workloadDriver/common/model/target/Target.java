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

import java.io.BufferedWriter;
import java.io.FileNotFoundException;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStreamWriter;
import java.io.UnsupportedEncodingException;
import java.io.Writer;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.HashMap;
import java.util.HashSet;
import java.util.Map;
import java.util.Queue;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.ConcurrentLinkedQueue;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicLong;

import org.omg.CORBA._IDLTypeStub;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnore;
import com.fasterxml.jackson.annotation.JsonSubTypes;
import com.fasterxml.jackson.annotation.JsonSubTypes.Type;
import com.fasterxml.jackson.annotation.JsonTypeInfo;
import com.fasterxml.jackson.annotation.JsonTypeInfo.As;
import com.vmware.weathervane.workloadDriver.common.core.Behavior;
import com.vmware.weathervane.workloadDriver.common.core.LoadProfileChangeCallback;
import com.vmware.weathervane.workloadDriver.common.core.User;
import com.vmware.weathervane.workloadDriver.common.exceptions.UnknownEntityException;
import com.vmware.weathervane.workloadDriver.common.model.Workload;
import com.vmware.weathervane.workloadDriver.common.model.loadPath.LoadPath;
import com.vmware.weathervane.workloadDriver.common.model.loadPath.UniformLoadInterval;

@JsonTypeInfo(use = com.fasterxml.jackson.annotation.JsonTypeInfo.Id.NAME, include = As.PROPERTY, property = "type")
@JsonSubTypes({ @Type(value = HttpTarget.class, name = "http")
})
public abstract class Target implements Runnable {
	private static final Logger logger = LoggerFactory.getLogger(Target.class);

	private String loadPathName;
	private String workloadName;
	
	@JsonIgnore
	private String name;

	@JsonIgnore
	private Integer nodeNumber;
	
	@JsonIgnore
	private Integer numNodes;
	

	@JsonIgnore
	private LoadPath loadPath = null;

	@JsonIgnore
	private Workload workload = null;
	
	@JsonIgnore
	private long finishTime;

	@JsonIgnore
	private long rampUp;

	@JsonIgnore
	private ScheduledExecutorService executorService;
	
	@JsonIgnore
	private UniformLoadInterval currentLoadInterval;
		
	@JsonIgnore
	private long numActiveUsers;
	
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
	
	public void initialize(String name, long rampUp, long steadyState, long rampDown,
			ScheduledExecutorService executorService,
			Map<String, LoadPath> loadPaths, Map<String, Workload> workloads, 
			Integer nodeNumber, Integer numNodes) {
		this.setName(name);
		this.nodeNumber = nodeNumber;
		this.numNodes = numNodes;
		this.executorService = executorService;
		
		long runDurationMs = (rampUp + steadyState + rampDown) * 1000;
		long now = System.currentTimeMillis();
		finishTime = now + runDurationMs;

		loadPath = loadPaths.get(loadPathName);
		if (loadPath == null) {
			throw new UnknownEntityException("No LoadPath with name " + loadPathName);
		}
		
		setWorkload(workloads.get(workloadName));
		if (getWorkload() == null) {
			throw new UnknownEntityException("No Workload with name " + workloadName);
		}
		workload.addTarget(this);
				
	}
	
	public void start() {
		logger.debug("Starting Target " + getName() );				
		currentLoadInterval = loadPath.getNextInterval(name);
		numActiveUsers = currentLoadInterval.getUsers();
		
		logger.debug("For target " + getName() + " initial interval: " + currentLoadInterval);
		
		/*
		 * Create and start all of the users
		 */
		long numUsersForThisNode = getLoadPath().getMaxUsers() ;
		
		logger.debug("For node " + nodeNumber + ", target " + getName() + " creating " + numUsersForThisNode + " users.");
		for (long i = 1; i <= numUsersForThisNode; i++) {
			long userId = userIdCounter.getAndIncrement();
			long orderingId = orderingIdCounter++;
			long globalOrderingId = (nodeNumber + 1) + ((userId - 1) * numNodes);
			User user = getWorkload().createUser(userId, orderingId, globalOrderingId, this);
			user.setStatsCollector(getWorkload().getStatsCollector());
			this.registerLoadProfileChangeCallback(user);
			
			user.start(finishTime, numActiveUsers);
		}
		
		// Schedule the next interval
		executorService.schedule(this, currentLoadInterval.getDuration(), TimeUnit.SECONDS);

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
	
	@Override
	public void run() {
		if (!finished) {
			logger.debug("run !finished");				
			currentLoadInterval = loadPath.getNextInterval(name);
			numActiveUsers = currentLoadInterval.getUsers();
			synchronized (loadProfileChangeCallbacks) {
				logger.debug("Calling loadProfileChanged callbacks");
				for (LoadProfileChangeCallback callbackObject : loadProfileChangeCallbacks) {
					callbackObject.loadProfileChanged(numActiveUsers);
				}
			}

			// Schedule the next interval
			executorService.schedule(this, currentLoadInterval.getDuration(), TimeUnit.SECONDS);
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
		
		/*
		 *  Make sure that there are enough users created.  If not then
		 *  create them and start them
		 */
		if ((userIdCounter.get() - 1) < numUsers) {
			long usersToCreate = numUsers - userIdCounter.get() + 1;
			logger.info("For node " + nodeNumber + ", target " + getName() + " creating " + usersToCreate + " users.");
			for (long i = 1; i <= usersToCreate; i++) {
				long userId = userIdCounter.getAndIncrement();
				long orderingId = orderingIdCounter++;
				long globalOrderingId = (nodeNumber + 1) + ((userId - 1) * numNodes);
				User user = getWorkload().createUser(userId, orderingId, globalOrderingId, this);
				user.setStatsCollector(getWorkload().getStatsCollector());
				this.registerLoadProfileChangeCallback(user);
				
				user.start(finishTime, numActiveUsers);
				
			}

		}
		logger.info("setUserLoad for target " + this.name + " exiting");

	}

	@JsonIgnore
	public long getNumActiveUsers() {
		return numActiveUsers;
	}

	public String getLoadPathName() {
		return loadPathName;
	}
	public void setLoadPathName(String loadPathName) {
		this.loadPathName = loadPathName;
	}
	public LoadPath getLoadPath() {
		return loadPath;
	}
	public void setLoadPath(LoadPath loadPath) {
		this.loadPath = loadPath;
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
		
	public Workload getWorkload() {
		return workload;
	}

	public void setWorkload(Workload workload) {
		this.workload = workload;
	}

}

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
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.common.core;

import java.util.ArrayList;
import java.util.List;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.ScheduledFuture;
import java.util.concurrent.TimeUnit;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooser;
import com.vmware.weathervane.workloadDriver.common.factory.OperationFactory;
import com.vmware.weathervane.workloadDriver.common.factory.TransitionChooserFactory;
import com.vmware.weathervane.workloadDriver.common.http.HttpTransport;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

/**
 * @author Hal
 * 
 */
public abstract class User implements LoadProfileChangeCallback {

	private static final Logger logger = LoggerFactory.getLogger(User.class);

	/**
	 * A scheduled executor that is used to set timers for the User reset process to 
	 * force it to complete after a fixed delay so that resources are returned.
	 * The delay is 60 seconds.
	 */
	private static final ScheduledExecutorService _resetTimingExecutor = Executors.newScheduledThreadPool(2);
	private static final long _resetTimeout = 60;
	
	/**
	 * The id the uniquely identifies the user in all ScenarioTracks.
	 */
	private long _id;

	/**
	 * The orderingId uniquely identifies the user in its own ScenarioTrack. It
	 * is used when deciding which users should be running
	 */
	protected long _orderingId;

	/**
	 * The _globalOrderingId uniquely orders users across all 
	 * workload driver nodes
	 */
	protected long _globalOrderingId;
	
	private OperationFactory _operationFactory = null;
	private TransitionChooserFactory _transitionChooserFactory = null;
	
	/**
	 * The Target against which this user driver load
	 */
	private Target target;
	
	/**
	 * This the current user name. It is set to the userId by
	 * default, but benchmark-specific users can set it as appropriate, e.g.
	 * when a login has completed. The username is used as the USER_CONTEXT in
	 * the HTTP client context to make sure each user gets its own connections.
	 */
	private String userName = null;

	private String _behaviorSpecName;
	
	/**
	 * This is the user's behavior. It is the entity that actually executes a
	 * workload. The behavior may change when the load profile changes
	 */
	protected Behavior _behavior = null;

	private HttpTransport _httpTransport;
	
	private StatsCollector _statsCollector = null;

	/**
	 * If this is set to true then this user's behaviours will use think-time
	 * rather than cycle-time when  determining inter-op delays
	 */
	private boolean _useThinkTime = false;
	
	/**
	 * Indicates whether this user is currently active. Determined by the
	 * current load profile in the scenarioTrack.
	 */
	private boolean _isActive = false;

	/**
	 * Indicates whether this User is in the process of stopping and going away
	 */
	private boolean _isResetting = false;
	
	/**
	 * Scheduled future for the timer on the reset process
	 */
	private ScheduledFuture<?> _resetTimerFuture = null;
	
	/**
	 * Emulate the user's browser cache by storing the URLs that have been
	 * cached.
	 */
	private List<String> _pageCache = new ArrayList<String>();

	// Fields related to selecting the next operation for each behavior

	protected Random _randomNumberGenerator;

	public User(Long id, Long orderingId, Long globalOrderingId, String behaviorSpecName, Target target) {

		logger.debug("Creating user with userId " + id + ", globalOrderingId = " 
				+ globalOrderingId + " for target " + target.getName());
		this._id = id;
		this._orderingId = orderingId;
		this._globalOrderingId = globalOrderingId;
		this.target = target;
		this._behaviorSpecName = behaviorSpecName;
		
		setUserName(Long.toString(_id));

		_randomNumberGenerator = new java.util.Random();

		_httpTransport = new HttpTransport(this);
	}

	/**
	 * This method starts the User running by creating the initial behavior and
	 * scheduling it for execution.
	 */
	public void start(long numActiveUsers) {

		_isActive = false;
		_behavior = null;

		/*
		 * Check whether the user is active in the current load profile. If it
		 * is, then create the initial behavior.
		 */
		logger.debug("User:start.  User id = " + _id + ", orderingId = " + _orderingId + ", numActiveUsers = "
				+ numActiveUsers + ", target = " + target.getName());

		if (_orderingId <= numActiveUsers) {
			// The user should be running
			logger.debug("User:start.  User id = " + _id + ", numActiveUsers = " + numActiveUsers + ", orderingId = "
					+ _orderingId + ". User should be running");
			_isActive = true;

			/*
			 * Create the initial Behavior for this user.
			 */
			_behavior = createBehavior();

			/*
			 * Start the behavior running
			 */
			_behavior.start();
		}

	}

	public void stop() {
		if (!_behavior.isStopped()) {
			_behavior.stop();
		}
	}

	public void cleanup() {
		_behavior = null;
		_httpTransport.close();
		_httpTransport = null;
	}

	/**
	 * SubClass must provide a state manager
	 */
	public abstract StateManagerStructs getStateManager();

	/**
	 * Insert the url into the user's browser cache.
	 * 
	 * @param url
	 *            : The URL to cache.
	 * @return false if already in the cache, true otherwise.
	 */
	public boolean cachePage(String url) {
		synchronized (_pageCache) {
			if (_pageCache.indexOf(url) >= 0) {
				return false;
			} else {
				_pageCache.add(url);
				return true;
			}
		}
	}

	/**
	 * Check whether the url is in the user's browser cache.
	 * 
	 * @param url
	 *            : The URL to look for in the cache.
	 * @return true if in the cache, false otherwise.
	 */
	public boolean checkCache(String url) {
		synchronized (_pageCache) {
			if (_pageCache.indexOf(url) >= 0) {
				return true;
			} else {
				return false;
			}
		}
	}

	/**
	 * Clear the user's page cache
	 */
	public void clearCache() {
		synchronized (_pageCache) {
			_pageCache.clear();
		}
	}

	/*** STATE PER OPERATION ***/


	public long getId() {
		return _id;
	}

	public void setId(long id) {
		this._id = id;
	}

	public boolean isActive() {
		return _isActive;
	}

	/**
	 * @param theObject
	 * @param idForNeeds
	 * @param idForContains
	 */
	protected abstract void prepareSharedData(Object theObject, UUID idForNeeds, UUID idForContains);

	protected abstract void prepareData(Object theObject, UUID idForNeeds, UUID idForContains);

	/**
	 * This method is invoked as a callback from the track whenever the load
	 * profile changes. The user must check whether it should still be active,
	 * and whether the mix for its main behavior has changed.
	 */
	@Override
	public void loadProfileChanged(long numActiveUsers) {
		logger.info("User:loadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId 
					+ ", isActive = " + _isActive + ", numActiveUsers = " + numActiveUsers
					+ ", isResetting = " + _isResetting);
		
		/*
		 * Check whether this user should be active.
		 */
		if (_isResetting) {
			/*
			 * This user is already resetting and going away.  It should never become active.
			 */
			logger.debug("User:loadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId + ". The user is already resetting.");
			return;
		} else if ((_orderingId <= numActiveUsers) && !_isActive) {
			/*
			 * The user was inactive. Start a new behavior. There should not
			 * already be a behavior for this user.
			 */
			logger.debug("User:loadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId + ". The user was inactive but should be active");
			if (_behavior != null) {
				throw new RuntimeException(
						"User:LoadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId + ". The user was inactive, but had a behavior");
			}

			_behavior = createBehavior();

			_isActive = true;
			
			/*
			 * Start the behavior running
			 */
			_behavior.start();

		} else if ((_orderingId > numActiveUsers) && _isActive)  {
			// The user should not be active
			logger.debug("User:loadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId + ". The user was active and should no longer be active");
			// There should be a behavior for this user.
			if (_behavior == null) {
				throw new RuntimeException(
						"User:LoadProfileChanged. userId = " + _id + ", orderingId = " + _orderingId + ". The user was active, but did not have a behavior");
			}
			_isActive = false;

			/*
			 * Reset the user and stop the current behavior.
			 */
			this.startReset();
		}

	}

	/**
	 * This method is invoked as a callback from the track when the last load
	 * profile is complete. The user stops executing.
	 */
	@Override
	public void loadProfilesComplete() {

		logger.debug("User:loadProfilesComplete. userId = " + _id);

		if (_behavior != null) {
			_behavior.stop();
		}
		_isActive = false;

	}

	protected Behavior createBehavior() {
		BehaviorSpec spec = BehaviorSpec.getBehaviorSpec(_behaviorSpecName);
		Behavior behavior = new Behavior(this, spec, _statsCollector, target);
		logger.debug("createBehavior Created behavior " + behavior.getBehaviorId());
		UUID behaviorId = behavior.getBehaviorId();

		behavior.setOperations(_operationFactory.getOperations(_statsCollector, this, behavior, target));
		for (Operation operation : behavior.getOperations()) {
			this.prepareData(operation, behaviorId, behaviorId);
		}
		
		behavior.setTransitionChoosers(_transitionChooserFactory.getTransitionChoosers(_randomNumberGenerator, behavior));
		for (TransitionChooser transitionChooser : behavior.getTransitionChoosers().values()) {
			this.prepareData(transitionChooser, behaviorId, behaviorId);
		}
		
		behavior.setHttpTransport(_httpTransport);
		behavior.setUseThinkTime(_useThinkTime);
		logger.debug("User with userId " + _id + " now has primary behavior " + behavior.getBehaviorId().toString()
				+ " and is on track " + target.getName());
		return behavior;
	}

	/**
	 * A call into the user to let it clear state for a behavior which is
	 * stopping
	 */
	protected abstract void clearBehaviorState(UUID behaviorId);

	/**
	 * 
	 */
	protected void startReset() {
		logger.info("startReset called for user " + this.getId() + ", main behavior = " + _behavior.getBehaviorId()
				+ ", subBehavior Ids: " + _behavior.getSubBehaviorIdsString());

		_isResetting = true;
		
		/*
		 * Stop the current behavior, which will stop all of its sub-behaviors
		 */
		_behavior.stop();

		/*
		 * Start a new user to replace this one.
		 */
		User newUser = target.getUserFactory().createUser(_id, _orderingId, _globalOrderingId, target);
		newUser.setStatsCollector(_statsCollector);
		target.registerLoadProfileChangeCallback(newUser);
		newUser.start(target.getNumActiveUsers());
		
		/*
		 * Schedule a timeout before forcing the reset to complete
		 */
		_resetTimerFuture =_resetTimingExecutor.schedule(new ResetTimeoutHandler(this, _behavior), _resetTimeout, TimeUnit.SECONDS);
		
	}

	/**
	 * Called when this users behavior and all sub-behaviors have fully stopped.
	 * It will clear out the user's state and start a new behavior
	 */
	protected synchronized void completeReset(Behavior callingBehavior) {
		logger.info("completeReset called for user " + this.getId() + ", main behavior = " + _behavior.getBehaviorId()
				+ ", subBehavior Ids: " + _behavior.getSubBehaviorIdsString());

		if (_resetTimerFuture != null) {
			_resetTimerFuture.cancel(false);
			_resetTimerFuture = null;
		}
		
		if (_isResetting) {

			this.resetState();
			this.cleanup();
			
			boolean existed = target.removeLoadProfileChangeCallback(this);
			if (!existed) {
				logger.warn("Tried to remove User from operation complete callbacks, but it didn't exist.");
			}

			_isResetting = false;
		}

	}

	protected abstract void resetState();

	public Behavior getBehavior() {
		return _behavior;
	}

	public boolean isUseThinkTime() {
		return _useThinkTime;
	}

	public void setUseThinkTime(boolean useThinkTime) {
		this._useThinkTime = useThinkTime;
	}

	public OperationFactory getOperationFactory() {
		return _operationFactory;
	}

	public void setOperationFactory(OperationFactory operationFactory) {
		this._operationFactory = operationFactory;
	}

	public TransitionChooserFactory getTransitionChooserFactory() {
		return _transitionChooserFactory;
	}

	public void setTransitionChooserFactory(TransitionChooserFactory transitionChooserFactory) {
		this._transitionChooserFactory = transitionChooserFactory;
	}

	public StatsCollector getStatsCollector() {
		return _statsCollector;
	}

	public void setStatsCollector(StatsCollector _statsCollector) {
		this._statsCollector = _statsCollector;
	}

	public String getUserName() {
		return userName;
	}

	public void setUserName(String userName) {
		this.userName = userName;
	}
	
	private class ResetTimeoutHandler implements Runnable {

		private User theUser = null;
		private Behavior theBehavior = null;
		public ResetTimeoutHandler(User user, Behavior behavior) {
			theUser = user;
			theBehavior = behavior;
		}
		
		@Override
		public void run() {
			/*
			 * If this is called, then the reset has taken to long.
			 * Force completion and cleanup.
			 */
			logger.info("ResetTimeoutHandler forcing completeReset for user " + theUser.getId() + ", main behavior = " + theBehavior.getBehaviorId()
			+ ", subBehavior Ids: " + theBehavior.getSubBehaviorIdsString());

			theUser.completeReset(theBehavior);
			
			
		}
		
	}



}

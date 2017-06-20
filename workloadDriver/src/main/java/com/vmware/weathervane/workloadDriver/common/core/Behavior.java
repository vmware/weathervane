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
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooser;
import com.vmware.weathervane.workloadDriver.common.chooser.TransitionChooserResponse;
import com.vmware.weathervane.workloadDriver.common.http.HttpTransport;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.random.NegativeExponential;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

/**
 * @author Hal
 * 
 */
public class Behavior implements OperationCompleteCallback {

	/**
	 * If this is set to true then this user's behaviours will use think-time
	 * rather than cycle-time when  determining inter-op delays
	 */
	private boolean _useThinkTime = false;

	/**
	 * The unique ID for this behavior
	 */
	private UUID _behaviorId;

	private HttpTransport _httpTransport;
	
	private Behavior _parentBehavior = null;

	private Map<UUID, Behavior> _subBehaviors = new HashMap<UUID, Behavior>();

	/**
	 * These are the sub-behaviors that are not scheduled to be stopped
	 */
	private List<UUID> _activeSubBehaviors = new ArrayList<UUID>();
	
	/**
	 * If this behavior is about to run an operation that will start an
	 * asynchronous behavior, then it first creates the behavior object that will
	 * execute that behavior. While this behavior isn't actually started until
	 * the new operation completes, it must be created first so that any data
	 * returned by the operation can be stored using the new async behavior's
	 * ID.
	 */
	private Behavior _pendingAsyncBehavior = null;

	private boolean _stop = false;

	private boolean _opStopped = false;

	private StatsCollector _statsCollector = null;

	private List<Operation> _operations;
	private Map<String, TransitionChooser> _transitionChoosers;

	private Operation _currentOperation = null;
	
	/**
	 * This is the list of behaviors that should be stopped when 
	 * the current operation completes.  It was selected by the 
	 * transitionChooser of the previous operation 
	 */
	private List<UUID> _behaviorsToStopOnOperationComplete;
		
	private long _nextOperationStartTime;

	private User _user;

	private BehaviorSpec _behaviorSpec;

	private List<Operation> _operationsRun = new ArrayList<Operation>();

	protected Random _randomNumberGenerator;

	private UUID _selectedAsyncId;

	private Target _target;

	private static final Logger logger = LoggerFactory.getLogger(Behavior.class);

	public Behavior(User user, BehaviorSpec behaviorSpec,
			StatsCollector statsCollector, Target target) {
		
		logger.debug("Creating Behavior with BehaviorSpec named: " + behaviorSpec.getName());
		
		_user = user;
		_behaviorSpec = behaviorSpec;
		_statsCollector = statsCollector;
		_target = target;

		// Give this behavior a unique If
		_behaviorId = UUID.randomUUID();

		_randomNumberGenerator = new java.util.Random();

		// Create the transition chooser objects for the behavior
		_transitionChoosers = getTransitionChoosers();

	}

	/**
	 * 
	 */
	public void start() {

		logger.debug("Behavior:start User = " + _user.getId() + ", Behavior UUID = " + _behaviorId);
				
		_stop = false;
		_currentOperation = null;
		_behaviorsToStopOnOperationComplete = null;
		_nextOperationStartTime = System.currentTimeMillis();
				
		startNextOperation(true);
		
	}

	/**
	 * Signals this behavior to stop. The behavior must stop all of its
	 * sub-behaviors as well.
	 * 
	 */
	public void stop() {
		/*
		 * Set the stop flag. This will cause the behavior to stop once the
		 * current operation has completed. If the behavior is stopped, the
		 * results of the operation won't be counted on the scoreboard or in the
		 * error count.
		 */
		logger.debug("Behavior:stop User = " + _user.getId() + " behavior = " + _behaviorId
				+ ", _subBehaviors = " + getSubBehaviorIdsString());
		_stop = true;
//		if (_currentOperation != null) {
//			try {
//				_currentOperation.closeCurrentResponse();
//			} catch (IOException e) {
//				logger.warn("Couldn't close response for ", _currentOperation.getOperationName(), " for behavior UUID ",
//						getBehaviorId(), ". Reason: ", e.getMessage());
//			}
//		}
		
		List<Behavior> subBehaviorList = new ArrayList<Behavior>(_subBehaviors.values());
		for (Behavior behavior : subBehaviorList) {
			_activeSubBehaviors.remove(behavior.getBehaviorId());
			behavior.stop();
		}
	}
	
	/**
	 * When this behavior's operation stops due to the
	 * stop flag, it uses this method to notify the behavior that it 
	 * is doing so.
	 */
	public void opStopped() {
		logger.debug("Behavior:opStopped User = " + _user.getId() + " behavior = " + _behaviorId);
		_opStopped = true;
		
		checkIfFullyStopped();
	}

	/**
	 * This method is called to allow a parent behavior to clean up when one of
	 * its subBehaviors stops for any reason.
	 */
	protected void childStopping(UUID subBehaviorID) {
		logger.debug("childStopping.  parent Behavior Id =  " + _behaviorId + ", child behavior Id = " + subBehaviorID);
		_subBehaviors.remove(subBehaviorID);
		
		checkIfFullyStopped();
	}
	
	/**
	 * A behavior is only fully stopped if its operation
	 * has acknowledged the stop, and all of its subbehaviors
	 * have fully stopped
	 */
	protected void checkIfFullyStopped() {
		logger.debug("checkIfFullyStopped.  Behavior Id =  " + _behaviorId
				+ ", _stop = " + _stop + ", _opStopped = " + _opStopped
				+ ", _subBehaviors.isEmpty = " + _subBehaviors.isEmpty());
		if (_stop && _opStopped && _subBehaviors.isEmpty()) {
			logger.debug("checkIfFullyStopped.  isFullyStopped Behavior Id =  " + _behaviorId);
			_user.clearBehaviorState(_behaviorId);
			_activeSubBehaviors.clear();
			
			/*
			 * This behavior is fully stopped.  Notify its
			 * parent.  If no parent, then the reset of the 
			 * user can complete
			 */
			if (_parentBehavior != null) {
				_parentBehavior.childStopping(_behaviorId);
			} else {
				_user.completeReset(this);
				_user = null;
				_httpTransport = null;
			}
		}
	}

	/*
	 * (non-Javadoc)
	 * 
	 * @see
	 * com.vmware.weathervane.workloadDriver.common.core.OperationCompleteCallback#operationComplete
	 * ()
	 */
	@Override
	public void operationComplete() {
		
		/*
		 * Remove the callback so it doesn't get called again
		 */
		_currentOperation.removeOperationCompleteChangeCallback(this);

		
		/*
		 * Only one behavior per user can be going through the 
		 * completion process or startNextOp process at a time
		 */
		synchronized (_user) {
						
			if (logger.isDebugEnabled()) {
				String msg = "Behavior:operationComplete User " + _user.getId()
						+ ", Behavior UUID = " + _behaviorId;
				if (_parentBehavior != null) {
					msg += ", Parent Behavior UUID = " + getParentBehavior().getBehaviorId();
				}
				msg += ", operation = " + _currentOperation.getOperationName();
				logger.debug(msg);
			}

			long now = System.currentTimeMillis();

			/*
			 * Check whether the just completed operation is one that causes a
			 * reset of the user state (e.g. a logout)
			 */
			Boolean[] resetState = _behaviorSpec.getIsResetState();
			if (resetState[_currentOperation.getOperationIndex()]) {
				/*
				 * The last operation was a reset state. Reset the user
				 */
				if (logger.isInfoEnabled()) {
					String msg = "Behavior:operationComplete User " + _user.getId()
							+ ", Behavior UUID = " + _behaviorId;
					if (_parentBehavior != null) {
						msg += ", Parent Behavior UUID = " + getParentBehavior().getBehaviorId();
					}
					msg += ", operation = " + _currentOperation.getOperationName()
							+ " Resetting user and restarting ";
					logger.info(msg);
				}

				/*
				 * The last operation was a reset state. Let the user know to
				 * reset. This will stop this behavior and start a new behavior
				 */
				_user.startReset();
			}

			/*
			 * Only undertake the steps required to set up and run the next
			 * operation if this behavior has not been told to stop and it is
			 * not time to end.
			 */
			if (!_stop) {

				/*
				 * Decide whether any sub-behavior should be stopped. This was
				 * decided by the transition chooser of the previous operation
				 */
				if (_behaviorsToStopOnOperationComplete != null) {
					for (UUID id : _behaviorsToStopOnOperationComplete) {
						logger.debug("Behavior:operationComplete User " + _user.getId()
								+ ", Behavior UUID = " + _behaviorId
								+ " Based on previous transition, stopping subbehavior with UUID "
								+ id);
						_subBehaviors.get(id).stop();
						_activeSubBehaviors.remove(id);
					}
				}

				/*
				 * Check whether we previously decided that what is now the last
				 * operation should start an asynchronous behavior
				 */
				if (_pendingAsyncBehavior != null) {
					_subBehaviors.put(_pendingAsyncBehavior.getBehaviorId(), _pendingAsyncBehavior);
					_pendingAsyncBehavior.start();
					_activeSubBehaviors.add(_pendingAsyncBehavior.getBehaviorId());
					
					_pendingAsyncBehavior = null;
				}

			}
			
			/*
			 * Set opStopped since there is no operation running. If
			 * the behavior is fully stopped then this will finish 
			 * any outstanding reset
			 */
			_opStopped = true;
		}
				
		// Now start the next operation
		startNextOperation(false);		

	}
	
	protected void startNextOperation(boolean firstOp) {

		/*
		 * Only one behavior per user can be going through the 
		 * completion process or startNextOp process at a time
		 */
		synchronized (_user) {
			logger.debug("startNextOperation User = " + _user.getId() + ", Behavior UUID = "
					+ _behaviorId );

			if (_stop) {
				logger.debug("startNextOperation: Stopping User = " + _user.getId()
						+ ", behavior = " + _behaviorId);
				checkIfFullyStopped();
				return;
			}

			TransitionChooserResponse chooserResponse = null;
			if (firstOp) {
				/*
				 * There is no transition chooser for the initial operation, so
				 * we just send along a dummy transitionChooserResponse.
				 */
				chooserResponse = new TransitionChooserResponse(0, null, null, null);

			} else {

				/*
				 * Set up the transition chooser for the just completed
				 * operation with all of the data it needs to make the
				 * transition decisions
				 */
				String transitionChooserName = _behaviorSpec.getTransitionChoosers()[_currentOperation
						.getOperationIndex()];
				TransitionChooser chooserForCompletedOp = _transitionChoosers.get(transitionChooserName);
				_user.prepareSharedData(chooserForCompletedOp, _behaviorId, _behaviorId);

				/*
				 * Use the transitionChooser for the current operation to select
				 * the information needed for selecting the next operation and
				 * the data on which it should operate
				 */
				try {
					chooserResponse = chooserForCompletedOp.chooseTransition();
				} catch (RuntimeException ex) {
					if (logger.isWarnEnabled()) {
						logger.warn("startNextOperation Exception when choosing transition.  AsyncId = " + _behaviorId + " Exception: " + ex.getMessage()
								+ ". Operation = " + _currentOperation.getOperationName());
						ex.printStackTrace();
					}
					/*
					 * Restart the user
					 */
					_user.startReset();
					this.opStopped();
				}

				// Save the list of behaviors to stop after this operation
				_behaviorsToStopOnOperationComplete = chooserResponse.getBehaviorsToStopAtEnd();
				
				/* 
				 * Clean up the current operation
				 */
				_currentOperation.stop();

			}

			/*
			 * Check whether the transitionChooser selected any async behaviors
			 * to be stopped before the next operation executes.
			 */
			if (chooserResponse.getBehaviorsToStopAtStart() != null) {
				for (UUID id : chooserResponse.getBehaviorsToStopAtStart()) {
					logger.debug("startNextOperation User " + _user.getId() + ", Behavior UUID = "
							+ _behaviorId + " Stopping subbehavior with UUID " + id);
					_activeSubBehaviors.remove(id);
					_subBehaviors.get(id).stop();
				}
			}

			// Get the start time for the next operation
			long operationStartTime = nextStartTime();

			// Choose the next operation to execute
			_currentOperation = nextRequest(chooserResponse.getChosenTransitionMatrix());
			int currentOpIndex = _currentOperation.getOperationIndex();

			// Choose the cycleTime for the new operation
			chooseCycleTime(_currentOperation);			
			
			/*
			 * Check whether the next operation will initiate an asynchronous
			 * behavior. If so, set up for the async behavior so that any data
			 * generated by the next operation that is specific to a single
			 * async behavior can be associated with the asyncId of the yet to
			 * be created thread.
			 */
			String[] asyncBehaviors = _behaviorSpec.getAsyncBehaviors();
			if ((asyncBehaviors != null) && !asyncBehaviors[currentOpIndex].equals("none")
					&& (_activeSubBehaviors.size() < _behaviorSpec.getMaxNumAsyncBehaviors())) {
				String asyncMixName = asyncBehaviors[currentOpIndex];
				/*
				 * Create a new asynchronous sub-behavior
				 */
				BehaviorSpec spec = BehaviorSpec.getBehaviorSpec(asyncMixName);
				_pendingAsyncBehavior = new Behavior(_user, spec,_statsCollector, _target);
				UUID behaviorId = _pendingAsyncBehavior.getBehaviorId();
				_pendingAsyncBehavior.setOperations(_user.getOperationFactory().getOperations(_statsCollector, _user, _pendingAsyncBehavior, _target));
				for (Operation operation : _pendingAsyncBehavior.getOperations()) {
					_user.prepareData(operation, behaviorId, behaviorId);
				}
				
				_pendingAsyncBehavior.setTransitionChoosers(_user.getTransitionChooserFactory().getTransitionChoosers(_randomNumberGenerator, _pendingAsyncBehavior));
				for (TransitionChooser transitionChooser : _pendingAsyncBehavior.getTransitionChoosers().values()) {
					_user.prepareData(transitionChooser, behaviorId, behaviorId);
				}
				
				_pendingAsyncBehavior.setHttpTransport(_httpTransport);
				_pendingAsyncBehavior.setParentBehavior(this);
				logger.debug("startNextOperation User " + _user.getId() + ", Behavior UUID = "
						+ _behaviorId + " created new subbehavior with behaviorId = " + _pendingAsyncBehavior.getBehaviorId());
			}

			/*
			 * Check whether the next operation is one that causes subBehaviors
			 * to be stopped. If so, stop them.
			 */
			logger.debug("Checking if next operation is a reset state for opIndex " + currentOpIndex);
			Boolean[] resetState = _behaviorSpec.getIsResetState();
			if (resetState[currentOpIndex]) {
				/*
				 * The next operation is a reset state. Stop the subBehaviors
				 */
				if (logger.isInfoEnabled()) {
					String msg = "Behavior:startNextOperation User " + _user.getId()
							+ ", Behavior UUID = " + _behaviorId;
					if (_parentBehavior != null) {
						msg += ", Parent Behavior UUID = " + getParentBehavior().getBehaviorId();
					}
					msg += ", operation = " + _currentOperation.getOperationName()
							+ " Stopping sub-behaviors: ";
					msg += this.getSubBehaviorIdsString();
					logger.info(msg);
				}

				/*
				 * Stop all of the sub-behaviors
				 */
				List<Behavior> subBehaviorList = new ArrayList<Behavior>(_subBehaviors.values());
				for (Behavior behavior : subBehaviorList) {
					_activeSubBehaviors.remove(behavior.getBehaviorId());
					behavior.stop();
				}
			}

			/*
			 * For some operations, the transition chooser will indicate that
			 * data needed by the next operation should be used from a
			 * sub-behavior, rather than the current behavior. The ID of that
			 * behavior is the selectedAsyncId
			 */
			_selectedAsyncId = chooserResponse.getBehaviorToUseAsDataSource();
			if (_selectedAsyncId == null) {
				_selectedAsyncId = _behaviorId;
			}
			logger.debug("startNextOperation User " + _user.getId() + ", Behavior UUID = "
					+ _behaviorId + " behaviorToUseAsDataSource for currentOperation "
					+ _currentOperation.getOperationName() + " is " + _selectedAsyncId);

			/*
			 * If there is an async behavior that will start after this
			 * operation completes, then the data from this operation should be
			 * stored using the UUID of that behavior.
			 */
			UUID pendingAsyncBehaviorId = _selectedAsyncId;
			if (_pendingAsyncBehavior != null) {
				pendingAsyncBehaviorId = _pendingAsyncBehavior.getBehaviorId();
			}
			logger.debug("startNextOperation User " + _user.getId() + ", Behavior UUID = "
					+ _behaviorId + " behaviorToUseAsDataSink for currentOperation "
					+ _currentOperation.getOperationName() + " is " + pendingAsyncBehaviorId);

			_user.prepareSharedData((Operation) _currentOperation, _selectedAsyncId,
					pendingAsyncBehaviorId);
			// rememberOperation((GenericOperation) _currentOperation);

			long now = System.currentTimeMillis();
			long opStartDelay = operationStartTime - now;
			if (opStartDelay < 0) {
				opStartDelay = 0;
			}

			logger.debug("startNextOperation User " + _user.getId() + ", Behavior UUID = "
					+ _behaviorId + ", nextOperation = " + _currentOperation.getOperationName()
					+ " Scheduling for " + opStartDelay + " milliseconds from now. now = " + now
					+ " operationStartTime = " + operationStartTime);

			_currentOperation.start(opStartDelay);
			
			// Set opStopped since there is now an operation running
			_opStopped = false;

		}
	}
	
	public HttpTransport getHttpTransport() {
		return _httpTransport;
	}

	public void setHttpTransport(HttpTransport httpTransport) {
		this._httpTransport = httpTransport;
	}
	
	/**
	 * Determine the start time of the next operation, based on the current
	 * operation and its starting time.
	 */
	protected void chooseCycleTime(Operation operation) {
				
		long meanCycleTime = _behaviorSpec.getMeanCycleTime(operation.getOperationIndex()) * 1000;

		/*
		 * Randomize the cycle time to be exponentially distributed with the
		 * given mean.
		 */
		long cycleTime = (long) Math.ceil(NegativeExponential.getNext(meanCycleTime));
		logger.debug("meanCycleTime = " + meanCycleTime + ", cycleTime = " + cycleTime);
		operation.setCycleTime(cycleTime);

	}
	
	/**
	 * Determine the start time of the next operation, based on the current
	 * operation and its starting time.
	 */
	protected long nextStartTime() {
		long currentStartTime = _nextOperationStartTime;
		long nextTime;

		long now = System.currentTimeMillis();
		
		/*
		 * If the currentOperation is null, as it will be at the start,
		 * then the next operation should start right away
		 */
		if (_currentOperation == null) {
			_nextOperationStartTime = now;
			return now;
		}
		
		long cycleTime = _currentOperation.getCycleTime();
		
		/*
		 * If we are using think-time, then then next start time is always the
		 * stated delay from now, rather than being based on the start time of the 
		 * previous operation. 
		 */
		if (_useThinkTime) {
			nextTime = now + cycleTime;
		} else {
			nextTime = currentStartTime + cycleTime;			
		}

		if (nextTime < now) {
			/*
			 * We missed the cycle time, or the cycle-time is 0.
			 */
			nextTime = now;
		}

		/*
		 * Save the next operation start time to be used when calculating the
		 * next start time
		 */
		_nextOperationStartTime = nextTime;
		
		/*
		 * Start the next operation at the cycleTime for the current operation
		 * after the current operation started.
		 */
		return nextTime;
	}

	/**
	 * 
	 */
	protected Operation nextRequest(int transitionMatrixId) {

		logger.debug("Behavior:nextRequest User = " + _user.getId()
				+ " behavior ID = " + _behaviorId + " current operation = "
				+ _currentOperation + ", transitionMatrixId = " + transitionMatrixId);

		int nextOperationIndex = -1;
		Operation result = null;

		if (_currentOperation == null) {
			nextOperationIndex = _behaviorSpec.getInitialState();
		} else {

			Double[][][] selectionMix = _behaviorSpec.getSelectionMix();

			Double[] mixForLastOperation = selectionMix[_currentOperation.getOperationIndex()][transitionMatrixId];
			
			Double selection = _randomNumberGenerator.nextDouble();
			for (int i = 0; i < mixForLastOperation.length; i++) {
				if (selection < mixForLastOperation[i]) {
					nextOperationIndex = i;
					break;
				}
			}
		}
		
		try {
			result = _operations.get(nextOperationIndex);
			logger.debug("Behavior:nextRequest User = " + _user.getId()
			+ " behavior ID = " + _behaviorId 
			+ " nextOperationIndex = " + nextOperationIndex
			+ " nextOperation = " + result.getOperationName());

			result.setHttpTransport(_httpTransport);
			result.registerOperationCompleteCallback(this);
			
			logger.debug("nextRequest User = " + _user.getId() + " behavior ID = " + _behaviorId
					+ " generated operation " + result.getOperationName() + " with behaviorId "
					+ result.getBehaviorId() + ", result = " + result );
		} catch (Exception e) {
			logger.error("nextRequest.  generating operation threw " + e.getMessage());
			e.printStackTrace();
			throw new RuntimeException(e);
		}
		
		logger.debug("Behavior:nextRequest User = " + _user.getId()
				+ " behavior ID = " + _behaviorId + " Returning operation " + result.getOperationName() 
				+ " with behaviorId " + result.getBehaviorId() + ", result = " + result);
		return result;
	}

	/*
	 * Each operation gets added to a remembered list, so that subsequent
	 * operations can query whether or not those operations have occurred
	 */
	public void rememberOperation(Operation operation) {
		synchronized (_operationsRun) {
			_operationsRun.add(operation);
		}
	}

	public void clearRememberedOperations() {
		synchronized (_operationsRun) {
			_operationsRun.clear();
		}
	}

	/**
	 * Checks to see whether an operation is of a particular polymorphic type.
	 * This is very important as the interfaces of an operation determine the
	 * state that it proves and the state that it needs. To look for a
	 * particular operation that provides project IDs for example, you would
	 * look for an operation of type @PidProvider
	 */
	private boolean isOperationOfType(Operation go, Class<?> type) {
		if (type.isInterface()) {
			for (Class<?> i : go.getClass().getInterfaces()) {
				if (i.equals(type))
					return true;
			}
		} else {
			if (type.isAssignableFrom(go.getClass()))
				return true;
		}
		return false;
	}

	/**
	 * Looks through the remembered operation list looking for a particular
	 * operation of a particular type
	 */
	protected Operation checkForLastRememberedOperationOfType(Class<?> type) {
		synchronized (_operationsRun) {
			for (Operation go : _operationsRun) {
				if (isOperationOfType(go, type)) {
					return go;
				}
			}
		}
		return null;
	}

	public UUID getBehaviorId() {
		return _behaviorId;
	}

	public Map<UUID, Behavior> getSubBehaviors() {
		return _subBehaviors;
	}

	public boolean isStopped() {
		return _stop;
	}

	public Operation getCurrentOperation() {
		return _currentOperation;
	}

	public Behavior getParentBehavior() {
		return _parentBehavior;
	}

	public void setParentBehavior(Behavior _parentBehavior) {
		this._parentBehavior = _parentBehavior;
	}

	public String getSubBehaviorIdsString() {
		if (_subBehaviors == null)
			return "";
		String msg = "";
		for (Behavior subBehavior : _subBehaviors.values()) {
			msg +=  subBehavior.getBehaviorId() + " ; " +
			subBehavior.getSubBehaviorIdsString();
		}
		return msg;
	}

	public List<UUID> getActiveSubBehaviors() {
		return _activeSubBehaviors;
	}
	

	public String getActiveSubBehaviorIdsString() {
		String msg = "";
		for (UUID subBehaviorId : _activeSubBehaviors) {
			msg += " ; " + subBehaviorId;
		}
		return msg;
	}

	public boolean isUseThinkTime() {
		return _useThinkTime;
	}

	public void setUseThinkTime(boolean useThinkTime) {
		this._useThinkTime = useThinkTime;
	}

	public BehaviorSpec getBehaviorSpec() {
		return _behaviorSpec;
	}

	public void setBehaviorSpec(BehaviorSpec behaviorSpec) {
		this._behaviorSpec = behaviorSpec;
	}

	public List<Operation> getOperations() {
		return _operations;
	}

	public void setOperations(List<Operation> operations) {
		this._operations = operations;
	}

	public Map<String, TransitionChooser> getTransitionChoosers() {
		return _transitionChoosers;
	}

	public void setTransitionChoosers(Map<String, TransitionChooser> transitionChoosers) {
		this._transitionChoosers = transitionChoosers;
	}

	@Override
	public String getOperationCompleteCallbackName() {
		return getBehaviorId().toString();
	}

	public StatsCollector getStatsCollector() {
		return _statsCollector;
	}

	public void setStatsCollector(StatsCollector _statsCollector) {
		this._statsCollector = _statsCollector;
	}


}

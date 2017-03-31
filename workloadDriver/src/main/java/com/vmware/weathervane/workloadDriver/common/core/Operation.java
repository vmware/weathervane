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

import java.net.URI;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.LinkedList;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.UUID;
import java.util.concurrent.Executors;
import java.util.concurrent.ScheduledExecutorService;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;

import org.json.JSONObject;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.core.StateManagerStructs.DataListener;
import com.vmware.weathervane.workloadDriver.common.exceptions.OperationFailedException;
import com.vmware.weathervane.workloadDriver.common.http.FileUploadInfo;
import com.vmware.weathervane.workloadDriver.common.http.HttpRequestCompleteCallback;
import com.vmware.weathervane.workloadDriver.common.http.HttpTransport;
import com.vmware.weathervane.workloadDriver.common.model.target.Target;
import com.vmware.weathervane.workloadDriver.common.statistics.OperationStats;
import com.vmware.weathervane.workloadDriver.common.statistics.StatsCollector;

import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpResponseStatus;

/**
 * @author Hal
 * 
 */
public abstract class Operation implements Runnable, HttpRequestCompleteCallback {

	private static final Logger logger = LoggerFactory.getLogger(Operation.class);
	
	private static final ScheduledExecutorService _scheduledExecutor;
	static {
		Integer numScheduledPoolThreads = Integer.getInteger("NUMSCHEDULEDPOOLTHREADS", 
													8 * Runtime.getRuntime().availableProcessors());
		_scheduledExecutor = Executors.newScheduledThreadPool(numScheduledPoolThreads);
		
		Runtime.getRuntime().addShutdownHook(new Thread(new Runnable() {
			
			@Override
			public void run() {
				_scheduledExecutor.shutdownNow();
			}
		}));
		
	}
	
	public static void scheduleRunnable(Runnable runnable) {
		if (!_scheduledExecutor.isShutdown()) {
			_scheduledExecutor.schedule(runnable, 1, TimeUnit.MICROSECONDS);
		}
	}
	
	public static void shutdownExecutor() throws InterruptedException {
		_scheduledExecutor.shutdown();
		_scheduledExecutor.awaitTermination(10, TimeUnit.SECONDS);
	}
	
	public enum UrlType {  GET, POST;  }

	/**
	 * The UserState for the user for which this operation is being executed.
	 */
	private User _user;

	private Target target;

	/**
	 * The behavior associated with the operation
	 */
	private Behavior _behavior;

	/**
	 * An operation may consist of multiple steps. Each step corresponds to at
	 * most one asynchronous HTTP operation. The nextOperationStep indicates the
	 * next step to be executed. It is used by the operation executeOperation
	 * method determine which step to execute when the operation's run() method
	 * is entered.
	 */
	private int _nextOperationStep = 0;

	/**
	 * This is the response info from the most recent HttpRequest, which may be a
	 * recursive get of an embedded link.
	 */
	private HttpResponseStatus _currentResponseStatus;
	private HttpHeaders _currentResponseHeaders;
	private String _currentResponseContent;
	
	/**
	 * This holds the number of simultaneous http GET requests that this operation has
	 * outstanding.  The GetResponseHandler only sets the operation to execute the 
	 * next step when getRequestsOutstanding == 0
	 */
	private AtomicInteger _getRequestsOutstanding = new AtomicInteger(0);
	
	/**
	 * Used to count how many HTTP requests have been issued to the
	 * HTTP transport but not completed
	 */
	private AtomicInteger _requestsOutstanding = new AtomicInteger(0);
	
	/**
	 * This flag is set by the concrete operation's executeOperation method to
	 * indicate that all steps of the operation have been executed.
	 */
	private boolean _operationComplete;

	/**
	 * This flag can be set by a behavior to indicate that a server response
	 * should cause this operation to be ignored in the tally of results.
	 */
	private boolean _ignoreResult = false;

	/**
	 * An array of DataListeners for this operation. This needs to be
	 * initialized by the operations in their constructor.
	 */
	protected DataListener[] _listeners;

	/**
	 * These are the valid response codes for the current step in the operation.
	 * This must be set by the operation at each step.
	 */
	protected int[] _validResponseCodes;

	/**
	 * These are the response codes for the current step in the operation that
	 * should cause the current behavior to be stopped or restarted. These are
	 * not errors, just codes that indicate a special server state that requires
	 * the user to make a decision about stopping or restarting the bahavior.
	 * This must be set by the operation at each step.
	 */
	protected int[] _abortResponseCodes;

	/**
	 * These are the strings that must be contained in the response entity for
	 * the current step in the operation. This must be set by the operation at
	 * each step.
	 */
	protected String[] _mustContainText;

	/**
	 * This is the URL of the current step in the operation.
	 */
	protected SimpleUri _currentURI;

	/**
	 * The number of redirects followed for the current request.
	 */
	protected int _numRedirectsFollowed;

	/**
	 * Whether to follow embedded links for the current HTTP request
	 */
	protected boolean _recursive;

	/**
	 * Whether to check the cache for embedded links on the current operation.
	 */
	protected boolean _checkCacheForRecursive;

	/**
	 * The list of embedded links that need to be followed recursively for the
	 * current operation.
	 */
	private List<UrlToLoad> _embeddedLinks = new ArrayList<UrlToLoad>();

	/**
	 * A list of objects which want to be notified when this operation
	 * completes.
	 */
	private List<OperationCompleteCallback> _operationCompleteCallbacks = new LinkedList<OperationCompleteCallback>();
	
	private HttpTransport _httpTransport;

	private StatsCollector _statsCollector;

	/*
	 * Store the _cycleTime so that it can be added to the operationStats
	 */
	private long _cycleTime;

	// Describes the operation
	protected int _operationIndex       = -1;
	private String _operationName     = "";

	protected boolean _failed           = false;
	protected Throwable _failureReason  = null;
	protected String _failureString = null;
	
	private long _timeStarted           = 0;
	private long _timeFinished          = 0;
	
	private Random _randomNumberGenerator;
	
	private List<SimpleUri> _getUrls = new ArrayList<SimpleUri>();
	private List<SimpleUri> _postUrls = new ArrayList<SimpleUri>();

	// Used to collect execution metrics
	protected long _totalSteps    = 0; 
	
	abstract public String provideOperationName();

	/**
	 * This method is used to register a callback completion of the operation
	 */
	public boolean registerOperationCompleteCallback(OperationCompleteCallback _callbackObject) {
		return _operationCompleteCallbacks.add(_callbackObject);
	}

	/**
	 * Remove a callback from the list of objects to be notified when the
	 * operation completes
	 */
	public boolean removeOperationCompleteChangeCallback(OperationCompleteCallback _callbackObject) {
		return _operationCompleteCallbacks.remove(_callbackObject);
	}

	public List<OperationCompleteCallback> getOperationCompleteCallbacks() {
		return _operationCompleteCallbacks;
	}

	/**
	 * @param interactive
	 * @param scoreboard
	 * @param operationId
	 */
	public Operation(User userState,
			Behavior behavior, Target target, StatsCollector statsCollector) {
		setOperationName(provideOperationName());
		setUser(userState);
		_behavior = behavior;
		this.target = target;
		this._statsCollector = statsCollector;
		_nextOperationStep = 0;
	}
	
	
	public void start(long startDelayMs) {
		_scheduledExecutor.schedule(this, startDelayMs, TimeUnit.MILLISECONDS);
	}
	
	private void reschedule() {
		if (!_scheduledExecutor.isShutdown()) {
			logger.info("Operation:reschedule Rescheduling " + getOperationName() + " for behavior UUID "
					+ _behavior.getBehaviorId());
			_scheduledExecutor.schedule(this, 1, TimeUnit.MICROSECONDS);
		}
	}
	
	public void stop() {
		_currentResponseStatus = null;
		_currentResponseHeaders = null;
		_currentResponseContent = null;
		_nextOperationStep = 0;
		_getRequestsOutstanding.getAndSet(0);
		_operationComplete = false;
		_embeddedLinks.clear();
		_listeners = null;
		_validResponseCodes = null;
		_abortResponseCodes = null;
		_mustContainText = null;
		_currentURI = null;
		_numRedirectsFollowed = 0;
		_recursive = false;
		_checkCacheForRecursive = false;
		_embeddedLinks.clear();
		_operationCompleteCallbacks.clear();
		_failed = false;
		_failureReason = null;
		_failureString = null;
		setTimeStarted(0);
		setTimeFinished(0);
		_totalSteps = 0;
	}

	private boolean isAbortStatusCode(int statusCode, int[] abortCodes) {
		for (int code : abortCodes) {
			if (statusCode == code) {
				return true;
			}
		}
		return false;
	}

	private void checkStatusCode(int statusCode, int[] validCodes) {
		boolean found = false;
		String errorMessage = null;
		for (int code : validCodes) {
			if (statusCode == code) {
				found = true;
				break;
			}
		}
		if (!found) {
			errorMessage = getOperationName() + " ERROR - unexpected response code: " + statusCode 
					+ " behavior UUID = " + _behavior.getBehaviorId();
		}
		if (errorMessage != null) {
			logger.error(errorMessage);
			throw new RuntimeException(errorMessage);
		}
	}

	private void checkResponse(String response, String[] mustContainText) {
		logger.debug("Operation:checkResponse for behavior UUID "
					+ _behavior.getBehaviorId() +
				" mustContainText length = " + mustContainText.length);

		String errorMessage = null;
		if (response.length() == 0) {
			logger.info("Operation:run Starting " + getOperationName() + " for behavior UUID "
					+ _behavior.getBehaviorId() + ", _behavior.isStopped() = " + _behavior.isStopped()
					+ ", isIgnoreResult = " + isIgnoreResult());
			
			errorMessage = getOperationName() + " ERROR - Received an empty response for behavior UUID = " + _behavior.getBehaviorId();
			logger.debug(errorMessage);
		}
		for (String current : mustContainText) {
			if (response.indexOf(current) < 0) {
				errorMessage = getOperationName() + " ERROR - Response " + response.toString() 
						+ " doesn't contain required string " + current + "\n\tResponse is: " + response.toString()
						+ " behavior UUID = " + _behavior.getBehaviorId();
				logger.debug(errorMessage);
			}
		}
		if (errorMessage != null) {
			logger.error(errorMessage);
			throw new RuntimeException(errorMessage);
		}
		logger.debug("Operation:checkResponse for behavior UUID "
				+ _behavior.getBehaviorId() + " returning");

	}
	
	/**
	 * This method is used to run this operation. By default, it records any
	 * metrics when executing. This can be overridden to make a single call to
	 * <code>execute()</code> for more fine-grained control. This method must
	 * catch any <code>Throwable</code>s.
	 */
	@Override
	public void run() {

		if (_nextOperationStep == 0) {
			logger.info("Operation:run Starting " + getOperationName() + " for behavior UUID "
					+ _behavior.getBehaviorId() + ", _behavior.isStopped() = " + _behavior.isStopped()
					+ ", isIgnoreResult = " + isIgnoreResult());
		} else {
			logger.debug("Operation:run Running " + getOperationName() + " for behavior UUID "
					+ _behavior.getBehaviorId() + " nextOperationStep = " + _nextOperationStep
					+ " isFailed = " + isFailed() + " _failureString = " + getFailureString()
					+ ", _behavior.isStopped() = " + _behavior.isStopped()
					+ ", isIgnoreResult = " + isIgnoreResult());
		}

		if (_behavior.isStopped()) {
			/*
			 * The behavior associated with this operation has been stopped.
			 * Don't continue executing the operation.
			 */
			logger.debug("Operation:run Behaviour is stopped for behavior UUID "
					+ _behavior.getBehaviorId());
			_behavior.opStopped();
			return;
		}

		/*
		 * This is the first step in the operation. No request has yet been
		 * issued. Perform the setup required before executing the operation.
		 */
		if (_nextOperationStep == 0) {

			/*
			 * This is the first step in the operation. Invoke the pre-execute
			 * hook here before we start the clock to time the operation's
			 * execution
			 */
			long now = System.currentTimeMillis();
			this.setTimeStarted(now);
			this.setFailed(false);

		} else if (!isFailed()) {

			/*
			 * At this point we need to do a number of checks on the response
			 * from the previous step before we start the next step of the
			 * operation. If any of the checks fails, then we throw an
			 * OperationFailedException.
			 */
			try {

				/*
				 * At this point, there should be a response from the previous
				 * step.
				 */
				if (_currentResponseStatus == null) {
					throw new OperationFailedException("Response status is null for operation " + this.getOperationName());
				}
				
				/*
				 * If the response status is an abort code, then something has
				 * happened on the server that requires this operation's
				 * behavior to be stopped. This is not an error,
				 * just a reflection of a change in server state that requires a
				 * change in the flow of operations.
				 */
				int statusCode = _currentResponseStatus.code();
				if (_abortResponseCodes != null) {
					if (isAbortStatusCode(statusCode, _abortResponseCodes)) {
						_user.startReset();
						_behavior.opStopped();
						return;
					}

				}

				/*
				 * Check whether the response has one of the expected response
				 * codes.
				 */
				if (_validResponseCodes != null) {
					try {
						checkStatusCode(statusCode, _validResponseCodes);
					} catch (Exception e) {
						throw new OperationFailedException(e.getMessage());
					}
				}

					
				/*
				 * If we need to check for recursive links, or mustContains 
				 * text, then read the HttpResponse data into a string
				 * and release the buffer. Otherwise we just release the buffer.
				 */
				if (_recursive ||  (_mustContainText != null) ||  (_listeners != null)) {
					
					if (_currentResponseContent == null) {
						throw new OperationFailedException("Attempting parse null content.");
					}
					
					
					if (logger.isDebugEnabled()) {
						if ((_currentResponseContent.charAt(0) == '{') || (_currentResponseContent.charAt(0) == '[')) {
							// Log all of JSON objects
							logger.debug("Operation::run.  behaviorId = " + _behavior.getBehaviorId() 
									+ " current URL = " + _currentURI + " Response buffer = "
									+ _currentResponseContent);
						} else {
							// Just log start of other responses
							logger.debug("Operation::run.  behaviorId = " + _behavior.getBehaviorId() 
									+ " current URL = " + _currentURI
									+ " Response buffer head = " + _currentResponseContent.substring(0, 100));
						}
					}
					
					/*
					 * If there are listeners for data from the response, then 
					 * call the methods to parse the data
					 */
					if  (_listeners != null){
						try {
							parseDataFromResponse(_currentResponseContent, _listeners);
							parseDataFromHeaders(_currentResponseHeaders, _listeners);
						} catch (RuntimeException ex) {
							throw new OperationFailedException(ex.getMessage());
						}
					}
					
					if (_mustContainText != null) {
						/*
						 * Check the response code to make sure that it is on of the
						 * expected codes.
						 */
						try {
							checkResponse(_currentResponseContent, _mustContainText);
						} catch (Exception ex) {
							throw new OperationFailedException(ex.getMessage());
						}
					}

					/*
					 * Check for embedded URLs. If present, and we are doing
					 * recursive GETs on this request, then we need to add them
					 * to the list of URLs to be processed before completing the
					 * operation. We also need to check the browser cache (if
					 * enabled) before saving the URL to be fetched.
					 * 
					 * ToDo: The current implementation serializes the fetching
					 * of embedded links. Really should be able to issue more
					 * than one request at the same time.
					 */
					if (_recursive) {
						List<UrlToLoad> urls = new ArrayList<UrlToLoad>();

						if (_currentResponseContent != null) {
							parseResourceLinksIntoUrls(_currentURI, urls, _currentResponseContent);
						}

						for (UrlToLoad url : urls) {
							// Only add to list of URLs to get if not in cache
							if (!this.getUser().checkCache(url.uri.toString())) {
								_embeddedLinks.add(url);
							}
						}

						/*
						 * If the list of embedded links is not empty, get the
						 * next link rather than scheduling the next step of the
						 * operation.
						 */
						while (!_embeddedLinks.isEmpty()) {
							UrlToLoad url = _embeddedLinks.remove(0);

							if (!_checkCacheForRecursive || !getUser().checkCache(url.uri.toString())) {
								/*
								 * Only load the embedded link if we are not
								 * checking the cache, or it is not in the cache
								 */
								/*
								 * Keep checking whether we are stopped to avoid
								 * extra requests.
								 */
								if (_behavior.isStopped()) {
									/*
									 * The behavior associated with this
									 * operation has been stopped. Don't
									 * continue executing the operation.
									 */
									_behavior.opStopped();
									return;
								}

								// Cache embedded links
								_user.cachePage(url.uri.toString());

								logger.debug(
										"Operation:run Fetching embedded link for behavior UUID " + _behavior.getBehaviorId() + " URL = " + url.uri.toString());

								/*
								 * This recursive get will cause the
								 * getResponseHandler to schedule this operation
								 * again when it has completed, The only
								 * response accepted for a recursive get is 200
								 * - OK, and there is no mustContainsText or
								 * data listeners
								 */
								SimpleUri simpleUri = new SimpleUri(url.uri);
								doHttpGet(simpleUri, null, new int[] { 200 }, null, url.recursive, true, null, null, null);
								return;
							}
						}
					}

				} 


			} catch (OperationFailedException ex) {
								
				/*
				 * Don't count the failure if this operation's behavior was
				 * stopped. The error may be a side effect of the stopping.
				 */
				if (_behavior.isStopped()) {
					_behavior.opStopped();
					return;
				}

				if (logger.isWarnEnabled()) {
					String msg = "Operation:run Operation failed " + getOperationName()
							+ " for behavior UUID " + _behavior.getBehaviorId();
					if (_behavior.getParentBehavior() != null) {
						msg += ", Parent Behavior UUID = "
								+ _behavior.getParentBehavior().getBehaviorId();
					}
					msg += " reason: " + ex.getMessage();
					logger.warn(msg);
					ex.printStackTrace();
				}
				this.setFailed(true);
				this.setFailureReason(new RuntimeException(ex.getMessage()));
				this.setFailureString(ex.toString());
			} 
		}

		/*
		 * If this operation hasn't failed, run the next step in the operation.
		 */
		if (!this.isFailed() && !_behavior.isStopped()) {

			try {

				/*
				 * The callback of the previous step in the operation may have
				 * set isFailed. Only execute the next step if not failed.
				 */
				this.execute();
				
				if (!isOperationComplete()) {
					/*
					 *  If this wasn't the last step, increment the count of 
					 *  actions performed by this operation.
					 */
					this.incrTotalSteps();
				}

				// Set up for the next step of the operation
				_nextOperationStep++;
				_numRedirectsFollowed = 0;

			} catch (Throwable e) {

				this.setFailed(true);
				this.setFailureReason(e);
				this.setFailureString(e.toString());
				logger.warn("Operation:run Execution Failed for " + getOperationName() + " for behavior UUID "
						+ _behavior.getBehaviorId() + " Failure Reason = " + this.getFailureReason());
				if (logger.isDebugEnabled()) {
					e.printStackTrace();
				}
			}
		}

		/*
		 * If the operation is complete, then record the statistics with the
		 * scoreboard.
		 */
		if ((isOperationComplete() || isFailed()) && !_behavior.isStopped() && !isIgnoreResult()) {
			logger.debug("Operation complete for " + getOperationName() + " for behavior UUID "
					+ _behavior.getBehaviorId() );
			long now = System.currentTimeMillis();
			this.setTimeFinished(now);

			logger.debug("Submitting operationStats to statsCollector for operation " + getOperationName() + " for behavior UUID "
						+ _behavior.getBehaviorId() );
			_statsCollector.submitOperationStats(new OperationStats(this));
			
			/*
			 * If the operation has failed, then we need to reset the user and restart 
			 * its primary behavior
			 */
			if (this.isFailed()) {
				logger.warn("Operation:run restarting userId = " + _user.getId() + ", operation = "
						+ getOperationName() + ", behavior UUID " + _behavior.getBehaviorId() 
						+ " Failure Reason = " + this.getFailureReason());
				this.getUser().startReset();
				_behavior.opStopped();
				return;
			}
			
			/*
			 * Signal all objects that have registered a callback that the
			 * operation is complete
			 */
			for (OperationCompleteCallback callbackObject : _operationCompleteCallbacks) {
				logger.debug("run Calling operationComplete  callback for " + getOperationName() + " for behavior UUID "
						+ callbackObject.getOperationCompleteCallbackName() );
				callbackObject.operationComplete();
			}
			
			// Clear the current response buffer
			_currentResponseStatus = null;
			_currentResponseHeaders = null;
			_currentResponseContent = null;
			
		}
		
		if (_behavior.isStopped()) {
			/*
			 * The behavior associated with this
			 * operation has been stopped. Don't
			 * continue executing the operation.
			 */
			_behavior.opStopped();
		}

	}

	/*
	 * Handlers for completion of HttpOperations. Called by the AsyncHttpTransport
	 * when an outstanding operation completes
	 */
	@Override
	public void httpRequestCompleted(HttpResponseStatus status,  HttpHeaders headers, String content, boolean isGet) {

		logger.debug("httpRequestCompleted for behavior UUID "
				+ _behavior.getBehaviorId() 
				+ ", operation = " + this.getOperationName()
				+ ", isGet = " + isGet
				+ ", response status = " + status);	

		_requestsOutstanding.decrementAndGet();

		if (isGet) {
			int outstandingGets = _getRequestsOutstanding.decrementAndGet();
			if (outstandingGets < 0) {
				/*
				 * This shouldn't happen. Set the operation as failed.
				 */
				logger.warn("httpRequestCompleted for behavior UUID " + _behavior.getBehaviorId() + " outstandingGets is less than zero: " + outstandingGets
						+ ", rescheduling as failed");
				_currentResponseStatus = status;
				_currentResponseHeaders = headers;
				_currentResponseContent = content;
				this.setFailed(true);
				this.setFailureString("httpGetRequestCompleted but getRequestsOutstanding < 0");
				this.setFailureReason(new OperationFailedException("getRequestsOutstanding < 0"));
			} else if (outstandingGets > 0) {
				// There are other GETs outstanding. Just clean this one up and
				// return
				logger.debug("httpGetRequestCompleted for behavior UUID " + _behavior.getBehaviorId() + " outstandingGets is still greater than zero: "
						+ outstandingGets);
				return;
			} else {
				logger.debug("httpGetRequestCompleted for behavior UUID " + _behavior.getBehaviorId() + " outstandingGets is zero, rescheduling operation ");
			}
		}
		_currentResponseStatus = status;
		_currentResponseHeaders = headers;
		_currentResponseContent = content;

		/*
		 * Schedule the operation for immediate re-execution.
		 */
		this.reschedule();

	}
	
	@Override
	public void httpRequestFailed(Throwable ex, boolean isGet) {
		logger.debug("httpRequestFailed for userId = " + _user.getId()
				+ ", behavior UUID " + _behavior.getBehaviorId() 
				+ ", operation = " + this.getOperationName()
				+ ", isGet = " + isGet
				+ ". Exception : " + ex.getMessage());	
		
		_requestsOutstanding.decrementAndGet();
		
		// Record the failure and then reschedule the operation
		// so that the failure is recorded in the Scoreboard
		_currentResponseStatus = null;
		_currentResponseHeaders = null;
		_currentResponseContent = null;
		this.setFailed(true);
		this.setFailureReason(ex);
		this.setFailureString(ex.toString());

		if (isGet) {
			int outstandingGets = _getRequestsOutstanding.decrementAndGet();
			if (outstandingGets > 0) {
				// There are other GETs outstanding. Just clean this one up and
				// return
				logger.warn("httpGetRequestFailed for behavior UUID " + _behavior.getBehaviorId() + " outstandingGets is still greater than zero: "
						+ outstandingGets);
				return;
			}
		}
		logger.debug("httpRequestFailed for behavior UUID " + _behavior.getBehaviorId() + ", rescheduling operation ");

		/*
		 * Schedule the operation for immediate re-execution.
		 */
		this.reschedule();
		
	}

	/*** URL HANDLING Delete ***/

	/**
	 * Main method for Http GET requests. If recursive==true, the result of the
	 * GET will be parsed for src= urls and those will be loaded and parsed.
	 * This can be done to any depth. If checkCache==true, the page cache will
	 * be checked before attempting the GET
	 */
	protected void doHttpDelete(SimpleUri uri, Map<String, String> urlBindVariables, int[] validResponseCodes, int[] abortResponseCodes,
			 String[] mustContainText, DataListener[] listeners,
			Map<String, String> headers) {
				
		/*
		 * Set up the variables that will be used when checking the response,
		 * which arrives asynchronously in the FutureCallback
		 */
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = listeners;
		_currentURI = uri;

		/*
		 * Kick off the HTTP operation. This thread will not wait for the
		 * response. Instead, the httpPostRequestCompleted() method will
		 * be called when the response is ready.
		 */
		_httpTransport.executeDelete(uri, urlBindVariables, headers, this, false);
		
		_requestsOutstanding.incrementAndGet();
		
	}
	
	/*** URL HANDLING GET ***/

	/**
	 * Main method for Http GET requests. If recursive==true, the result of the
	 * GET will be parsed for src= urls and those will be loaded and parsed.
	 * This can be done to any depth. If checkCache==true, the page cache will
	 * be checked before attempting the GET
	 */
	protected void doHttpGet(SimpleUri uri, Map<String, String> urlBindVariables, int[] validResponseCodes, int[] abortResponseCodes,
			boolean recursive, boolean checkCacheForRecursive, String[] mustContainText, DataListener[] listeners,
			Map<String, String> headers) {
		logger.debug("doHttpGet with uri " + uri.getUriString());

		/*
		 * If the operation did not set the number of get requests that
		 * it will issue (_getRequestsOutstanding == 0), then set the
		 * number to 1
		 */
		_getRequestsOutstanding.compareAndSet(0, 1);
		
		/*
		 * Set up the variables that will be used when checking the response,
		 * which arrives asynchronously in the FutureCallback
		 */
		_recursive = recursive;
		_checkCacheForRecursive = checkCacheForRecursive;
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = listeners;
		_currentURI = uri;

		boolean dropResponse = false;
		if ((mustContainText == null) && (listeners == null) && !recursive) {
			dropResponse = true;
		}
		
		/*
		 * Kick off the HTTP operation. This thread will not wait for the
		 * response. Instead, the httpGetRequestCompleted() method will
		 * be called when the response is ready.
		 */
		_httpTransport.executeGet(uri, urlBindVariables, headers, this, dropResponse);
		
		_requestsOutstanding.incrementAndGet();
		
	}

	/*** URL HANDLING POST ***/

	/**
	 * doHttpPostFiles will do multipart POST files  
	 */
	protected void doHttpPostFiles(SimpleUri uri, Map<String, String> urlBindVariables, List<FileUploadInfo> fileUploads,
			int[] validResponseCodes, 
			int[] abortResponseCodes, String[] mustContainText, Map<String, String> headers) throws Throwable {
		
		_recursive = false;
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = null;
		_currentURI = uri;

		boolean dropResponse = false;
		if (mustContainText == null)  {
			dropResponse = true;
		}

		_httpTransport.executePostFiles(uri, urlBindVariables, fileUploads, headers, this, dropResponse);
		
		_requestsOutstanding.incrementAndGet();

	}

	/**
	 * doHttpPostJson will POST a Json object to a given Url. It takes
	 * name/value pairs as an array and turns those into a JSONobject which is
	 * set as the request body. JSONObjects with embedded objects must be
	 * handled by including the object to be embedded as one of the
	 * nameValuePairs.
	 */
	protected void doHttpPostJson(SimpleUri uri, Map<String, String> urlBindVariables, int[] validResponseCodes, int[] abortResponseCodes,
			Map<String, String> nameValuePairs, String[] mustContainText, DataListener[] listeners,
			Map<String, String> headers) throws Throwable {
		
		_recursive = false;
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = listeners;
		_currentURI = uri;

		boolean dropResponse = false;
		if ((mustContainText == null) && (listeners == null)) {
			dropResponse = true;
		}
		

		JSONObject jsonObject = new JSONObject();

		for (String key : nameValuePairs.keySet()) {
			String name = key;
			String value = nameValuePairs.get(key);

			jsonObject.put(name, value);

		}

		String jsonString = jsonObject.toString();
		logger.debug("Operation:doHttpPostJson: behavior UUID = " + _behavior.getBehaviorId()
				+ ", POST body = " + jsonString);

		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		// We will send and accept JSON
		if (!headers.containsKey("Accept")) {
			headers.put("Accept", "application/json");
		}
		if (!headers.containsKey("Content-Type")) {
			headers.put("Content-Type", "application/json");
		}

		_httpTransport.executePost(uri, urlBindVariables, jsonString, headers, this, dropResponse);
		
		_requestsOutstanding.incrementAndGet();

	}

	/**
	 * doHttpPostJson will POST a Json object to a given Url. It takes a string
	 * which represents a JSON object/array and places it in the request body.
	 */
	protected void doHttpPostJsonString(SimpleUri uri, Map<String, String> urlBindVariables, int[] validResponseCodes, int[] abortResponseCodes,
			String jsonString, String[] mustContainText, DataListener[] listeners, Map<String, String> headers)
			throws Throwable {
		
		_recursive = false;
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = listeners;
		_currentURI = uri;


		boolean dropResponse = false;
		if ((mustContainText == null) && (listeners == null)) {
			dropResponse = true;
		}

		logger.debug("Operation:doAsyncHttpPostJsonString: behavior UUID = " + _behavior.getBehaviorId()
				+ ", POST body = " + jsonString);

		// We will send and accept JSON
		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		if (!headers.containsKey("Accept")) {
			headers.put("Accept", "application/json");
		}
		if (!headers.containsKey("Content-Type")) {
			headers.put("Content-Type", "application/json");
		}

		_httpTransport.executePost(uri, urlBindVariables, jsonString, headers, this, dropResponse);
		
		_requestsOutstanding.incrementAndGet();

	}

	/**
	 * doHttpPutJson will Put a Json object to a given Url. It takes a string
	 * which represents a JSON object/array and places it in the request body.
	 */
	protected void doHttpPutJsonString(SimpleUri uri, Map<String, String> urlBindVariables, int[] validResponseCodes, int[] abortResponseCodes,
			String jsonString, String[] mustContainText, DataListener[] listeners, Map<String, String> headers)
			throws Throwable {
		
		_recursive = false;
		_validResponseCodes = validResponseCodes;
		_abortResponseCodes = abortResponseCodes;
		_mustContainText = mustContainText;
		_listeners = listeners;
		_currentURI = uri;


		boolean dropResponse = false;
		if ((mustContainText == null) && (listeners == null)) {
			dropResponse = true;
		}

		logger.debug("Operation:doAsyncHttpPutJsonString: behavior UUID = " + _behavior.getBehaviorId()
				+ ", Put body = " + jsonString);

		// We will send and accept JSON
		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		if (!headers.containsKey("Accept")) {
			headers.put("Accept", "application/json");
		}
		if (!headers.containsKey("Content-Type")) {
			headers.put("Content-Type", "application/json");
		}

		_httpTransport.executePut(uri, urlBindVariables, jsonString, headers, this, dropResponse);
		
		_requestsOutstanding.incrementAndGet();

	}

	public User getUser() {
		return _user;
	}

	public void setUser(User userState) {
		this._user = userState;
	}

	public int getNextOperationStep() {
		return _nextOperationStep;
	}

	public void incrementNextOperationStep() {
		this._nextOperationStep++;
	}

	public boolean isOperationComplete() {
		return _operationComplete;
	}

	public void setOperationComplete(boolean operationComplete) {
		this._operationComplete = operationComplete;
	}
	
	public void setGetRequestsOutstanding(int requests) {
		_getRequestsOutstanding.set(requests);
	}

	public int getGetRequestsOutstanding() {
		return _getRequestsOutstanding.get();
	}

	public Behavior getBehavior() {
		return _behavior;
	}


	public Target getTarget() {
		return target;
	}

	public void setTarget(Target target) {
		this.target = target;
	}

	@Override
	public UUID getBehaviorId() {
		return _behavior.getBehaviorId();
	}

	public boolean isIgnoreResult() {
		return _ignoreResult;
	}

	public void setIgnoreResult(boolean _ignoreResult) {
		this._ignoreResult = _ignoreResult;
	}

	public void setCycleTime(long cycleTime) {
		this._cycleTime = cycleTime;
	}

	public long getCycleTime() {
		return _cycleTime;
	}
	
	public int getOperationIndex() { return this._operationIndex; }
	public void setOperationIndex(int _operationIndex) {
		this._operationIndex = _operationIndex;
	}

	public String getOperationName() { return this._operationName; }


	protected SimpleUri getOperationUri(UrlType type, int index) {
		List<SimpleUri> theList = null;
		if (type.equals(UrlType.GET)) {
			theList = getGetUrls();
		} else if (type.equals(UrlType.POST)) {
			theList = getPostUrls();
		}

		return theList.get(index);
	}
	

	protected String getOperationUrl(UrlType type, int index, Map<String, String> bindVariables) {
		List<SimpleUri> theList = null;
		if (type.equals(UrlType.GET)) {
			theList = getGetUrls();
		} else if (type.equals(UrlType.POST)) {
			theList = getPostUrls();
		}

		if (theList != null) {
			SimpleUri url = theList.get(index);
			return url.getUriString(bindVariables);
		} else {
			return ""; 
		}
	}
	
	protected String getOperationUrl(UrlType type, int index) {
		return getOperationUrl(type, index, null);
	}

	protected Random getRandomNumberGenerator() {
		return _randomNumberGenerator;
	}

	public boolean isFailed() {return this._failed; }
	public void setFailed( boolean val ){ this._failed = val; }
	public Throwable getFailureReason(){ return this._failureReason; }
	public void setFailureReason( Throwable t ){ this._failureReason = t; }
	
	public String getFailureString() {
		return _failureString;
	}

	public void setFailureString(String failureString) {
		this._failureString = failureString;
	}

	public long getTotalSteps(){ return _totalSteps; }
	public void incrTotalSteps(){ _totalSteps++; }
	public void setTotalSteps( long val ){ this._totalSteps = val; }
	
	public long getTimeStarted() { return this._timeStarted; }
	public void setTimeStarted( long val ) { this._timeStarted = val; }
	public long getTimeFinished() { return this._timeFinished; }
	public void setTimeFinished( long val ) { this._timeFinished = val; }

	public HttpResponseStatus getCurrentResponseStatus() {
		return _currentResponseStatus;
	}

	/*
	 * Bind variables cannot contain spaces and need a bunch of special
	 * characters to be transformed
	 */
	protected String transformBindVar(String toTransform) {
		String temp = toTransform;
		temp = temp.replaceAll("@", "%40");
		temp = temp.replaceAll(">", "%3E");
		temp = temp.replaceAll("/", "%2F");
		temp = temp.replaceAll(":", "%3A");
		temp = temp.replaceAll(" ", "+");
		return temp;
	}

	/*** LIFECYCLE ***/

	public void cleanup() {
	}

	public void execute() throws Throwable {
		setFailed(false);
	}

	protected abstract void parseDataFromResponse(String response, DataListener[] listeners);

	protected abstract void parseDataFromHeaders(HttpHeaders headers, DataListener[] listeners);

	/**
	 * Simple tuple class for use by parseResourceLinksIntoUrls Note the
	 * recursive flag will cause the result of the GET to be parsed for more
	 * Urls.
	 */
	public class UrlToLoad {
		public UrlToLoad(URI uri, boolean recursive) {
			this.uri = uri;
			this.recursive = recursive;
		}

		public URI uri;
		public boolean recursive; /*
								 * parseResourceLinksIntoUrls can indicate that
								 * a particular URL should be re-parsed for more
								 * Urls
								 */
	}

	/**
	 * Takes a link such as href=\"/foo/bar" and turns it into a fully-qualified
	 * URL
	 * 
	 * @param toParse
	 *            - StringBuilder input
	 * @param linkStart
	 *            - The first character of the link after the quote
	 * @param quoteChar
	 *            - The quote character being used - either " or '
	 * @param escapeString
	 *            - If the quote is escaped with \" then this should be "\\",
	 *            otherwise empty
	 * @param isJs
	 *            - If the link is javascript then the forward slashes can be
	 *            escaped thus: \/
	 * @return the Url
	 */
	private String buildUrlFromTag(StringBuilder toParse, int linkStart, char quoteChar,
			String escapeString, boolean isJs) {
		int linkEnd = toParse.indexOf(escapeString + quoteChar, linkStart);
		if (toParse.charAt(linkStart) == '/')
			linkStart++;
		String url = null;
		if (linkEnd > linkStart) {
			url = toParse.substring(linkStart, linkEnd);
			if (isJs) {
				url = url.replaceAll("\\\\", "");
			}
			while (url.startsWith("../")) {
				url = url.substring(3, url.length());
			}
/*
 			if (!url.startsWith(getRootContext())) {
				if (url.startsWith(getContextPath())) {
					url = getRootContext() + url;
				} else if (url.startsWith("http://")) {
					return null; // Unknown URL not from the server under test -
									// don't load!
				} else {
					url = getBaseUrl() + url;
				}
			}
*/
		}
		return url;
	}

	/*
	 * When we strip URLs recursively from different formats, you can sometimes
	 * get funnies such as placeholders
	 */
	private boolean isValidUrl(String url) {
		if ((url.indexOf("{") >= 0) || (url.indexOf("}") >= 0)) {
			return false;
		}
		return true;
	}

	/**
	 * Takes a List and fills it with Urls parsed from a response from a
	 * previous HTTP GET.
	 * 
	 * @param urls
	 *            - The List of results
	 * @param toParse
	 *            - The data to parse to look for Urls
	 * @param searchPrefix
	 *            - The key to use for the parsing
	 * @param searchPostfix
	 *            - Optional extra key to only parse urls with the postfix
	 *            provided - must include closing quote as the start char -
	 *            should be null if not required
	 * @param recursive
	 *            - Should be set to true if the results of GETting these Urls
	 *            should also be parsed
	 * @param isJs
	 *            - Set to true if toParse is javascript, false otherwise
	 */
	protected void createUrlsFromTags(List<UrlToLoad> urls, StringBuilder toParse,
			String searchPrefix, String searchPostfix, boolean recursive, boolean isJs) {
		int linkIndex = 0;
		do {
			linkIndex = toParse.indexOf(searchPrefix);
			if (linkIndex > 0) {
				int linkStart = linkIndex + searchPrefix.length() + 1;
				char quoteChar = toParse.charAt(linkStart - 1);
				String escapeString = "";
				/* Some URLs use \" instead of " */
				if (quoteChar == '\\') {
					escapeString = "\\";
					linkStart++;
					quoteChar = toParse.charAt(linkStart - 1);
				}
				if (quoteChar == '\'' || quoteChar == '\"') {
					boolean postfixMatch = true;
					if (searchPostfix != null) {
						int closingQuoteIndex = toParse.indexOf("" + quoteChar, linkStart);
						if (closingQuoteIndex > 0) {
							postfixMatch = (toParse.indexOf(searchPostfix, closingQuoteIndex - 1) == (closingQuoteIndex - 1));
						}
					}
					if (postfixMatch) {
						String url = buildUrlFromTag(toParse, linkStart, quoteChar, escapeString,
								isJs);
						if (url != null && isValidUrl(url)) {
							URI uri;
							try {
								uri = new URI(url);
								urls.add(new UrlToLoad(uri, recursive));
							} catch (URISyntaxException e) {
								logger.warn("createUrlsFromTags: URISyntaxException on url " + url + ": " + e.getMessage());
							} 
						}
					}
				}
				toParse.delete(0, linkStart);
			}
		} while (linkIndex > 0);
	}

	/**
	 * This is a very useful function which can select options from an HTML
	 * <select> clause. It is essential for operations which need to pick an
	 * option from a drop-down in a form. The selectName should be the name of
	 * the select clause, isMultple should be true if multiple options can be
	 * selected and false otherwise. The noPickSelected value should be true if
	 * the default selection would cause an error.
	 */
	private String[] parseOptionValuesFromSelectClause(StringBuilder toParse, String selectName,
			boolean isMultiple, boolean noPickSelected) {
		String[] result = null;
		String searchString = "<select " + (isMultiple ? "multiple " : "") + "name=\"" + selectName
				+ "\"";
		int selectIndex = toParse.indexOf(searchString);
		if (selectIndex >= 0) {
			int selectEndIndex = toParse.indexOf("</select>", selectIndex + searchString.length());
			if (selectEndIndex > selectIndex) {
				int currentOptionStartIndex = selectIndex;
				List<String> optionValues = new ArrayList<String>();
				while (true) {
					searchString = "<option value=\"";
					currentOptionStartIndex = toParse.indexOf(searchString, currentOptionStartIndex
							+ searchString.length());
					int nextOptionStartIndex = toParse.indexOf(searchString,
							currentOptionStartIndex + searchString.length());
					if ((currentOptionStartIndex > selectIndex)
							&& (currentOptionStartIndex < selectEndIndex)) {
						int optionValueStartIndex = currentOptionStartIndex + searchString.length();
						int optionValueEndIndex = toParse.indexOf("\"", optionValueStartIndex);
						String value = toParse
								.substring(optionValueStartIndex, optionValueEndIndex);
						boolean selected = false;
						if (noPickSelected) {
							int selectedIndex = toParse.indexOf(" selected ", optionValueEndIndex);
							if ((selectedIndex > -1) && (selectedIndex < nextOptionStartIndex)) {
								selected = true;
							}
						}
						if (!noPickSelected || !selected) {
							if (!value.equals("-1")) { // Option can sometimes
														// be -1
														// for entries which
														// shouldn't
														// be selected
								optionValues.add(value);
							}
						}
					} else {
						break;
					}
				}
				result = optionValues.toArray(new String[] {});
			}
		}
		return result;
	}

	protected String pickRandomValueFromSelectClause(StringBuilder toParse, String selectName,
			boolean noPickSelected) {
		String[] allValues = parseOptionValuesFromSelectClause(toParse, selectName, false,
				noPickSelected);
		if (allValues == null) {
			return null;
		}
		return allValues[_randomNumberGenerator.nextInt(allValues.length)];
	}

	/* TODO: Pick more than one */
	protected String pickRandomValueFromMultipleSelectClause(StringBuilder toParse,
			String selectName, boolean noPickSelected) {
		String[] allValues = parseOptionValuesFromSelectClause(toParse, selectName, true,
				noPickSelected);
		if (allValues == null) {
			return null;
		}
		return allValues[_randomNumberGenerator.nextInt(allValues.length)];
	}

	/**
	 * Method which takes a response from an HTTP GET and harvests a bunch of
	 * Urls from it which should also be passed to HTTP GET. These Urls will
	 * only be loaded if they have not already been cached.
	 */
	protected void parseResourceLinksIntoUrls(String sourceUrl, List<UrlToLoad> urls,
			StringBuilder toParse) {
		if (sourceUrl.endsWith(".css")) {
			createUrlsFromTags(urls, new StringBuilder(toParse), "url(", null, false, false);
		} else {
			// load all src= tags (js and images)
			createUrlsFromTags(urls, new StringBuilder(toParse), "src=", null, false, false);
			// load all CSS files and look recursively in them for more links
			createUrlsFromTags(urls, new StringBuilder(toParse), "<link href=\"",
					"\" media=\"screen\" rel=\"stylesheet\" type=\"text/css", true, false);
		}
	}

	/**
	 * Method which takes a response from an HTTP GET and harvests a bunch of
	 * Urls from it which should also be passed to HTTP GET. These Urls will
	 * only be loaded if they have not already been cached.
	 */
	protected void parseResourceLinksIntoUrls(SimpleUri sourceUrl, List<UrlToLoad> urls, String toParse) {
		if (sourceUrl.getQueryString().endsWith(".css")) {
			createUrlsFromTags(urls, new StringBuilder(toParse), "url(", null, false, false);
		} else {
			// load all src= tags (js and images)
			createUrlsFromTags(urls, new StringBuilder(toParse), "src=", null, false, false);
			// load all CSS files and look recursively in them for more links
			createUrlsFromTags(urls, new StringBuilder(toParse), "<link href=\"",
					"\" media=\"screen\" rel=\"stylesheet\" type=\"text/css", true, false);
		}
	}

	/**
	 * Generates a random string, useful for comments, names or any string data
	 * which needs to be posted MaxLength is the maximum length of the string (a
	 * random length value will be picked between maxLength/2 and maxLength)
	 * AvgWordLength is the average length of each word, if the random string is
	 * to look like a sentence. -1 will produce no spaces Note that if
	 * allCapsFixedLength is set to true, maxLength is the actual word length
	 */
	protected String getRandomString(int maxLength, boolean allCapsFixedLength, int avgWordLength) {
		StringBuilder toBuild = new StringBuilder();
		int length = 0;
		if (allCapsFixedLength || (maxLength < 5)) {
			length = maxLength;
		} else {
			length = (_randomNumberGenerator.nextInt(maxLength / 2) + (maxLength / 2));
		}
		for (int i = 0; i < length; i++) {
			char current = 0;
			if ((avgWordLength > 0)
					&& (_randomNumberGenerator.nextInt(avgWordLength * 2) == avgWordLength)) {
				current = ' ';
			} else if (allCapsFixedLength) {
				current = (char) (_randomNumberGenerator.nextInt(26) + 'A');
			} else {
				current = (char) (_randomNumberGenerator.nextInt(26) + (_randomNumberGenerator
						.nextBoolean() ? 'a' : 'A'));
			}
			toBuild.append(new Character(current));
		}
		return toBuild.toString();
	}

	/*
	 * @Override public String toString() { return this.getOperationName(); }
	 */

	public List<SimpleUri> getGetUrls() {
		return _getUrls;
	}

	public void setGetUrls(List<SimpleUri> getUrls) {
		this._getUrls = getUrls;
	}

	public void addGetUrl(SimpleUri getUrl) {
		this._getUrls.add(getUrl);
	}

	public List<SimpleUri> getPostUrls() {
		return _postUrls;
	}

	public void setPostUrls(List<SimpleUri> postUrls) {
		this._postUrls = postUrls;
	}

	public void addPostUrl(SimpleUri postUrl) {
		this._postUrls.add(postUrl);
	}

	public void setOperationName(String _operationName) {
		this._operationName = _operationName;
	}

	public HttpTransport getHttpTransport() {
		return _httpTransport;
	}

	public void setHttpTransport(HttpTransport _httpTransport) {
		this._httpTransport = _httpTransport;
	}

	public int getRequestsOutstanding() {
		return _requestsOutstanding.get();
	}

	
}

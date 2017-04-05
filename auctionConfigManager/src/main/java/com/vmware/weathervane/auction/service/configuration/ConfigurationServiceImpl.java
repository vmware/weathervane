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
package com.vmware.weathervane.auction.service.configuration;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import java.util.concurrent.locks.Lock;

import javax.transaction.Transactional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.model.configuration.AppInstance;
import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.configuration.LbServer;
import com.vmware.weathervane.auction.model.configuration.WebServer;
import com.vmware.weathervane.auction.repository.AppInstanceRepository;
import com.vmware.weathervane.auction.repository.AppServerRepository;
import com.vmware.weathervane.auction.repository.CoordinationServerRepository;
import com.vmware.weathervane.auction.repository.DbServerRepository;
import com.vmware.weathervane.auction.repository.LbServerRepository;
import com.vmware.weathervane.auction.repository.MsgServerRepository;
import com.vmware.weathervane.auction.repository.NosqlServerRepository;
import com.vmware.weathervane.auction.repository.WebServerRepository;
import com.vmware.weathervane.auction.representation.configuration.ChangeConfigurationRequest;
import com.vmware.weathervane.auction.representation.configuration.ChangeConfigurationResponse;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@Service
public class ConfigurationServiceImpl implements ConfigurationService {
	private static final Logger logger = LoggerFactory.getLogger(ConfigurationServiceImpl.class);

	@Autowired
	private DefaultsService defaultsService;

	@Autowired
	private AppInstanceRepository appInstanceRepository;

	@Autowired
	private AppServerRepository appServerRepository;

	@Autowired
	private AppServerService appServerService;

	@Autowired
	private DbServerRepository dbServerRepository;

	@Autowired
	private NosqlServerRepository nosqlServerRepository;

	@Autowired
	private MsgServerRepository msgServerRepository;

	@Autowired
	private WebServerRepository webServerRepository;

	@Autowired
	private LbServerRepository lbServerRepository;

	@Autowired
	private CoordinationServerRepository coordinationServerRepository;

	private ExecutorService executor = Executors.newCachedThreadPool();

	@Override
	@Transactional
	public ChangeConfigurationResponse changeConfiguration(ChangeConfigurationRequest mergedRequest)
			throws ServiceNotFoundException, InterruptedException, IOException, DuplicateServiceException, AddFailedException, IllegalConfigurationException {

		logger.debug("changeConfiguration: " + mergedRequest);
		ChangeConfigurationResponse response = new ChangeConfigurationResponse();
		
		/*
		 * Get the lists from the request.  Make sure they are not null to avoid repeated
		 * checks for null
		 */
		List<AppServer> appServersToAdd = (mergedRequest.getAppServersToAdd() != null) ? 
				mergedRequest.getAppServersToAdd()  : new ArrayList<AppServer>();
		List<WebServer> webServersToAdd = (mergedRequest.getWebServersToAdd() != null) ? 
						mergedRequest.getWebServersToAdd()  : new ArrayList<WebServer>();
		Long numAppServersToRemove = (mergedRequest.getNumAppServersToRemove() != null) ? 
				mergedRequest.getNumAppServersToRemove()  : 0L;
		Long numWebServersToRemove = (mergedRequest.getNumWebServersToRemove() != null) ? 
				mergedRequest.getNumWebServersToRemove()  : 0L;

		/*
		 * Get the global lock on configuration changes
		 */
		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		try {
			/*
			 * First check the configuration to make sure that this request is
			 * valid
			 */
			long numAppServersToAdd = appServersToAdd.size();
			long numWebServersToAdd = webServersToAdd.size();

			long numCurrentAppServers = appServerRepository.count();
			long numCurrentWebServers = webServerRepository.count();
			long numCurrentLbServers = lbServerRepository.count();

			if (numAppServersToRemove >= numCurrentAppServers) {
				logger.warn("Attempt to remove all running app servers.  numAppServersToRemove = " + numAppServersToRemove +
							", numCurrentAppServers = " + numCurrentAppServers 
							+ ", received request: " + mergedRequest);
				throw new IllegalConfigurationException("Can't remove all running app servers.");
			}
			if (numWebServersToRemove >= numCurrentWebServers) {
				logger.warn("Attempt to remove all running web servers: " + mergedRequest);
				throw new IllegalConfigurationException("Can't remove all running web servers.");
			}
			if ((numAppServersToAdd > 0) && (numCurrentWebServers <= 0) && (numCurrentLbServers <= 0)) {
				logger.warn("Must be at least one web server or load-balancer to add an app server: " + mergedRequest);
				throw new IllegalConfigurationException("Must be at least one web server or load-balancer to add an app server.");
			}
			if ((numWebServersToAdd > 0) && (numCurrentLbServers <= 0)) {
				logger.warn("Must be at least one load-balancer to add a web server: " + mergedRequest);
				throw new IllegalConfigurationException("Must be at least one load-balancer to add a web server.");
			}

			List<Long> addedAppServerIds = new ArrayList<Long>();;
			List<Long> addedWebServerIds = new ArrayList<Long>();;

			/*
			 * Add all of the new appServers to the repository
			 */
			List<AppServer> updatedAppServersToAdd = new ArrayList<AppServer>();
			for (AppServer appServer : appServersToAdd) {
				appServer = appServerRepository.save(appServer);
				logger.debug("Added app server on host " + appServer.getHostHostName() + " to repository. Got id " + appServer.getId());
				addedAppServerIds.add(appServer.getId());
				updatedAppServersToAdd.add(appServer);
			}
			appServersToAdd = updatedAppServersToAdd;

			/*
			 * Add all of the new webServers to the repository. Also update the
			 * list of webServersToAdd so that we have a list with the correct
			 * IDs (which are added during the save).
			 */
			List<WebServer> updatedWebServersToAdd = new ArrayList<WebServer>();
			for (WebServer webServer : webServersToAdd) {
				webServer = webServerRepository.save(webServer);
				logger.debug("Added web server on host " + webServer.getHostHostName() + " to repository. Got id " + webServer.getId());
				webServer.initializeRuntimeInfo();
				addedWebServerIds.add(webServer.getId());
				updatedWebServersToAdd.add(webServer);
			}
			webServersToAdd = updatedWebServersToAdd;

			/*
			 * Get the list of all services involved in reconfiguration from the
			 * repositories and then adjust the lists to remove servers that are
			 * being removed.
			 */
			AppInstance appInstance = appInstanceRepository.findOne(1L);
			if (appInstance == null) {
				throw new ServiceNotFoundException("Could not find appInstance with id 1");
			}

			List<WebServer> webServers = webServerRepository.findAll();
			List<LbServer> lbServers = lbServerRepository.findAll();
			List<AppServer> appServers = appServerRepository.findAll();
			List<AppServer> appServersToRemove = new ArrayList<AppServer>();
			List<WebServer> webServersToRemove = new ArrayList<WebServer>();

			/*
			 * Need to choose which app and web servers to remove
			 */
			long numRemovesRemaining = numAppServersToRemove;
			int index = 0;
			while (numRemovesRemaining > 0) {
				AppServer appServer = appServers.get(index);
				if (appServer.isMaster()) {
					logger.debug("App server on " + appServer.getHostHostName() + " is master.  Not removing.");
					index++;
					continue;
				}
				
				logger.debug("Found app server to remove with id  " + appServer.getId() 
					+ ", it is on host " + appServer.getHostHostName());
				appServersToRemove.add(appServer);
				index++;
				numRemovesRemaining--;
			}
			for (AppServer appServer: appServersToRemove) {
				appServers.remove(appServer);				
			}
			
			index = 0;
			numRemovesRemaining = numWebServersToRemove;
			while (numRemovesRemaining > 0) {
				WebServer webServer = webServers.get(index);
				logger.debug("Found web server to remove with id  " + webServer.getId()
					+ ", it is on host " + webServer.getHostHostName());
				webServersToRemove.add(webServer);
				numRemovesRemaining--;
				index++;
			}
			for (WebServer webServer : webServersToRemove) {
				webServers.remove(webServer);				
			}

			/*
			 * Now start and warm all of the new app servers
			 */
			List<Future<Boolean>> actionReturns = new ArrayList<Future<Boolean>>();
			for (AppServer appServer : appServersToAdd) {
				logger.debug("Configuring appServer on " + appServer.getHostHostName());
				appServer.configure(defaultsService.getAppServerDefaults(), appInstance, appServers, webServers, dbServerRepository.findAll(),
						nosqlServerRepository.findAll(), msgServerRepository.findAll(), coordinationServerRepository.findAll());

				actionReturns.add(executor.submit(new AppServerStarter(appServer)));
			}

			Boolean actionSucceeded = true;
			for (Future<Boolean> actionSucceededFuture : actionReturns) {
				try {
					Boolean retVal = actionSucceededFuture.get();
					actionSucceeded &= retVal;
				} catch (ExecutionException e) {
					Throwable e1 = e.getCause();
					if (e1 != null) {
						logger.warn("Getting start app server future returned an exception.  original: " + e.getCause().getMessage());
					} else {
						logger.warn("Getting start app server future returned an exception: " + e.getMessage());						
					}
					actionSucceeded = false;
				}
			}
			if (!actionSucceeded) {
				/*
				 * If any of the adds failed, then need to stop all of the
				 * appServers and throw an exception
				 */
				for (AppServer appServer : appServersToAdd) {
					appServerRepository.delete(appServer);
					appServer.stop();
				}
				throw new AddFailedException("Could not start all appServers");
			}
			
			List<Long> appServerToWarmIds = new ArrayList<Long>();;
			for (AppServer appServer : appServersToAdd) {
				if (appServer.getPrewarmAppServers()) {
					appServerToWarmIds.add(appServer.getId());
				}
			}
			if ((appServerToWarmIds != null) && (appServerToWarmIds.size() > 0)) {
				appServerService.warmAppServers(appServerToWarmIds);
			}
			
			/*
			 * App Servers are up and warm. Configure all of the web servers that will be up.
			 */
			boolean configureExistingWeb = false;
			if ((numCurrentWebServers > 0) && ((numAppServersToAdd > 0) || (numAppServersToRemove > 0))) {
				configureExistingWeb = true;
			}

			for (WebServer webServer : webServersToAdd) {
				logger.debug("Configuring webServer on " + webServer.getHostHostName());
				webServer.configure(defaultsService.getWebServerDefaults(), appInstance, webServerRepository.count(), appServers);				
			}
			if (configureExistingWeb) {
				for (WebServer webServer : webServers) {
					if (webServersToAdd.contains(webServer)) {
						continue;
					}
					logger.debug("Configuring webServer on " + webServer.getHostHostName());
					webServer.configure(defaultsService.getWebServerDefaults(), appInstance, webServerRepository.count(), appServers);
				}
			}

			/*
			 * Start all of the added web servers
			 */
			actionReturns.clear();
			for (WebServer webServer : webServersToAdd) {
				logger.debug("Starting webServer on " + webServer.getHostHostName());
				actionReturns.add(executor.submit(new WebServerStarter(webServer)));
			}
			actionSucceeded = true;
			for (Future<Boolean> actionSucceededFuture : actionReturns) {
				try {
					Boolean retVal = actionSucceededFuture.get();
					actionSucceeded &= retVal;
				} catch (ExecutionException e) {
					Throwable e1 = e.getCause();
					if (e1 != null) {
						logger.warn("Getting start web server future returned an exception.  original: " + e.getCause().getMessage());
					} else {
						logger.warn("Getting start web server future returned an exception: " + e.getMessage());						
					}
					actionSucceeded = false;
				}
			}
			if (!actionSucceeded) {
				logger.warn("Could not start all web servers to be added: " + mergedRequest);
				/*
				 * If any of the adds failed, then need to stop all of the
				 * appServers and webServers and throw an exception
				 */
				for (AppServer appServer : appServersToAdd) {
					appServerRepository.delete(appServer);
					appServer.stop();
				}
				for (WebServer webServer : webServersToAdd) {
					webServerRepository.delete(webServer);
					webServer.stop();
				}
				throw new AddFailedException("Could not start all webServers");
			}

			if (configureExistingWeb) {
				/*
				 * Reload all of the active web servers, but not the ones that
				 * were just added since they have the correct configuration
				 */
				actionReturns.clear();
				for (WebServer webServer : webServers) {
					if (webServersToAdd.contains(webServer)) {
						continue;
					}
					logger.debug("Reloading webServer on " + webServer.getHostHostName());
					actionReturns.add(executor.submit(new WebServerReloader(webServer)));
				}
				actionSucceeded = true;
				for (Future<Boolean> actionSuceededFuture : actionReturns) {
					try {
						Boolean retVal = actionSuceededFuture.get();
						actionSucceeded &= retVal;
					} catch (ExecutionException e) {
						Throwable e1 = e.getCause();
						if (e1 != null) {
							logger.warn("Getting reload web server future returned an exception.  original: " + e.getCause().getMessage());
						} else {
							logger.warn("Getting reload web server future returned an exception: " + e.getMessage());						
						}
						actionSucceeded = false;
					}
				}
				if (!actionSucceeded) {
					logger.warn("Could not reload all current web servers: " + mergedRequest);
					/*
					 * If any of the reloads failed, then need to stop all of
					 * the appServers and webServers and throw an exception
					 */
					for (AppServer appServer : appServersToAdd) {
						appServerRepository.delete(appServer);
						appServer.stop();
					}
					for (WebServer webServer : webServersToAdd) {
						webServerRepository.delete(webServer);
						webServer.stop();
					}
					throw new AddFailedException("Could not reload all current webServers");
				}
			}

			/*
			 * If we are removing any app servers we need to wait until the reload
			 * is complete on the web servers so that we are sure that the app servers
			 * are no longer handing any requests.
			 */
			if (numAppServersToRemove > 0) {
				/*
				 * Tell of the the app servers being removed to prepare for a shutdown.
				 */
				for (AppServer appServer: appServersToRemove) {
					logger.debug("Telling app server with id  " + appServer.getId() 
					+ " to prepareToShutdown ");
					appServer.prepareToShutdown();				
				}
				
				actionReturns.clear();
				for (WebServer webServer : webServers) {
					if (webServersToAdd.contains(webServer)) {
						continue;
					}
					logger.debug("Waiting for reload complete for webServer on " + webServer.getHostHostName());
					actionReturns.add(executor.submit(new WebServerReloadWaiter(webServer)));
				}
				actionSucceeded = true;
				for (Future<Boolean> actionSuceededFuture : actionReturns) {
					try {
						Boolean retVal = actionSuceededFuture.get();
						actionSucceeded &= retVal;
					} catch (ExecutionException e) {
						Throwable e1 = e.getCause();
						if (e1 != null) {
							logger.warn("Getting wait for reload web server future returned an exception.  original: " + e.getCause().getMessage());
						} else {
							logger.warn("Getting wait for reload web server future returned an exception: " + e.getMessage());						
						}
						actionSucceeded = false;
					}
				}
				if (!actionSucceeded) {
					/*
					 * If any of the reloads failed, then need to stop all of
					 * the appServers and webServers and throw an exception
					 */
					for (AppServer appServer : appServersToAdd) {
						appServerRepository.delete(appServer);
						appServer.stop();
					}
					for (WebServer webServer : webServersToAdd) {
						webServerRepository.delete(webServer);
						webServer.stop();
					}
					throw new AddFailedException("Error waiting for web server reload to complete");
				}
			}
						

			/*
			 * Reconfigure and reload the load balancers if the tier below the load balancers has changed
			 */
			if (((numCurrentWebServers > 0) && ((numWebServersToAdd > 0) || (numWebServersToRemove > 0)))
					|| ((numCurrentWebServers == 0) && ((numAppServersToAdd > 0) || (numAppServersToRemove > 0)))) {

				actionReturns.clear();
				for (LbServer lbServer : lbServers) {
					logger.debug("Configuring lbServer on " + lbServer.getHostHostName());
					lbServer.configure(defaultsService.getLbServerDefaults(), lbServers.size(), appServers, webServers);
					logger.debug("Reloading lbServer on " + lbServer.getHostHostName());
					actionReturns.add(executor.submit(new LbServerReloader(lbServer)));
				}
				actionSucceeded = true;
				for (Future<Boolean> actionSuceededFuture : actionReturns) {
					try {
						Boolean retVal = actionSuceededFuture.get();
						actionSucceeded &= retVal;
					} catch (ExecutionException e) {
						Throwable e1 = e.getCause();
						if (e1 != null) {
							logger.warn("Getting reload lb server future returned an exception.  original: " + e.getCause().getMessage());
						} else {
							logger.warn("Getting reload lb server future returned an exception: " + e.getMessage());						
						}
						actionSucceeded = false;
					}
				}
				if (!actionSucceeded) {
					logger.warn("Could not reload all current load balancers: " + mergedRequest);
					/*
					 * If any of the reloads failed, then need to stop all of
					 * the appServers and webServers and throw an exception
					 */
					for (AppServer appServer : appServersToAdd) {
						appServerRepository.delete(appServer);
						appServer.stop();
					}
					for (WebServer webServer : webServersToAdd) {
						webServerRepository.delete(webServer);
						webServer.stop();
					}
					throw new AddFailedException("Could not reload all LbServers");
				}
				
				/*
				 * If we are removing any web servers we need to wait until the reload
				 * is complete on the lb servers so that we are sure that the web servers
				 * are no longer handing any requests.
				 */
				if (numWebServersToRemove > 0) {
					/*
					 * To get the web servers to drop their connections, reload
					 */
					for (WebServer webServer : webServersToRemove) {
						webServer.reload();
					}
					for (WebServer webServer : webServers) {
						if (webServersToAdd.contains(webServer)) {
							continue;
						}
						webServer.reload();
					}
					
					/*
					 * Tell of the the app servers to release any outstanding async requests
					 * so that the web servers can give up the connections.
					 */
					for (AppServer appServer: appServers) {
						logger.debug("Telling app server with id  " + appServer.getId() 
						+ " to release connections ");
						appServer.releaseAsyncRequests();				
					}
					
					actionReturns.clear();
					for (LbServer lbServer : lbServers) {
						logger.debug("Waiting for reload complete for lbServer on " + lbServer.getHostHostName());
						actionReturns.add(executor.submit(new LbServerReloadWaiter(lbServer)));
					}
					actionSucceeded = true;
					for (Future<Boolean> actionSuceededFuture : actionReturns) {
						try {
							Boolean retVal = actionSuceededFuture.get();
							actionSucceeded &= retVal;
						} catch (ExecutionException e) {
							Throwable e1 = e.getCause();
							if (e1 != null) {
								logger.warn("Getting wait for reload lb server future returned an exception.  original: " + e.getCause().getMessage());
							} else {
								logger.warn("Getting wait for reload lb server future returned an exception: " + e.getMessage());						
							}
							actionSucceeded = false;
						}
					}
					if (!actionSucceeded) {
						/*
						 * If any of the reloads failed, then need to throw an exception
						 */
						throw new AddFailedException("Error waiting for web server reload to complete");
					}
				}							

			}
			
			/*
			 * Stop all of the web servers and app servers to be removed and
			 * delete them from the repository
			 */
			List<Future<Boolean>>  futureReturnList = new ArrayList<Future<Boolean>>();
			for (AppServer appServer : appServersToRemove) {
				logger.debug("Stopping appServer " + appServer.getId() + " on host " + appServer.getHostHostName());
				futureReturnList.add(executor.submit(new Callable<Boolean>() {

					@Override
					public Boolean call() throws Exception {
						appServer.stop();
						return true;
					}
				}));
			}
			for (WebServer webServer : webServersToRemove) {
				logger.debug("Stopping webServer " + webServer.getId() + " on host " + webServer.getHostHostName());
				futureReturnList.add(executor.submit(new Callable<Boolean>() {

					@Override
					public Boolean call() throws Exception {
						webServer.stop();
						return true;
					}
				}));
			}
			for (Future<Boolean> future: futureReturnList) {
				try {
					future.get();
				} catch (ExecutionException e) {
					logger.warn("Exception during stop execution: " + e.getMessage() );
				}
			}
			for (AppServer appServer : appServersToRemove) {
				appServerRepository.delete(appServer.getId());
			}
			for (WebServer webServer : webServersToRemove) {
				List<Integer> workerPids = webServer.getWorkerPids();
				if (workerPids != null) {
					logger.debug("Deleting webServer " + webServer.getId() + " with " + workerPids.size() + " workerPids");
				}
				webServerRepository.delete(webServer.getId());
			}
			
			response.setAppServersRemoved(appServersToRemove);
			response.setWebServersRemoved(webServersToRemove);
			response.setAddedAppServerIds(addedAppServerIds);
			response.setAddedWebServerIds(addedWebServerIds);
			return response;

		} finally {
			configurationChangeLock.unlock();
		}
	}

	private class AppServerStarter implements Callable<Boolean> {
		private AppServer appServer;

		protected AppServerStarter(AppServer appServer) {
			this.appServer = appServer;
		}

		@Override
		public Boolean call() {
			logger.debug("AppServerStarter.  Starting appServer " + appServer.getId());
			try {
				return appServer.startWithoutWarmup(defaultsService.getAppServerDefaults());
			} catch (InterruptedException e) {
				return false;
			} catch (IOException e) {
				return false;
			}
		}

	}

	private class WebServerStarter implements Callable<Boolean> {
		private WebServer webServer;

		protected WebServerStarter(WebServer webServer) {
			this.webServer = webServer;
		}

		@Override
		public Boolean call() {
			logger.debug("WebServerStarter.  Starting lbServer " + webServer.getId());
			try {
				return webServer.start(defaultsService.getWebServerDefaults());
			} catch (InterruptedException e) {
				return false;
			}
		}

	}

	private class WebServerReloader implements Callable<Boolean> {
		private WebServer webServer;

		protected WebServerReloader(WebServer webServer) {
			this.webServer = webServer;
		}

		@Override
		public Boolean call() {
			logger.debug("WebServerReloader.  Reloading lbServer " + webServer.getId());
			try {
				return webServer.reload();
			} catch (InterruptedException e) {
				return false;
			} catch (IOException e) {
				return false;
			}
		}

	}

	private class WebServerReloadWaiter implements Callable<Boolean> {
		private WebServer webServer;

		protected WebServerReloadWaiter(WebServer webServer) {
			this.webServer = webServer;
		}

		@Override
		public Boolean call() {
			logger.debug("WebServerReloadWaiter.  Reloading lbServer " + webServer.getId());
			try {
				return webServer.waitForReloadComplete();
			} catch (InterruptedException e) {
				return false;
			} catch (IOException e) {
				return false;
			}
		}

	}

	private class LbServerReloader implements Callable<Boolean> {
		private LbServer lbServer;

		protected LbServerReloader(LbServer lbServer) {
			this.lbServer = lbServer;
		}

		@Override
		public Boolean call() {
			logger.debug("LbServerReloader.  Reloading lbServer " + lbServer.getId());
			try {
				return lbServer.reload();
			} catch (InterruptedException e) {
				return false;
			} catch (IOException e) {
				return false;
			}
		}

	}
	
	private class LbServerReloadWaiter implements Callable<Boolean> {
		private LbServer _lbServer;

		protected LbServerReloadWaiter(LbServer lbServer) {
			this._lbServer = lbServer;
		}

		@Override
		public Boolean call() {
			logger.debug("LbServerReloadWaiter.  Reloading lbServer " + _lbServer.getId());
			try {
				return _lbServer.waitForReloadComplete();
			} catch (InterruptedException e) {
				return false;
			} 
		}

	}

}

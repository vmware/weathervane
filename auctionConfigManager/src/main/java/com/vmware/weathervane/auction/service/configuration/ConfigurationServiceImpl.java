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

			long numCurrentWebServers = webServerRepository.count();

			boolean validConfig = validateConfigurationRequest(numAppServersToRemove, numWebServersToRemove, 
					numAppServersToAdd, numWebServersToAdd);
			if (!validConfig) {
				throw new IllegalConfigurationException();
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

			/*
			 * Need to choose which app and web servers to remove
			 */
			List<AppServer> appServersToRemove = chooseAppServersToRemove(numAppServersToRemove, appServers);
			for (AppServer appServer: appServersToRemove) {
				appServers.remove(appServer);				
			}
			
			List<WebServer> webServersToRemove = chooseWebServersToRemove(numWebServersToRemove, webServers);
			for (WebServer webServer : webServersToRemove) {
				webServers.remove(webServer);				
			}

			/*
			 * Now configure, start, and warm all of the new app servers
			 */
			configureAndStartAppServers(appServersToAdd, appInstance, appServers, webServers);
			warmAppServers(appServersToAdd);
			
			/*
			 * App Servers are up and warm. Configure all of the web servers that will be up.
			 */
			boolean configureExistingWeb = false;
			if ((numCurrentWebServers > 0) && ((numAppServersToAdd > 0) || (numAppServersToRemove > 0))) {
				configureExistingWeb = true;
			}
			configureWebServers(webServersToAdd, webServers, configureExistingWeb, appServers, appInstance);

			/*
			 * Start all of the added web servers
			 */
			startWebServers(webServersToAdd, appServersToAdd);

			/*
			 * Reconfigure and reload the load balancers if the tier below the load balancers is changing
			 */
			if (((numCurrentWebServers > 0) && ((numWebServersToAdd > 0) || (numWebServersToRemove > 0)))
					|| ((numCurrentWebServers == 0) && ((numAppServersToAdd > 0) || (numAppServersToRemove > 0)))) {

				configureAndReloadLbServers(lbServers, webServers, appServers, webServersToAdd, appServersToAdd);
			}
			
			/*
			 * Reload all of the web servers, but not the ones that were just added,
			 * so that they get any updated config and drop connections so that the 
			 * load-balancer can finish its reload.
			 * Since we currently only change the number of web and app servers this
			 * will always happen
			 */
			if ((numWebServersToAdd + numWebServersToRemove + numAppServersToAdd + numAppServersToRemove) > 0) {
				reloadWebServers(webServersToRemove, null);
				reloadWebServers(webServers, webServersToAdd);
			}
			
			/*
			 * Tell all of the the app servers being removed to prepare for a shutdown.
			 */
			for (AppServer appServer: appServersToRemove) {
				logger.debug("Telling app server with id  " + appServer.getId() 
				+ " to prepareToShutdown ");
				appServer.prepareToShutdown();				
			}
			
			/*
			 * Tell of the the app servers to release any outstanding async
			 * requests so that the web servers can give up the connections.
			 */
			if ((numWebServersToAdd + numWebServersToRemove + numAppServersToAdd + numAppServersToRemove) > 0) {
				for (AppServer appServer : appServers) {
					if (appServersToRemove.contains(appServer)) {
						continue;
					}
					logger.debug("Telling app server with id  " + appServer.getId() + " to release connections ");
					appServer.releaseAsyncRequests();
				}
			}

			/*
			 * If we are removing any app servers we need to wait until the reload
			 * is complete on the web servers so that we are sure that the app servers
			 * are no longer handling any requests.
			 */
			if (numAppServersToRemove > 0) {
				waitForWebServerReload(webServers, webServersToAdd, appServersToAdd);
			}
						
			/*
			 * If we are removing any web servers we need to wait until the
			 * reload is complete on the lb servers so that we are sure that the
			 * web servers are no longer handing any requests.
			 */
			if (numWebServersToRemove > 0) {
				waitForLbServerReload(lbServers);
			}
			
			/*
			 * Stop all of the web servers and app servers to be removed and
			 * delete them from the repository
			 */
			stopWebAndAppServers(webServersToRemove, appServersToRemove);

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
	
	private boolean validateConfigurationRequest(long numAppServersToRemove, long numWebServersToRemove, 
			long numAppServersToAdd, long numWebServersToAdd) throws IllegalConfigurationException {
		long numCurrentAppServers = appServerRepository.count();
		long numCurrentWebServers = webServerRepository.count();
		long numCurrentLbServers = lbServerRepository.count();
		
		if (numAppServersToRemove >= numCurrentAppServers) {
			logger.warn("Attempt to remove all running app servers.  numAppServersToRemove = " + numAppServersToRemove +
						", numCurrentAppServers = " + numCurrentAppServers);
			throw new IllegalConfigurationException("Can't remove all running app servers.");
		}
		if (numWebServersToRemove >= numCurrentWebServers) {
			logger.warn("Attempt to remove all running web servers ");
			throw new IllegalConfigurationException("Can't remove all running web servers.");
		}
		if ((numAppServersToAdd > 0) && (numCurrentWebServers <= 0) && (numCurrentLbServers <= 0)) {
			logger.warn("Must be at least one web server or load-balancer to add an app server");
			throw new IllegalConfigurationException("Must be at least one web server or load-balancer to add an app server.");
		}
		if ((numWebServersToAdd > 0) && (numCurrentLbServers <= 0)) {
			logger.warn("Must be at least one load-balancer to add a web server");
			throw new IllegalConfigurationException("Must be at least one load-balancer to add a web server.");
		}
		
		return true;
	}

	private List<AppServer> chooseAppServersToRemove(long numAppServersToRemove, List<AppServer> appServers) {
		List<AppServer> appServersToRemove = new ArrayList<AppServer>();
		int index = 0;
		while (numAppServersToRemove > 0) {
			AppServer appServer = appServers.get(index);
			if (appServer.isMaster()) {
				logger.debug("chooseAppServersToRemove: App server on " + appServer.getHostHostName() + " is master.  Not removing.");
				index++;
				continue;
			}
			
			logger.debug("chooseAppServersToRemove: Found app server to remove with id  " + appServer.getId() 
				+ ", it is on host " + appServer.getHostHostName());
			appServersToRemove.add(appServer);
			index++;
			numAppServersToRemove--;
		}
		return appServersToRemove;
	}
	
	private List<WebServer> chooseWebServersToRemove(long numWebServersToRemove, List<WebServer> webServers) {
		List<WebServer> webServersToRemove = new ArrayList<WebServer>();
		int index = 0;
		while (numWebServersToRemove > 0) {
			WebServer webServer = webServers.get(index);
			logger.debug("Found web server to remove with id  " + webServer.getId()
				+ ", it is on host " + webServer.getHostHostName());
			webServersToRemove.add(webServer);
			numWebServersToRemove--;
			index++;
		}
		
		return webServersToRemove;

	}
	
	private void configureAndStartAppServers(List<AppServer> appServersToAdd, AppInstance appInstance, List<AppServer> appServers, List<WebServer> webServers) throws ServiceNotFoundException, IOException, InterruptedException {
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
			try {
				throw new AddFailedException("Could not start all appServers");
			} catch (AddFailedException e) {
				// TODO Auto-generated catch block
				e.printStackTrace();
			}
		}

	}
	
	private void warmAppServers(List<AppServer> appServersToAdd) throws ServiceNotFoundException {
		List<Long> appServerToWarmIds = new ArrayList<Long>();;
		for (AppServer appServer : appServersToAdd) {
			if (appServer.getPrewarmAppServers()) {
				appServerToWarmIds.add(appServer.getId());
			}
		}
		if ((appServerToWarmIds != null) && (appServerToWarmIds.size() > 0)) {
			appServerService.warmAppServers(appServerToWarmIds);
		}
	}
	
	private void configureWebServers(List<WebServer> webServersToAdd, List<WebServer> webServers, boolean configureExistingWeb,
			List<AppServer> appServers, AppInstance appInstance) throws IOException, InterruptedException {
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

	}
	
	private void startWebServers(List<WebServer> webServersToAdd, List<AppServer> appServersToAdd) throws InterruptedException, IOException, AddFailedException {
		List<Future<Boolean>> actionReturns = new ArrayList<Future<Boolean>>();
		for (WebServer webServer : webServersToAdd) {
			logger.debug("Starting webServer on " + webServer.getHostHostName());
			actionReturns.add(executor.submit(new WebServerStarter(webServer)));
		}
		Boolean actionSucceeded = true;
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
			logger.warn("Could not start all web servers to be added ");
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

	}
	
	private void reloadWebServers(List<WebServer> webServersToReload, List<WebServer> webServersToIgnore) throws InterruptedException, IOException, AddFailedException {
		
		if ((webServersToReload == null) || webServersToReload.isEmpty()) {
			return;
		}
		
		for (WebServer webServer : webServersToReload) {
			if ((webServersToIgnore != null) && (webServersToIgnore.contains(webServer))) {
				continue;
			}
			logger.debug("Reloading webServer on " + webServer.getHostHostName());
			webServer.reload();
		}
	}
	
	private void waitForWebServerReload(List<WebServer> webServers, List<WebServer> webServersToAdd, 
			List<AppServer> appServersToAdd) throws InterruptedException, IOException, AddFailedException {
		List<Future<Boolean>> actionReturns = new ArrayList<Future<Boolean>>();
		for (WebServer webServer : webServers) {
			if (webServersToAdd.contains(webServer)) {
				continue;
			}
			logger.debug("Waiting for reload complete for webServer on " + webServer.getHostHostName());
			actionReturns.add(executor.submit(new WebServerReloadWaiter(webServer)));
		}
		boolean actionSucceeded = true;
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
	
	private void configureAndReloadLbServers(List<LbServer> lbServers, List<WebServer> webServers,
			List<AppServer> appServers, List<WebServer> webServersToAdd, 
			List<AppServer> appServersToAdd) throws IOException, InterruptedException, AddFailedException {
		List<Future<Boolean>> actionReturns = new ArrayList<Future<Boolean>>();
		for (LbServer lbServer : lbServers) {
			logger.debug("Configuring lbServer on " + lbServer.getHostHostName());
			lbServer.configure(defaultsService.getLbServerDefaults(), lbServers.size(), appServers, webServers);
			logger.debug("Reloading lbServer on " + lbServer.getHostHostName());
			actionReturns.add(executor.submit(new LbServerReloader(lbServer)));
		}
		boolean actionSucceeded = true;
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
			logger.warn("Could not reload all current load balancers");
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

	}
	
	private void waitForLbServerReload(List<LbServer> lbServers) throws InterruptedException, AddFailedException {
		List<Future<Boolean>> actionReturns = new ArrayList<Future<Boolean>>();
		for (LbServer lbServer : lbServers) {
			logger.debug("Waiting for reload complete for lbServer on " + lbServer.getHostHostName());
			actionReturns.add(executor.submit(new LbServerReloadWaiter(lbServer)));
		}
		boolean actionSucceeded = true;
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
			throw new AddFailedException("Error waiting for lb server reload to complete");
		}

	}
	
	private void stopWebAndAppServers(List<WebServer> webServersToRemove, List<AppServer> appServersToRemove) throws InterruptedException {
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
			logger.debug("WebServerStarter.  Starting webServer " + webServer.getId());
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
			logger.debug("WebServerReloader.  Reloading webServer " + webServer.getId());
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
			logger.debug("WebServerReloadWaiter.  Reloading webServer " + webServer.getId());
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

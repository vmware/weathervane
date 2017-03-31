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
import java.util.concurrent.locks.Lock;

import javax.transaction.Transactional;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.model.configuration.AppInstance;
import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.configuration.LbServer;
import com.vmware.weathervane.auction.model.configuration.Service.ServiceState;
import com.vmware.weathervane.auction.model.configuration.WebServer;
import com.vmware.weathervane.auction.model.defaults.AppServerDefaults;
import com.vmware.weathervane.auction.repository.AppInstanceRepository;
import com.vmware.weathervane.auction.repository.AppServerRepository;
import com.vmware.weathervane.auction.repository.CoordinationServerRepository;
import com.vmware.weathervane.auction.repository.DbServerRepository;
import com.vmware.weathervane.auction.repository.LbServerRepository;
import com.vmware.weathervane.auction.repository.MsgServerRepository;
import com.vmware.weathervane.auction.repository.NosqlServerRepository;
import com.vmware.weathervane.auction.repository.WebServerRepository;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@Service
public class AppServerServiceImpl implements AppServerService {
	private static final Logger logger = LoggerFactory.getLogger(AppServerServiceImpl.class);

	@Autowired
	private DefaultsService defaultsService;

	@Autowired
	private AppInstanceRepository appInstanceRepository;

	@Autowired
	private AppServerRepository appServerRepository;

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

	@Override
	public AppServer getAppServer(Long id) throws ServiceNotFoundException {
		AppServer appServer = appServerRepository.findOne(id);
		if (appServer == null) {
			throw new ServiceNotFoundException();
		}
		return appServer;
	}

	@Override
	@Transactional
	public AppServer addAppServerInfo(AppServer appServer) throws DuplicateServiceException {
		
		List<AppServer> existingAppServers = appServerRepository.findByHostHostName(appServer.getHostHostName());
		
		appServer.setState(ServiceState.ACTIVE);
		appServer = appServerRepository.save(appServer);

		return appServer;
	}

	@Override
	public List<AppServer> getAppServers() {
		return appServerRepository.findAll();
	}

	@Override
	@Transactional
	public void configureAppServer(Long appServerId, AppServerDefaults defaults) throws ServiceNotFoundException, IOException, InterruptedException {
		AppServer appServer = appServerRepository.findOne(appServerId);
		if (appServer == null) {
			throw new ServiceNotFoundException();
		}

		AppInstance appInstance = appInstanceRepository.findOne(1L);
		if (appInstance == null) {
			throw new ServiceNotFoundException("Could not find appInstance with id 1");
		}

		appServer.configure(defaults, appInstance, appServerRepository.findAll(), webServerRepository.findAll(), dbServerRepository.findAll(),
				nosqlServerRepository.findAll(), msgServerRepository.findAll(), coordinationServerRepository.findAll());
		
	}

	@Override
	public void startAppServer(Long appServerId, AppServerDefaults defaults) throws ServiceNotFoundException, InterruptedException, IOException {
		AppServer appServer = appServerRepository.findOne(appServerId);
		if (appServer == null) {
			throw new ServiceNotFoundException();
		}

		appServer.start(defaults);
	}

	@Override
	@Transactional
	public synchronized AppServer addAppServer(AppServer appServer, AppServerDefaults defaults)
			throws ServiceNotFoundException, InterruptedException, IOException, DuplicateServiceException, AddFailedException, IllegalConfigurationException {
		logger.debug("addAppServer: " + appServer);

		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("addAppServer: " + appServer + " Got configurationChangeLock");

		try {
			long numWebServers = webServerRepository.count();
			long numLbServers = lbServerRepository.count();
			if ((numWebServers <= 0) && (numLbServers <= 0)) {
				throw new IllegalConfigurationException("Must be at least one web server or load-balancer to add an app server.");
			}

			appServer = appServerRepository.save(appServer);

			List<WebServer> webServers = webServerRepository.findAll();
			List<LbServer> lbServers = lbServerRepository.findAll();
			List<AppServer> appServers = appServerRepository.findAll();

			AppInstance appInstance = appInstanceRepository.findOne(1L);
			if (appInstance == null) {
				throw new ServiceNotFoundException("Could not find appInstance with id 1");
			}

			logger.debug("Configuring appServer on " + appServer.getHostHostName());
			appServer.configure(defaults, appInstance, appServers, webServers, dbServerRepository.findAll(), nosqlServerRepository.findAll(),
					msgServerRepository.findAll(), coordinationServerRepository.findAll());

			logger.debug("Starting appServer on " + appServer.getHostHostName());
			boolean startSuccceeded = appServer.start(defaults);

			if (startSuccceeded) {
				appServer = appServerRepository.save(appServer);
				appServers = appServerRepository.findAll();

				if (logger.isDebugEnabled()) {
					logger.debug("Configuring web servers with the following app servers:");
					for (AppServer anAppServer : appServers) {
						System.out.print(anAppServer.getHostName() + ",");
					}
					System.out.println();
				}
				/*
				 * Configure all of the web servers before reloading.
				 */
				if (webServers.size() > 0) {
					for (WebServer webServer : webServers) {
						logger.debug("Configuring and reloading webServer on " + webServer.getHostHostName());
						webServer.configure(defaultsService.getWebServerDefaults(), appInstance, webServerRepository.count(), appServers);
						webServer.reload();
					}

				} else {
					for (LbServer lbServer : lbServers) {
						logger.debug("Configuring and reloading lbServer on " + lbServer.getHostHostName());
						lbServer.configure(defaultsService.getLbServerDefaults(), numLbServers, appServers, webServers);
						lbServer.reload();
					}
				}
				return appServer;
			} else {
				throw new AddFailedException("Could not add appServer");
			}
		} finally {
			configurationChangeLock.unlock();
		}
	}

	@Override
	public void removeAppServer(Long id) throws ServiceNotFoundException, IOException, InterruptedException {
		logger.debug("removeAppServer id : " + id);
		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("removeAppServer: id = " + id + ". Got configurationChangeLock");

		try {
			AppServer appServer = appServerRepository.findOne(id);
			if (appServer == null) {
				throw new ServiceNotFoundException();
			}

			List<AppServer> appServers = appServerRepository.findAll();
			List<WebServer> webServers = webServerRepository.findAll();
			List<LbServer> lbServers = lbServerRepository.findAll();
			
			appServers.remove(appServer);

			AppInstance appInstance = appInstanceRepository.findOne(1L);
			if (appInstance == null) {
				throw new ServiceNotFoundException("Could not find appInstance with id 1");
			}

			if (logger.isDebugEnabled()) {
				logger.debug("Configuring web servers with the following app servers:");
				for (AppServer anAppServer : appServers) {
					System.out.print(anAppServer.getHostName() + ",");
				}
				System.out.println();
			}

			if (webServers.size() > 0) {
				for (WebServer webServer : webServers) {
					logger.debug("Configuring and reloading webServer on " + webServer.getHostHostName());
					webServer.configure(defaultsService.getWebServerDefaults(), appInstance, webServerRepository.count(), appServers);
				}
			} else {
				for (LbServer lbServer : lbServers) {
					logger.debug("Configuring and reloading lbServer on " + lbServer.getHostHostName());
					lbServer.configure(defaultsService.getLbServerDefaults(), lbServerRepository.count(), appServers, webServers);
				}
			}

			if (webServers.size() > 0) {
				for (WebServer webServer : webServers) {
					logger.debug("Reloading webServer on " + webServer.getHostHostName());
					webServer.reload();
				}
			} else {
				for (LbServer lbServer : lbServers) {
					logger.debug("Reloading lbServer on " + lbServer.getHostHostName());
					lbServer.reload();
				}
			}

			if (webServers.size() > 0) {
				for (WebServer webServer : webServers) {
					logger.debug("waiting for reload complete for webServer on " + webServer.getHostHostName());
					webServer.waitForReloadComplete();
				}
			}

			/*
			 *  Need to stop app server here once the web/lb servers have
			 *  finished reconfiguring
			 */
			appServer.stop();

			appServerRepository.delete(id);
		} finally {
			configurationChangeLock.unlock();
		}
	}

	@Override
	public void warmAppServer(Long id) throws ServiceNotFoundException {
		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("warmAppServer: id = " + id + " Got configurationChangeLock");

		try {
			logger.debug("warmAppServer id : " + id);
			AppServer appServer = appServerRepository.findOne(id);
			if (appServer == null) {
				throw new ServiceNotFoundException();
			}

			appServer.warmUp(1);
		} finally {
			configurationChangeLock.unlock();
		}
	}

	@Override
	public void warmAppServers(final List<Long> appServerIds) throws ServiceNotFoundException {
		if ((appServerIds == null) || (appServerIds.size() <= 0)) {
			return;
		}
		
		List<Thread> warmupThreads = new ArrayList<Thread>();

		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("warmAppServers: Got configurationChangeLock");
		try {
			/*
			 * There are only enough warmer users in the system to warm 
			 * this many appServers at once.
			 */
			long numSimultaneousWarms = 
					(long) Math.floor(AppServer.NUM_WARMER_USERS / 
							(AppServer.WARMER_THREADS_PER_APPSERVER * 1.0));
			
			List<Long> appServersToWarm = new ArrayList<>(appServerIds);
			
			logger.debug("warmAppServers.  Can warm " + numSimultaneousWarms +
					" simultaneous appServers. Warm Requested for " + 
					appServersToWarm.size() + " appServers.");
			while (!appServersToWarm.isEmpty()) {
				warmupThreads.clear();
				int numActiveWarms = 0;
				int startWarmerId = 1;
				while ((numActiveWarms < numSimultaneousWarms) && (!appServersToWarm.isEmpty())) {
					long id = appServersToWarm.remove(0);
					logger.debug("warmAppServers. Warming appServer with id " + id);

					AppServer appServer = appServerRepository.findOne(id);
					if (appServer == null) {
						throw new ServiceNotFoundException();
					}

					AppServerWarmer appServerWarmer = new AppServerWarmer(appServer, startWarmerId);
					Thread warmerThread = new Thread(appServerWarmer, "warmerThread" + id);
					warmupThreads.add(warmerThread);

					numActiveWarms++;
					startWarmerId += AppServer.WARMER_THREADS_PER_APPSERVER;
				}
				logger.debug("Warming " + numActiveWarms + " app servers");
				for (Thread warmupThread : warmupThreads) {
					warmupThread.start();
				}

				for (Thread warmupThread : warmupThreads) {
					try {
						warmupThread.join();
						numActiveWarms--;
						
					} catch (InterruptedException e) {
						logger.warn("warmUp thread " + warmupThread.getName() + " was interrupted before completing");
					}
				}
			}

		} finally {
			configurationChangeLock.unlock();
		}

	}
	
	private class AppServerWarmer implements Runnable {
		private AppServer appServer;
		private final int startWarmerId;
		
		protected AppServerWarmer(AppServer appServer, int startWarmerId) {
			this.appServer = appServer;
			this.startWarmerId = startWarmerId;
			
		}
		
		@Override
		public void run() {
			logger.debug("AppServerWarmer.  Warming appServer " + appServer.getId() + 
					" from start warmerId " + startWarmerId);
			appServer.warmUp(startWarmerId);
		}
		
	}
	
}

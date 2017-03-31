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
import com.vmware.weathervane.auction.model.configuration.WebServer;
import com.vmware.weathervane.auction.model.defaults.WebServerDefaults;
import com.vmware.weathervane.auction.repository.AppInstanceRepository;
import com.vmware.weathervane.auction.repository.AppServerRepository;
import com.vmware.weathervane.auction.repository.LbServerRepository;
import com.vmware.weathervane.auction.repository.WebServerRepository;
import com.vmware.weathervane.auction.service.exception.AddFailedException;
import com.vmware.weathervane.auction.service.exception.DuplicateServiceException;
import com.vmware.weathervane.auction.service.exception.IllegalConfigurationException;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;

@Service
public class WebServerServiceImpl implements WebServerService {
	private static final Logger logger = LoggerFactory.getLogger(WebServerServiceImpl.class);

	@Autowired
	private DefaultsService defaultsService;

	@Autowired
	private AppInstanceRepository appInstanceRepository;

	@Autowired
	private WebServerRepository webServerRepository;

	@Autowired
	private AppServerRepository appServerRepository;

	@Autowired
	private LbServerRepository lbServerRepository;

	@Override
	public List<WebServer> getWebServers() {
		return webServerRepository.findAll();
	}

	@Override
	public WebServer getWebServer(Long id) {
		return webServerRepository.findOne(id);
	}

	@Override
	public WebServer addWebServerInfo(WebServer webServer) throws DuplicateServiceException {
		logger.debug("addWebServerInfo: " + webServer.toString());
		webServer =  webServerRepository.save(webServer);
		webServer.initializeRuntimeInfo();

		return webServer;
	}


	@Override
	public void configureWebServer(Long webServerId, WebServerDefaults defaults)
			throws ServiceNotFoundException, IOException, InterruptedException {

		WebServer webServer = webServerRepository.findOne(webServerId);
		if (webServer == null) {
			throw new ServiceNotFoundException();
		}
		
		AppInstance appInstance = appInstanceRepository.findOne(1L);
		if (appInstance == null) {
			throw new ServiceNotFoundException("Could not find appInstance with id 1");
		}

		webServer.configure(defaults, appInstance, webServerRepository.count(), appServerRepository.findAll());

	}

	@Override
	public void startWebServer(Long webServerId, WebServerDefaults defaults)
			throws ServiceNotFoundException, InterruptedException {
		WebServer webServer = webServerRepository.findOne(webServerId);

		if (webServer == null) {
			throw new ServiceNotFoundException();
		}

		webServer.start(defaults);

	}

	@Override
	@Transactional
	public synchronized WebServer addWebServer(WebServer webServer, WebServerDefaults defaults)
			throws ServiceNotFoundException, InterruptedException, IOException, DuplicateServiceException, AddFailedException, IllegalConfigurationException {
		logger.debug("addWebServer: " + webServer);
		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("addWebServer: " + webServer + ". Got configurationChangeLock");

		try {

			long numLbServers = lbServerRepository.count();
			if (numLbServers <= 0) {
				throw new IllegalConfigurationException("Must be at least one load-balancer to add a web server.");
			}

			webServer = this.addWebServerInfo(webServer);

			List<LbServer> lbServers = lbServerRepository.findAll();
			List<AppServer> appServers = appServerRepository.findAll();

			AppInstance appInstance = appInstanceRepository.findOne(1L);
			if (appInstance == null) {
				throw new ServiceNotFoundException("Could not find appInstance with id 1");
			}

			logger.debug("Configuring webServer on " + webServer.getHostHostName());
			webServer.configure(defaults, appInstance, webServerRepository.count(), appServers);

			logger.debug("Starting webServer on " + webServer.getHostHostName());
			boolean startSuccceeded = webServer.start(defaults);

			if (startSuccceeded) {
				webServer = webServerRepository.save(webServer);
				List<WebServer> webServers = webServerRepository.findAll();

				if (logger.isDebugEnabled()) {
					logger.debug("Configuring lb servers with the following web servers:");
					for (WebServer aWebServer : webServers) {
						System.out.print(aWebServer.getHostName() + ",");
					}
					System.out.println();
				}

				for (LbServer lbServer : lbServers) {
					logger.debug("Configuring and reloading lbServer on " + lbServer.getHostHostName());
					lbServer.configure(defaultsService.getLbServerDefaults(), numLbServers, appServers, webServers);
					lbServer.reload();
				}

				return webServer;
			} else {
				throw new AddFailedException("Could not add webServer");
			}
		} finally {
			configurationChangeLock.unlock();
		}

	}

	@Override
	public void removeWebServer(Long id) throws ServiceNotFoundException, IOException, InterruptedException {
		logger.debug("removeWebServer id : " + id);
		Lock configurationChangeLock = ConfigurationChangeLock.getLock();
		configurationChangeLock.lock();

		logger.debug("removeWebServer id : " + id + ". Got configurationChangeLock");

		try {
			WebServer webServer = webServerRepository.findOne(id);
			if (webServer == null) {
				throw new ServiceNotFoundException();
			}

			List<AppServer> appServers = appServerRepository.findAll();
			List<WebServer> webServers = webServerRepository.findAll();
			List<LbServer> lbServers = lbServerRepository.findAll();
			webServers.remove(webServer);

			if (logger.isDebugEnabled()) {
				logger.debug("Configuring lb servers with the following web servers:");
				for (WebServer aWebServer : webServers) {
					System.out.print(aWebServer.getHostName() + ",");
				}
				System.out.println();
			}

			for (LbServer lbServer : lbServers) {
				logger.debug("Configuring and reloading lbServer on " + lbServer.getHostHostName());
				lbServer.configure(defaultsService.getLbServerDefaults(), lbServerRepository.count(), appServers, webServers);
			}

			for (LbServer lbServer : lbServers) {
				logger.debug("Configuring and reloading lbServer on " + lbServer.getHostHostName());
				lbServer.reload();
			}

			// Need to stop web server here once the lb servers have finished
			// reconfiguring
			webServer.stop();

			webServerRepository.delete(id);
		} finally {
			configurationChangeLock.unlock();
		}
	}
}

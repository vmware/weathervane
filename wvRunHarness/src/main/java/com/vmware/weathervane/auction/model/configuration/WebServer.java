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
package com.vmware.weathervane.auction.model.configuration;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.persistence.ElementCollection;
import javax.persistence.Entity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.model.defaults.WebServerDefaults;
import com.vmware.weathervane.auction.util.SshUtils;

@Entity
@JsonIgnoreProperties(ignoreUnknown = true)
public class WebServer extends Service {
	private static final Logger logger = LoggerFactory.getLogger(WebServer.class);
	private static final int WEBSERVER_STARTUP_TIMEOUT = 300;

	private String webServerImpl;
	private Integer webServerPortStep;
	private Integer webServerPortOffset;

	private Integer httpPort;
	private Integer httpsPort;
	private Integer httpInternalPort;
	private Integer httpsInternalPort;

	private Integer nginxMaxKeepaliveRequests;
	private Integer nginxKeepaliveTimeout;
	private Integer nginxWorkerConnections;
	private String nginxServerRoot;
	private String nginxDocumentRoot;

	@ElementCollection
	private List<Integer> workerPids = null;

	public WebServer() {

	}

	public boolean isRunning() {
		String hostHostName = getHostHostName();
		logger.debug("Checking whether web server is running on " + hostHostName);

		String status = SshUtils.SshExec(hostHostName, "service nginx status");
		Pattern runningPat1 = Pattern.compile("is running");
		Pattern runningPat2 = Pattern.compile("Active: active");

		logger.debug("service nginx status on " + hostHostName + " = " + status);
		if (runningPat1.matcher(status).find() || runningPat2.matcher(status).find()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean isUp() {

		RestTemplate restTemplate = new RestTemplate();
		ResponseEntity<String> response = null;
		try {
			response = restTemplate.getForEntity("http://" + getHostHostName() + ":" + getHttpInternalPort(), String.class);
		} catch (RestClientException e) {
			logger.info("Checking isUp got RestClientException: " + e.getMessage());
			return false;
		}

		if (response.getStatusCode().is2xxSuccessful()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean start(WebServerDefaults webServerDefaults) throws InterruptedException {
		String hostname = getHostHostName();
		logger.debug("webServer::start hostName = " + getHostName());

		if (isRunning()) {
			logger.debug("webServer::start hostName = " + getHostName() + ". Web Server was running, stopping.");
			stop();
			logger.debug("webServer::start hostName = " + getHostName() + ". Web Server was running, cleaning logs.");
			cleanLogs();
		}

		httpPort = httpInternalPort;
		httpsPort = httpsInternalPort;
		openPortNumber(getHttpPort());
		openPortNumber(getHttpsPort());
		startNscd();

		String output = SshUtils.SshExec(hostname, "systemctl start nginx");
		logger.debug("Result of starting web server is " + output);

		// Now need to wait until webServer is up
		int remainingWaitSec = WEBSERVER_STARTUP_TIMEOUT;
		while (remainingWaitSec > 0) {
			if (isUp()) {
				logger.debug("Web server is up.");
				retrieveWorkerPids();
				return true;
			}
			logger.debug("Web server is not up yet.  Sleeping for 15 seconds");
			Thread.sleep(15000);
			remainingWaitSec -= 15;
		}

		return false;

	}

	public void stopWorkers() {
		String hostname = getHostHostName();
		logger.debug("WebServer::stopWorkers hostName = " + getHostName());

		if (isRunning()) {

			Integer masterPid = retrieveMasterPid();
			String output = SshUtils.SshExec(hostname, "kill -WINCH " + masterPid.toString());
			logger.debug("Result of stopping web server workers is " + output);

		}
	}

	public void stop() {
		String hostname = getHostHostName();
		logger.debug("WebServer::stop hostName = " + getHostName());

		if (isRunning()) {

			String output = SshUtils.SshExec(hostname, "service nginx stop");
			logger.debug("Result of stopping web	 server is " + output);

		}

		if (getHttpPort() != null) {
			closePortNumber(getHttpPort());
		}
		if (getHttpsPort() != null) {
			closePortNumber(getHttpsPort());
		}

	}

	public void setPortNumbers(AppInstance appInstance) {
		long portOffset = 0L;
		if (!appInstance.getEdgeService().equals("webServer")) {
			if (webServerPortOffset == null) {
				logger.debug("setPortNumbers: webServerPortOffset is null");
				webServerPortOffset = 9000;
			}
			if (webServerPortStep == null) {
				logger.debug("setPortNumbers: webServerPortStep is null");
				webServerPortStep = 1;
			}
			portOffset = webServerPortOffset + (getId() - 1) * webServerPortStep;
		}

		if (httpInternalPort == null) {
			httpInternalPort = (int) (80 + portOffset);
		}

		if (httpsInternalPort == null) {
			httpsInternalPort = (int) (443 + portOffset);
		}

	}

	public void cleanLogs() {

	}

	public boolean reload() throws IOException, InterruptedException {

		String hostname = getHostHostName();
		retrieveWorkerPids();
		String output = SshUtils.SshExec(hostname, "/usr/sbin/nginx -s reload");
		logger.debug("Result of reload of web server on " + hostname + " is: " + output);

		/*
		 * ToDo: Don't currently determine whether the reload failed. 
		 */
		return true;
	}

	public boolean waitForReloadComplete() throws IOException, InterruptedException {

		String hostname = getHostHostName();

		/*
		 * Wait until previous nginx worker processes have finished before
		 * returning. This indicates that the reload is complete.
		 */
		boolean reloadFinished = false;
		List<Integer> oldPids = workerPids;
		do {
			retrieveWorkerPids();
			reloadFinished = true;
			for (Integer pid : oldPids) {
				if (workerPids.contains(pid)) {
					logger.debug("For reload of web server on " + hostname + ", old processes still up.");
					reloadFinished = false;
					break;
				}
			}
			if (!reloadFinished) {
				Thread.sleep(15000);
			}
		} while (!reloadFinished);
		
		logger.debug("For reload of web server on " + hostname + ", all old processes finished.");
		return true;
	}

	public WebServer configure(WebServerDefaults defaults, AppInstance appInstance, long numWebServers, List<AppServer> appServers)
			throws IOException, InterruptedException {

		setPortNumbers(appInstance);

		String hostname = getHostHostName();
		long workerConnections = (long) Math.ceil(getFrontendConnectionMultiplier() * getUsers() / (numWebServers * 1.0));
		if (workerConnections < 100) {
			workerConnections = 100;
		}

		String upsteamString = "\tupstream appServers {\nleast_conn;\n";
		for (AppServer appServer : appServers) {
			String appHostname = getHostnameForUsedService(appServer);
			Integer appPort = appServer.getHttpPort();
			if (corunningDockerized(appServer)) {
				appPort = appServer.getHttpInternalPort();
			}
			upsteamString += "\t\t" + "server " + appHostname + ":" + appPort + " max_fails=0;\n";
		}
		upsteamString += "      keepalive 1000;\n";
		upsteamString += "}\n";

		String newNginxConfFile = String.format(defaults.getNginxConfFile(), workerConnections, getNginxMaxKeepaliveRequests(), getNginxKeepaliveTimeout(),
				upsteamString);

		SshUtils.ScpStringTo(newNginxConfFile, hostname, getNginxServerRoot() + "/nginx.conf");

		String rewriteRules = "";
		if (getImageStoreType().equals("filesystem")) {
			rewriteRules = "if ($query_string ~ \"size=(.*)$\") {\n" + "set $size $1;\n"
					+ "rewrite ^/auction/image/([^\\.]*).(\\.*)$ /imageStore/$1_$size.$2;\n" + "}\n" + "location /imageStore{\n" + "root /mnt;\n" + "}\n";
		}

		String newSslConfFile = String.format(defaults.getSslConfFile(), "\tlisten " + getHttpsInternalPort() + " ssl backlog=16384;\n", rewriteRules);

		SshUtils.ScpStringTo(newSslConfFile, hostname, getNginxServerRoot() + "/conf.d/ssl.conf");

		String newDefaultConfFile = String.format(defaults.getDefaultConfFile(), "\tlisten " + getHttpInternalPort() + " backlog=16384;\n", rewriteRules);
		SshUtils.ScpStringTo(newDefaultConfFile, hostname, getNginxServerRoot() + "/conf.d/default.conf");

		return this;
	}

	public void initializeRuntimeInfo() {
		this.retrieveWorkerPids();
	}

	private List<Integer> retrieveWorkerPids() {
		String hostname = getHostHostName();

		String psList = SshUtils.SshExec(hostname, "ps ax | grep \"nginx: worker\"  | grep -v grep");

		logger.debug("retrieveWorkerPids for web server on  " + hostname + " returned: " + psList);

		Pattern pidPattern = Pattern.compile("(\\d+)\\s+.*:.*nginx:\\sworker");

		Matcher pidMatcher = pidPattern.matcher(psList);

		workerPids = new ArrayList<Integer>();
		while (pidMatcher.find()) {
			logger.debug("retrieveWorkerPids for web server on  " + hostname + " found pid " + pidMatcher.group(1));
			workerPids.add(Integer.decode(pidMatcher.group(1)));
		}

		return workerPids;
	}

	private Integer retrieveMasterPid() {
		String hostname = getHostHostName();

		String psList = SshUtils.SshExec(hostname, "ps ax | grep \"nginx: master\"  | grep -v grep");

		logger.debug("retrieveMasterPid for web server on  " + hostname + " returned: " + psList);

		Pattern pidPattern = Pattern.compile("(\\d+)\\s+.*:.*nginx:\\smaster");

		Matcher pidMatcher = pidPattern.matcher(psList);

		Integer masterPid = null;
		if (pidMatcher.find()) {
			logger.debug("retrieveMasterPid for web server on  " + hostname + " found pid " + pidMatcher.group(1));
			masterPid = Integer.decode(pidMatcher.group(1));
		}

		return masterPid;
	}

	public List<Integer> getWorkerPids() {
		return workerPids;
	}

	public void setWorkerPids(List<Integer> workerPids) {
		this.workerPids = workerPids;
	}

	public String getWebServerImpl() {
		return webServerImpl;
	}

	public void setWebServerImpl(String webServerImpl) {
		this.webServerImpl = webServerImpl;
	}

	public Integer getWebServerPortStep() {
		return webServerPortStep;
	}

	public void setWebServerPortStep(Integer webServerPortStep) {
		this.webServerPortStep = webServerPortStep;
	}

	public Integer getWebServerPortOffset() {
		return webServerPortOffset;
	}

	public void setWebServerPortOffset(Integer webServerPortOffset) {
		this.webServerPortOffset = webServerPortOffset;
	}

	public Integer getNginxMaxKeepaliveRequests() {
		return nginxMaxKeepaliveRequests;
	}

	public void setNginxMaxKeepaliveRequests(Integer nginxMaxKeepaliveRequests) {
		this.nginxMaxKeepaliveRequests = nginxMaxKeepaliveRequests;
	}

	public Integer getNginxKeepaliveTimeout() {
		return nginxKeepaliveTimeout;
	}

	public void setNginxKeepaliveTimeout(Integer nginxKeepaliveTimeout) {
		this.nginxKeepaliveTimeout = nginxKeepaliveTimeout;
	}

	public Integer getNginxWorkerConnections() {
		return nginxWorkerConnections;
	}

	public void setNginxWorkerConnections(Integer nginxWorkerConnections) {
		this.nginxWorkerConnections = nginxWorkerConnections;
	}

	public String getNginxServerRoot() {
		return nginxServerRoot;
	}

	public void setNginxServerRoot(String nginxServerRoot) {
		this.nginxServerRoot = nginxServerRoot;
	}

	public String getNginxDocumentRoot() {
		return nginxDocumentRoot;
	}

	public void setNginxDocumentRoot(String nginxDocumentRoot) {
		this.nginxDocumentRoot = nginxDocumentRoot;
	}

	public Integer getHttpPort() {
		return httpPort;
	}

	public void setHttpPort(Integer httpPort) {
		this.httpPort = httpPort;
	}

	public Integer getHttpsPort() {
		return httpsPort;
	}

	public void setHttpsPort(Integer httpsPort) {
		this.httpsPort = httpsPort;
	}

	public Integer getHttpInternalPort() {
		return httpInternalPort;
	}

	public void setHttpInternalPort(Integer httpInternalPort) {
		this.httpInternalPort = httpInternalPort;
	}

	public Integer getHttpsInternalPort() {
		return httpsInternalPort;
	}

	public void setHttpsInternalPort(Integer httpsInternalPort) {
		this.httpsInternalPort = httpsInternalPort;
	}

	public WebServer mergeDefaults(final WebServerDefaults defaults) {
		WebServer mergedWebServer = (WebServer) super.mergeDefaults(this, defaults);
		mergedWebServer.setWebServerImpl(webServerImpl != null ? webServerImpl : defaults.getWebServerImpl());
		mergedWebServer.setWebServerPortOffset(webServerPortOffset != null ? webServerPortOffset : defaults.getWebServerPortOffset());
		mergedWebServer.setWebServerPortStep(webServerPortStep != null ? webServerPortStep : defaults.getWebServerPortStep());
		mergedWebServer.setNginxDocumentRoot(nginxDocumentRoot != null ? nginxDocumentRoot : defaults.getNginxDocumentRoot());
		mergedWebServer.setNginxKeepaliveTimeout(nginxKeepaliveTimeout != null ? nginxKeepaliveTimeout : defaults.getNginxKeepaliveTimeout());
		mergedWebServer.setNginxMaxKeepaliveRequests(nginxMaxKeepaliveRequests != null ? nginxMaxKeepaliveRequests : defaults.getNginxMaxKeepaliveRequests());
		mergedWebServer.setNginxServerRoot(nginxServerRoot != null ? nginxServerRoot : defaults.getNginxServerRoot());
		mergedWebServer.setNginxWorkerConnections(nginxWorkerConnections != null ? nginxWorkerConnections : defaults.getNginxWorkerConnections());
		mergedWebServer.setImageStoreType(getImageStoreType() != null ? getImageStoreType() : defaults.getImageStoreType());

		logger.debug("mergeDefaults setting webServerPortOffset default value = " + defaults.getWebServerPortOffset());
		mergedWebServer.setWebServerPortOffset(webServerPortOffset != null ? webServerPortOffset : defaults.getWebServerPortOffset());

		logger.debug("mergeDefaults setting webServerPortStep default value = " + defaults.getWebServerPortStep());
		mergedWebServer.setWebServerPortStep(webServerPortStep != null ? webServerPortStep : defaults.getWebServerPortStep());

		return mergedWebServer;
	}

	@Override
	public String toString() {
		return "WebServer [webServerImpl=" + webServerImpl + ", webServerPortStep=" + webServerPortStep + ", webServerPortOffset=" + webServerPortOffset
				+ ", httpPort=" + httpPort + ", httpsPort=" + httpsPort + ", httpInternalPort=" + httpInternalPort + ", httpsInternalPort=" + httpsInternalPort
				+ ", nginxMaxKeepaliveRequests=" + nginxMaxKeepaliveRequests + ", nginxKeepaliveTimeout=" + nginxKeepaliveTimeout + ", nginxWorkerConnections="
				+ nginxWorkerConnections + ", nginxServerRoot=" + nginxServerRoot + ", nginxDocumentRoot=" + nginxDocumentRoot + ", workerPids=" + workerPids + "]";
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof WebServer))
			return false;
		if (obj == this)
			return true;

		WebServer rhs = (WebServer) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}

}

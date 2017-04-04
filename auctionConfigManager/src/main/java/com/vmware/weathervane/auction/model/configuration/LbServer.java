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

import javax.persistence.Entity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.model.defaults.LbServerDefaults;
import com.vmware.weathervane.auction.util.SshUtils;

@Entity
@JsonIgnoreProperties(ignoreUnknown = true)
public class LbServer extends Service {
	private static final Logger logger = LoggerFactory.getLogger(LbServer.class);
	private static final int LBSERVER_STARTUP_TIMEOUT = 300;

	private String lbServerImpl;

	private Integer haproxyMaxConn;
	private String haproxyServerRoot;

	private Integer statsPort;
	private Integer statsInternalPort;
	private Integer httpPort;
	private Integer httpsPort;
	private Integer httpInternalPort;
	private Integer httpsInternalPort;
	private Boolean haproxyTerminateTLS;

	
	private Integer _pid;

	public String getLbServerImpl() {
		return lbServerImpl;
	}

	public boolean isRunning() {
		String hostHostName = getHostHostName();
		logger.debug("Checking whether load balancer is running on " + hostHostName);

		String status = SshUtils.SshExec(hostHostName, "ps aux | grep /usr/sbin/haproxy | grep -v grep");
		Pattern runningPat1 = Pattern.compile("haproxy");

		logger.debug("ps aux | grep /usr/sbin/haproxy | grep -v grep on " + hostHostName + " = " + status);
		if (runningPat1.matcher(status).find()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean isUp() {
		return isRunning();
	}

	public boolean start(LbServerDefaults lbServerDefaults) throws InterruptedException {
		String hostname = getHostHostName();
		logger.debug("AppServer::start hostName = " + getHostName());

		if (isRunning()) {
			stop();
			cleanLogs();
		}

		httpPort = httpInternalPort;
		httpsPort = httpsInternalPort;
		statsPort = statsInternalPort;
		openPortNumber(getHttpPort());
		openPortNumber(getHttpsPort());
		openPortNumber(getStatsPort());
		startNscd();

		String output = SshUtils.SshExec(hostname, "$sshConnectString /usr/sbin/haproxy -f " + haproxyServerRoot + "/haproxy.cfg -D -p /run/haproxy.pid  -sf $(cat /run/haproxy.pid)");
		logger.debug("Result of starting load balancer is " + output);

		// Now need to wait until appServer is up
		int remainingWaitSec = LBSERVER_STARTUP_TIMEOUT;
		while (remainingWaitSec > 0) {
			if (isUp()) {
				logger.debug("Load Balancer is up.");
				return true;
			}
			logger.debug("Load Balancer is not up yet.  Sleeping for 15 seconds");
			Thread.sleep(15000);
			remainingWaitSec -= 15;
		}

		return false;

	}

	public void stop() {
		logger.debug("LbServer::stop hostName = " + getHostName());

		if (isRunning()) {

			logger.warn("stop of load balancer is not yet implemented");

		}

		if (getHttpPort() != null) {
			closePortNumber(getHttpPort());
		}
		if (getHttpsPort() != null) {
			closePortNumber(getHttpsPort());
		}

	}

	public void cleanLogs() {

	}

	public boolean reload() throws IOException, InterruptedException {

		String hostname = getHostHostName();
		String output;
		
// 		output = SshUtils.SshExec(hostname, "iptables -I INPUT -p tcp --dport " + getHttpPort() + " --syn -j DROP"); 
//		output = SshUtils.SshExec(hostname, "iptables -I INPUT -p tcp --dport " + getHttpsPort() + " --syn -j DROP");
//		Thread.sleep(100);
		String pid = SshUtils.SshExec(hostname, "cat /run/haproxy.pid");
		pid = pid.replaceAll("\\r|\\n", "");
		_pid = Integer.decode(pid);
		output = SshUtils.SshExec(hostname, "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -p /run/haproxy.pid -sf " + _pid.toString());
		logger.debug("Result of reload of load balancer on " + hostname + " is: " + output);
//		output = SshUtils.SshExec(hostname, "iptables -D INPUT -p tcp --dport " + getHttpPort() + " --syn -j DROP");
//		output = SshUtils.SshExec(hostname, "iptables -D INPUT -p tcp --dport " + getHttpsPort() + " --syn -j DROP");
	
		return true;
	}

	public Boolean waitForReloadComplete() throws InterruptedException {
		String hostname = getHostHostName();
		logger.debug("Wait for reload of lb server on " + hostname + ", old pid = " + _pid);

		/*
		 * Wait until previous haproxy process has finished before
		 * returning. This indicates that the reload is complete.
		 */
		boolean reloadFinished = false;
		do {
			List<Integer> runningPids = retrieveRunningPids();
			reloadFinished = true;
			if (runningPids.contains(_pid)) {
				logger.debug("For reload of lb server on " + hostname + ", old processes still up.");
				reloadFinished = false;
			}
			if (!reloadFinished) {
				Thread.sleep(15000);
			}
		} while (!reloadFinished);
		
		logger.debug("For reload of lb server on " + hostname + ", all old processes finished.");
		return true;	
	}
	
	private List<Integer> retrieveRunningPids() {
		String hostname = getHostHostName();

		String psList = SshUtils.SshExec(hostname, "ps ax | grep \"/usr/sbin/haproxy\"  | grep -v grep");

		logger.debug("retrieveRunningPids for lb server on  " + hostname + " returned: " + psList);

		Pattern pidPattern = Pattern.compile("(\\d+)\\s+.*:.*/usr/sbin/haproxy");

		Matcher pidMatcher = pidPattern.matcher(psList);

		List<Integer> runningPids = new ArrayList<Integer>();
		while (pidMatcher.find()) {
			logger.debug("retrieveRunningPids for lb server on  " + hostname + " found pid " + pidMatcher.group(1));
			runningPids.add(Integer.decode(pidMatcher.group(1)));
		}

		return runningPids;
	}


	public LbServer configure(LbServerDefaults defaults, long numLbServers, List<AppServer> appServers, List<WebServer> webServers)
			throws IOException, InterruptedException {
		String hostname = getHostHostName();
		int numWebServers = webServers.size();

		long maxConn = getFrontendConnectionMultiplier() * (long) Math.floor(getUsers() / numLbServers);
		if (haproxyMaxConn > 0) {
			maxConn = haproxyMaxConn;
		}
		
		long serverMaxConn = maxConn;
		
		String backendHttpServerString = "";
		String backendHttpsServerString = "";
		if (numWebServers > 0) {
			int cnt = 1;
			for (WebServer webServer : webServers) {
				String svrHostname = getHostnameForUsedService(webServer);
				backendHttpServerString += "\tserver web" + cnt + " " + svrHostname + ":" + webServer.getHttpPort() + " check " + " maxconn " + serverMaxConn + "\n";
				backendHttpsServerString += "\tserver web" + cnt + " " + svrHostname + ":" + webServer.getHttpsPort() + " check " + " maxconn " + serverMaxConn
						+ "\n";
				cnt++;
			}
		} else {
			int cnt = 1;
			for (AppServer appServer : appServers) {
				String svrHostname = getHostnameForUsedService(appServer);
				backendHttpServerString += "\tserver web" + cnt + " " + svrHostname + ":" + appServer.getHttpPort() + " check " + " maxconn " + serverMaxConn + "\n";
				backendHttpsServerString += "\tserver web" + cnt + " " + svrHostname + ":" + appServer.getHttpsPort() + " check " + " maxconn " + serverMaxConn
						+ "\n";
				cnt++;
			}
		}

		String newHaproxyCfgFile = null;
		if (haproxyTerminateTLS) {
			newHaproxyCfgFile = String.format(defaults.getHaproxyCfgFile(), maxConn, "1", maxConn, 
					getStatsInternalPort(), getHttpInternalPort(),
				getHttpsInternalPort(), backendHttpServerString, backendHttpsServerString);
		} else {
			newHaproxyCfgFile = String.format(defaults.getHaproxyTerminateTLSCfgFile(), maxConn, this.getHostCpus(), 
					maxConn, getStatsInternalPort(), getHttpInternalPort(),
					getHttpsInternalPort(), backendHttpServerString);			
		}
		SshUtils.ScpStringTo(newHaproxyCfgFile, hostname, getHaproxyServerRoot() + "/haproxy.cfg");
		return this;
	}

	public void setLbServerImpl(String lbServerImpl) {
		this.lbServerImpl = lbServerImpl;
	}

	public Integer getHaproxyMaxConn() {
		return haproxyMaxConn;
	}

	public void setHaproxyMaxConn(Integer haproxyMaxConn) {
		this.haproxyMaxConn = haproxyMaxConn;
	}

	public String getHaproxyServerRoot() {
		return haproxyServerRoot;
	}

	public void setHaproxyServerRoot(String haproxyServerRoot) {
		this.haproxyServerRoot = haproxyServerRoot;
	}

	public Integer getStatsPort() {
		return statsPort;
	}

	public void setStatsPort(Integer statsPort) {
		this.statsPort = statsPort;
	}

	public Integer getStatsInternalPort() {
		return statsInternalPort;
	}

	public void setStatsInternalPort(Integer statsInternalPort) {
		this.statsInternalPort = statsInternalPort;
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

	public LbServer mergeDefaults(final LbServerDefaults defaults) {
		LbServer mergedLbServer = (LbServer) super.mergeDefaults(this, defaults);
		mergedLbServer.setLbServerImpl(lbServerImpl != null ? lbServerImpl : defaults.getLbServerImpl());
		mergedLbServer.setHaproxyTerminateTLS(haproxyTerminateTLS != null ? haproxyTerminateTLS : defaults.getHaproxyTerminateTLS());

		return mergedLbServer;
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof LbServer))
			return false;
		if (obj == this)
			return true;

		LbServer rhs = (LbServer) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}

	public Boolean getHaproxyTerminateTLS() {
		return haproxyTerminateTLS;
	}

	public void setHaproxyTerminateTLS(Boolean haproxyTerminateTLS) {
		this.haproxyTerminateTLS = haproxyTerminateTLS;
	}
}

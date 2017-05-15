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
import java.util.Map;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import javax.persistence.Entity;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.core.ParameterizedTypeReference;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.client.RestClientException;
import org.springframework.web.client.RestTemplate;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.fasterxml.jackson.annotation.JsonTypeName;
import com.vmware.weathervane.auction.model.defaults.AppServerDefaults;
import com.vmware.weathervane.auction.representation.AttendanceRecordRepresentation;
import com.vmware.weathervane.auction.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.representation.AuthenticationRequestRepresentation;
import com.vmware.weathervane.auction.representation.BidRepresentation;
import com.vmware.weathervane.auction.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.representation.ItemRepresentation;
import com.vmware.weathervane.auction.representation.LoginResponse;
import com.vmware.weathervane.auction.representation.Representation;
import com.vmware.weathervane.auction.representation.UserRepresentation;
import com.vmware.weathervane.auction.representation.Representation.RestAction;
import com.vmware.weathervane.auction.service.exception.ServiceNotFoundException;
import com.vmware.weathervane.auction.util.SshUtils;

@Entity
@JsonIgnoreProperties(ignoreUnknown = true)
@JsonTypeName(value = "appServer")
public class AppServer extends Service {
	private static final Logger logger = LoggerFactory.getLogger(AppServer.class);

	private static final int APPSERVER_STARTUP_TIMEOUT = 300;
	public static final int NUM_WARMER_USERS = 40;
	public static final int WARMER_THREADS_PER_APPSERVER = 10;
	public static final int WARMER_ITERATIONS = 5000;

	private String appServerJvmOpts;
	private Integer appServerThreads;
	private Integer appServerJdbcConnections;

	private Integer appServerPortOffset;
	private Integer appServerPortStep;

	private String appServerImpl;
	private String appServerCacheImpl;
	private String igniteAuthTokenCacheMode;
	private Boolean igniteCopyOnRead;
	private Boolean appServerPerformanceMonitor;
	private Boolean appServerEnableJprofiler;
	private Boolean randomizeImages;
	private Boolean useImageWriterThreads;
	private Integer imageWriterThreads;
	private Integer numClientUpdateThreads;
	private Integer numAuctioneerThreads;
	private Integer newBidQueueConcurrency;
	private Integer highBidQueueConcurrency;
	private Integer appServerThumbnailImageCacheSizeMultiplier;
	private Integer appServerPreviewImageCacheSizeMultiplier;
	private Integer appServerFullImageCacheSizeMultiplier;

	private String tomcatCatalinaHome;
	private String tomcatCatalinaBase;

	private Integer httpPort;
	private Integer httpsPort;
	private Integer shutdownPort;
	private Integer httpInternalPort;
	private Integer httpsInternalPort;
	private Integer shutdownInternalPort;

	private Integer usersPerAuctionScaleFactor;

	private Boolean prewarmAppServers;
	
	public boolean isRunning() throws InterruptedException, IOException {
		String hostHostName = getHostHostName();
		logger.debug("Checking whether app server is running on " + hostHostName);

		String jpsInfo = SshUtils.SshExec(hostHostName, "jps");
		Pattern procPattern = Pattern.compile("Bootstrap");

		logger.debug("jps on " + hostHostName + " = " + jpsInfo);
		if (procPattern.matcher(jpsInfo).find()) {
			return true;
		} else {
			return false;
		}
	}

	public boolean isUp() {

		RestTemplate restTemplate = new RestTemplate();
		String response = "";
		try {
			response = restTemplate.getForObject(
					"http://" + getHostHostName() + ":" + getHttpInternalPort() + "/auction/healthCheck",
					String.class);
			logger.info("isUp got response " + response);
		} catch (RestClientException e) {
			logger.info("Checking isUp got RestClientException: " + e.getMessage());
			return false;
		}

		if (response.equals("alive")) {
			return true;
		} else {
			return false;
		}
	}
	
	public void prepareToShutdown() {
		RestTemplate restTemplate = new RestTemplate();
		Boolean response = false;
		try {
			String url = "http://" + getHostHostName() + ":" + getHttpInternalPort() + "/auction/live/auction/prepareForShutdown";
			response = restTemplate.getForObject(url, Boolean.class);
			logger.info("prepareToShutdown got response " + response + " for url " + url);
		} catch (RestClientException e) {
			logger.info("prepareToShutdown got RestClientException: " + e.getMessage());
		}
		
	}
	
	public void releaseAsyncRequests() {
		RestTemplate restTemplate = new RestTemplate();
		Boolean response = false;
		try {
			String url = "http://" + getHostHostName() + ":" + getHttpInternalPort() + "/auction/live/auction/release";
			response = restTemplate.getForObject(url, Boolean.class);
			logger.info("releaseAsyncRequests got response " + response + " for url " + url);
		} catch (RestClientException e) {
			logger.info("releaseAsyncRequests got RestClientException: " + e.getMessage());
		}
		
	}

	public boolean isMaster() {

		RestTemplate restTemplate = new RestTemplate();
		Boolean response = false;
		try {
			String url = "http://" + getHostHostName() + ":" + getHttpInternalPort() + "/auction/live/auction/isMaster";
			response = restTemplate.getForObject(url, Boolean.class);
			logger.info("isMaster got response " + response + " for url " + url);
		} catch (RestClientException e) {
			logger.info("Checking isUp got RestClientException: " + e.getMessage());
			return false;
		}
		return response;
	}

	public AppServer configure(AppServerDefaults defaults, AppInstance appInstance, List<AppServer> appServers,
			List<WebServer> webServers, List<DbServer> dbServers, List<NosqlServer> nosqlServers,
			List<MsgServer> msgServers, List<CoordinationServer> coordinationServers) throws ServiceNotFoundException, IOException, InterruptedException {
		logger.debug("AppServer::configure hostName = " + getHostName());

		setPortNumbers(appInstance);

		String hostname = getHostHostName();

		String jvmOpts = getJvmOpts(appServers, webServers, dbServers, nosqlServers, msgServers, coordinationServers);
		if (!jvmOpts.contains("CompileThreshold")) {
			jvmOpts += " -XX:CompileThreshold=2000 ";
		}
		
		String newSetenvShFile = String.format(defaults.getSetenvShFile(), jvmOpts);

		logger.debug("Copying new setenv.sh file to " + getTomcatCatalinaBase() + "/bin/setenv.sh on " + hostname);
		SshUtils.ScpStringTo(newSetenvShFile, hostname, getTomcatCatalinaBase() + "/bin/setenv.sh");

		Integer maxConnections = (int) Math
				.ceil((getFrontendConnectionMultiplier() * getUsers()) / (appServers.size() * 1.0));
		if (maxConnections < 100) {
			maxConnections = 100;
		}
		long maxIdle = (long) Math.ceil(getAppServerJdbcConnections() / 2.0);

		long minThreads = (long) Math.ceil(getAppServerThreads() / 3);

		DbServer dbServer = dbServers.get(0);
		String dbHostname = getHostnameForUsedService(dbServer);
		Integer dbPort = dbServer.getPostgresqlPort();
		if (corunningDockerized(dbServer)) {
			dbPort = dbServer.getPostgresqlInternalPort();
		}

		String dbUrl = "";
		String driverClassName = "";
		if (dbServer.getDbServerImpl().equals("mysql")) {
			driverClassName = "com.mysql.jdbc.Driver";
			dbUrl = "jdbc:mysql://" + dbHostname + ":" + dbPort + "/auction";
		} else if (dbServer.getDbServerImpl().equals("postgresql")) {
			driverClassName = "org.postgresql.Driver";
			dbUrl = "jdbc:postgresql://" + dbHostname + ":" + dbPort + "/auction";
		}

		String connectorString = "<Connector\n" + "acceptCount=\"100\"\n" + "acceptorThreadCount=\"2\"\n"
				+ "connectionTimeout=\"60000\"\n" + "asyncTimeout=\"60000\"\n" + "disableUploadTimeout=\"false\"\n"
				+ "connectionUploadTimeout=\"240000\"\n" + "socketBuffer=\"65536\"\n"
				+ "executor=\"tomcatThreadPool\"\n" + "maxKeepAliveRequests=\"-1\"\n" + "keepAliveTimeout=\"-1\"\n"
				+ "maxConnections=\"" + maxConnections + "\"\n"
				+ "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n";

		if ((getSsl() != null) && getSsl() && (webServers.size() == 0)) {
			// If using ssl, reconfigure the connector
			// to handle ssl on https port
			// output an ssl connector and a redirect connector
			connectorString += "port=\"" + getHttpsInternalPort() + "\"\n"
					+ "scheme=\"https\" secure=\"true\" SSLEnabled=\"true\"\n"
					+ "keystoreFile=\"/etc/pki/tls/weathervane.jks\" keystorePass=\"weathervane\"\n"
					+ "clientAuth=\"false\" sslProtocol=\"TLS\"/>\n" + "<Connector port=\"" + getHttpInternalPort()
					+ "\"\n" + "enableLookups=\"false\" \n" + "redirectPort=\"" + getHttpsInternalPort() + "\"/>\n"
					+ "acceptCount=\"100\"\n" + "acceptorThreadCount=\"2\"\n" + "socketBuffer=\"65536\"\n"
					+ "connectionTimeout=\"60000\"\n" + "disableUploadTimeout=\"false\"\n"
					+ "connectionUploadTimeout=\"240000\"\n" + "asyncTimeout=\"60000\"\n"
					+ "executor=\"tomcatThreadPool\"\n" + "maxKeepAliveRequests=\"-1\"\n" + "keepAliveTimeout=\"-1\"\n"
					+ "maxConnections=\"" + maxConnections + "\"\n"
					+ "protocol=\"org.apache.coyote.http11.Http11NioProtocol\"\n" + "/>\n";
		} else {
			connectorString += "port=\"" + getHttpInternalPort() + "\"\n" + "redirectPort=\"" + getHttpsInternalPort()
					+ "\"/>\n";
		}

		String newServerXmlFile = String.format(defaults.getServerXmlFile(), getShutdownInternalPort(),
				"\tmaxActive=\"" + getAppServerJdbcConnections() + "\"", "\tmaxIdle=\"" + maxIdle + "\"",
				"\tinitialSize=\"" + maxIdle + "\"", "\turl=\"" + dbUrl + "\"",
				"\tdriverClassName=\"" + driverClassName + "\"",
				"<Executor maxThreads=\"" + getAppServerThreads() + "\"", "\tminSpareThreads=\"" + minThreads + "\"",
				connectorString,
				"    <Engine name=\"Catalina\" defaultHost=\"localhost\" jvmRoute=\"" + hostname + "\">");

		logger.debug("Copying new server.xml file to " + getTomcatCatalinaBase() + "/conf/server.xml on " + hostname);
		SshUtils.ScpStringTo(newServerXmlFile, hostname, getTomcatCatalinaBase() + "/conf/server.xml");

		return this;
	}

	public boolean start(AppServerDefaults appServerDefaults) throws InterruptedException, IOException {
		String hostname = getHostHostName();
		logger.debug("AppServer::start hostName = " + getHostName());

		if (isRunning()) {
			stop();
		}
		cleanLogs();
		
		httpPort = httpInternalPort;
		httpsPort = httpsInternalPort;
		shutdownPort = shutdownInternalPort;
		openPortNumber(getHttpPort());
		openPortNumber(getHttpsPort());
		openPortNumber(getShutdownPort());
		startNscd();
				
		String output = SshUtils.SshExec(hostname,
				" CATALINA_BASE=\"" + getTomcatCatalinaBase() + "\" " + getTomcatCatalinaHome() + "/bin/startup.sh");
		logger.debug("Result of starting app server is " + output);

		// Now need to wait until appServer is up
		int remainingWaitSec = APPSERVER_STARTUP_TIMEOUT;
		while (remainingWaitSec > 0) {
			if (isUp()) {
				logger.debug("App server is up.");
				
				/*
				 * Warm up the app server before returning
				 */
				return this.warmUp(1);
			}
			logger.debug("App server is not up yet.  Sleeping for 15 seconds");
			Thread.sleep(15000);
			remainingWaitSec -= 15;
		}

		return false;

	}

	public boolean startWithoutWarmup(AppServerDefaults appServerDefaults) throws InterruptedException, IOException {
		String hostname = getHostHostName();
		logger.debug("AppServer::startWithoutWarmup hostName = " + getHostName());

		if (isRunning()) {
			stop();
		}
		cleanLogs();
		
		httpPort = httpInternalPort;
		httpsPort = httpsInternalPort;
		shutdownPort = shutdownInternalPort;
		openPortNumber(getHttpPort());
		openPortNumber(getHttpsPort());
		openPortNumber(getShutdownPort());
		startNscd();
				
		String output = SshUtils.SshExec(hostname,
				" CATALINA_BASE=\"" + getTomcatCatalinaBase() + "\" " + getTomcatCatalinaHome() + "/bin/startup.sh");
		logger.debug("Result of starting app server is " + output);

		// Now need to wait until appServer is up
		int remainingWaitSec = APPSERVER_STARTUP_TIMEOUT;
		while (remainingWaitSec > 0) {
			if (isUp()) {
				logger.debug("App server is up.");
				return true;
			}
			logger.debug("App server is not up yet.  Sleeping for 15 seconds");
			Thread.sleep(15000);
			remainingWaitSec -= 15;
		}

		return false;

	}

	public void stop() throws InterruptedException, IOException {
		String hostname = getHostHostName();
		logger.debug("AppServer::stop hostName = " + getHostName());

		if (isRunning()) {

			String output = SshUtils.SshExec(hostname, getTomcatCatalinaHome() + "/bin/shutdown.sh -force");
			logger.debug("Result of stopping app server is " + output);

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
		long portStep = 0L;
		if (!appInstance.getEdgeService().equals("appServer")) {
			if (appServerPortOffset == null) {
				logger.debug("setPortNumbers: appServerPortOffset is null");
				appServerPortOffset = 8000;
			}
			if (appServerPortStep == null) {
				logger.debug("setPortNumbers: appServerPortStep is null");
				appServerPortStep = 1;
			}
			portStep = (getId() - 1) * appServerPortStep;
			portOffset = appServerPortOffset + portStep;
		}

		if (httpInternalPort == null) {
			httpInternalPort = (int) (80 + portOffset);
		}

		if (httpsInternalPort == null) {
			httpsInternalPort = (int) (443 + portOffset);
		}

		if (shutdownInternalPort == null) {
			shutdownInternalPort = (int) (8005 + portStep);
		}

	}

	public void cleanLogs() {
		String hostname = getHostHostName();
		logger.debug("AppServer::cleanLogs hostName = " + getHostName());

		String output = SshUtils.SshExec(hostname, "rm -f " + getTomcatCatalinaBase() + "/logs/*");
		logger.debug("Result of cleaning logs is " + output);

		output = SshUtils.SshExec(hostname, "rm -f " + "/tmp/copycat*");
		logger.debug("Result of cleaning logs is " + output);

	}

	/*
	 * This method is used to warm up the app server before allowing it to 
	 * be integrated into a running configuration.  The main goal of the warmup 
	 * is to force the classloader and JIT compiler to process all of the main 
	 * paths in the application so that the CPU overhead does not affect the
	 * users when the app server is first integrated.
	 */
	public boolean warmUp(int startWarmerId) {
		List<Thread> warmupThreads = new ArrayList<Thread>();
		
		logger.debug("warmUp. Warming appServer " + this.getId() + 
				" starting from warmer " + startWarmerId);
		final int iterationsPerWarmer = (int) Math.ceil(WARMER_ITERATIONS / (WARMER_THREADS_PER_APPSERVER * 1.0));
		int lastWarmerId = startWarmerId + WARMER_THREADS_PER_APPSERVER - 1;
		for (int i = startWarmerId; i <= lastWarmerId; i++) {
			String username = "warmer" + i + "@auction.xyz";
			AppServerWarmer appServerWarmer = new AppServerWarmer(username, iterationsPerWarmer);
			Thread warmerThread = new Thread(appServerWarmer, "warmer" + i + "Thread");
			warmupThreads.add(warmerThread);
		}
		
		for (Thread warmupThread : warmupThreads) {
			warmupThread.start();
		}

		for (Thread warmupThread : warmupThreads) {
			try {
				warmupThread.join();
			} catch (InterruptedException e) {
				logger.warn("warmUp thread " + warmupThread.getName() + " was interrupted before completing");
			}
		}

		return true;
	}
	
	private String getJvmOpts(List<AppServer> appServers, List<WebServer> webServers, List<DbServer> dbServers, List<NosqlServer> nosqlServers,
			List<MsgServer> msgServers, List<CoordinationServer> coordinationServers) {
		logger.debug("AppServer::getJvmOpts hostName = " + getHostName());

		StringBuilder completeJvmOpts = new StringBuilder(getAppServerJvmOpts());
		if (getAppServerEnableJprofiler()) {
			completeJvmOpts.append(
					" -agentpath:/opt/jprofiler8/bin/linux-x64/libjprofilerti.so=port=8849,nowait -XX:MaxPermSize=400m");
		}
		if (getLogLevel() >= 3) {
			completeJvmOpts.append(
					" -XX:+PrintGCDetails -XX:+PrintGCTimeStamps -Xloggc:" + getTomcatCatalinaBase() + "/logs/gc.log ");
		}
		completeJvmOpts.append(" -DnodeNumber=" + getId() + " ");

		StringBuilder springProfilesActive = new StringBuilder();
		DbServer dbServer = dbServers.get(0);
		NosqlServer nosqlServer = nosqlServers.get(0);

		if (dbServer.getDbServerImpl().equals("mysql")) {
			springProfilesActive.append("mysql");
		} else {
			springProfilesActive.append("postgresql");
		}

		if ( appServerCacheImpl.equals("ehcache") ) {
			springProfilesActive.append(",ehcache");
		}
		else {
			springProfilesActive.append(",ignite");
		}

		if (getImageStoreType().equals("filesystem") || getImageStoreType().equals("filesystemApp")) {
			springProfilesActive.append(",imagesInFilesystem");
		} else if (getImageStoreType().equals("mongodb")) {
			springProfilesActive.append(",imagesInMongo");
		} else if (getImageStoreType().equals("memory")) {
			springProfilesActive.append(",imagesInMemory");
		}

		if (nosqlServer.getNosqlSharded()) {
			springProfilesActive.append(",shardedMongo");
		} else if (nosqlServer.getNosqlReplicated()) {
			springProfilesActive.append(",replicatedMongo");
		} else {
			springProfilesActive.append(",singleMongo");
		}

		long numMsgServers = msgServers.size();
		if (numMsgServers > 1) {
			springProfilesActive.append(",clusteredRabbit");
		} else {
			springProfilesActive.append(",singleRabbit");
		}

		if (getAppServerPerformanceMonitor()) {
			springProfilesActive.append(",performanceMonitor");
		}

		completeJvmOpts.append(" -Dspring.profiles.active=" + springProfilesActive.toString() + " ");

		long auctions = (long) Math.ceil(getUsers() / (getUsersPerAuctionScaleFactor() * 1.0));
		long numWebServers = webServers.size();
		long authTokenCacheSize = 2 * getUsers();
		long activeAuctionCacheSize = 2 * auctions;
		long itemsForAuctionCacheSize = 2 * auctions;
		long itemCacheSize = 20 * auctions;
		long auctionRepresentationCacheSize = 2 * auctions;
		long imageInfoCacheSize = 100 * auctions;

		long itemThumbnailImageCacheSize = getAppServerThumbnailImageCacheSizeMultiplier() * auctions;
		long itemPreviewImageCacheSize = getAppServerPreviewImageCacheSizeMultiplier() * auctions;
		long itemFullImageCacheSize = getAppServerFullImageCacheSizeMultiplier() * auctions;

		completeJvmOpts.append(" -DAUTHTOKENCACHESIZE=" + authTokenCacheSize + " -DACTIVEAUCTIONCACHESIZE="
				+ activeAuctionCacheSize + " ");
		completeJvmOpts.append(" -DAUCTIONREPRESENTATIONCACHESIZE=" + auctionRepresentationCacheSize + " ");
		completeJvmOpts.append(" -DIMAGEINFOCACHESIZE=" + imageInfoCacheSize + " -DITEMSFORAUCTIONCACHESIZE="
				+ itemsForAuctionCacheSize + " ");
		completeJvmOpts.append(" -DITEMCACHESIZE=" + itemCacheSize + " ");

		completeJvmOpts.append(" -DAUTHTOKENCACHEMODE=" + igniteAuthTokenCacheMode + " ");
		String copyOnRead = "false";
		if ( igniteCopyOnRead ) {
			copyOnRead = "true";
		}
		completeJvmOpts.append(" -DIGNITECOPYONREAD=" + copyOnRead + " ");

		completeJvmOpts.append(" -DIGNITEAPP1HOSTNAME=" + appServers.get(0).getHostHostName() + " ");

		// Set the defines for the Atomix nodes
		StringBuilder zookeeperConnectionString = new StringBuilder();
		for (CoordinationServer server : coordinationServers) {
			zookeeperConnectionString.append(server.getHostIpAddr() +  ":" + server.getClientPort() + "," );
		}
		zookeeperConnectionString.deleteCharAt(zookeeperConnectionString.length() - 1);
		completeJvmOpts.append(" -DZOOKEEPERCONNECTIONSTRING=" + zookeeperConnectionString.toString() + " ");

		if (numWebServers > 1) {

			// Don't need to cache images in app server if there is a web
			// server since the web server caches.
			itemThumbnailImageCacheSize = auctions;
			itemPreviewImageCacheSize = 1;
			itemFullImageCacheSize = 1;
		} else {
			if (itemPreviewImageCacheSize == 0) {
				itemPreviewImageCacheSize = 1;
			}

			if (itemFullImageCacheSize == 0) {
				itemFullImageCacheSize = 1;
			}
		}
		completeJvmOpts.append(" -DITEMTHUMBNAILIMAGECACHESIZE=" + itemThumbnailImageCacheSize + " ");
		completeJvmOpts.append(" -DITEMPREVIEWIMAGECACHESIZE=" + itemPreviewImageCacheSize + " ");
		completeJvmOpts.append(" -DITEMFULLIMAGECACHESIZE=" + itemFullImageCacheSize + " ");

		if (getRandomizeImages()) {
			completeJvmOpts.append(" -DRANDOMIZEIMAGES=true ");
		} else {
			completeJvmOpts.append(" -DRANDOMIZEIMAGES=false ");
		}

		long numCpus = 0;
		if ((getHostCpus() == null) || (getHostCpus() == 0)) {
			/*
			 * Need to find out how many cpus are on the host
			 */
			String hostHostName = getHostHostName();
			logger.debug("Getting the number of cpus for " + hostHostName);

			String cpuInfo = SshUtils.SshExec(hostHostName, "cat /proc/cpuinfo");
			Pattern p = Pattern.compile("processor");
			Matcher m = p.matcher(cpuInfo);
			while (m.find()) {
				numCpus++;
			}

		}
		if (!getUseDocker()) {
			numCpus = getHostCpus();
		} else if ((getDockerCpus() != null) && (getDockerCpus() > 0)) {
			numCpus = getDockerCpus();
		} else {
			numCpus = getHostCpus();
		} 

		// Turn on imageWriters in the application
		if (getUseImageWriterThreads()) {
			if (getImageWriterThreads() > 0) {
				// value was set, overriding the default
				completeJvmOpts.append(" -DIMAGEWRITERTHREADS=" + getImageWriterThreads() + " ");
			} else {

				int iwThreads = (int) Math.floor(numCpus / 2.0);
				if (iwThreads < 1) {
					iwThreads = 1;
				}
				completeJvmOpts.append(" -DIMAGEWRITERTHREADS=" + iwThreads + " ");

			}

			completeJvmOpts.append(" -DUSEIMAGEWRITERTHREADS=true ");
		} else {
			completeJvmOpts.append(" -DUSEIMAGEWRITERTHREADS=false ");
		}

		completeJvmOpts.append(" -DNUMCLIENTUPDATETHREADS=" + getNumClientUpdateThreads() + " ");
		completeJvmOpts.append(" -DNUMAUCTIONEERTHREADS=" + getNumAuctioneerThreads() + " ");

		long highBidConc = getHighBidQueueConcurrency();
		if (highBidConc == 0) {
			highBidConc = numCpus;
		}
		completeJvmOpts.append(" -DHIGHBIDQUEUECONCURRENCY=" + highBidConc + " ");

		long newBidConc = getNewBidQueueConcurrency();
		if (newBidConc == 0) {
			newBidConc = numCpus;
		}
		completeJvmOpts.append(" -DNEWBIDQUEUECONCURRENCY=" + newBidConc + " ");

		boolean clusteredRabbit = false;
		if (numMsgServers > 1) {
			clusteredRabbit = true;
		}

		if (clusteredRabbit) {

			completeJvmOpts.append(" -DRABBITMQ_HOSTS=");
			for (MsgServer msgServer : msgServers) {
				String msgHostname = getHostnameForUsedService(msgServer);
				int rabbitMQPort = msgServer.getRabbitmqPort();
				if (corunningDockerized(msgServer)) {
					rabbitMQPort = msgServer.getRabbitmqInternalPort();
				}
				completeJvmOpts.append(msgHostname + ":" + rabbitMQPort + ",");
			}

			// remove the last (extra) comma
			completeJvmOpts.deleteCharAt(completeJvmOpts.length() - 1);

			completeJvmOpts.append(" ");
		} else {
			MsgServer msgService = msgServers.get(0);
			String msgHostname = getHostnameForUsedService(msgService);
			int rabbitMQPort = msgService.getRabbitmqPort();
			if (corunningDockerized(msgService)) {
				rabbitMQPort = msgService.getRabbitmqInternalPort();
			}
			completeJvmOpts.append(" -DRABBITMQ_HOST=" + msgHostname + " -DRABBITMQ_PORT=" + rabbitMQPort + " ");
		}

		String nosqlHostname = getHostnameForUsedService(nosqlServer);
		int mongodbPort = nosqlServer.getMongodPort();
		if (corunningDockerized(nosqlServer)) {
			mongodbPort = nosqlServer.getMongodInternalPort();
		}

		/*
		 * Not dealing with sharded mongodb yet if
		 * (nosqlServer.getNosqlSharded()) {
		 * 
		 * // The mongos will be running on this app server $nosqlHostname =
		 * appServer.getHostHostName(); if ($service->mongosDocker) {
		 * $nosqlHostname = $service->mongosDocker; } $mongodbPort =
		 * $service->internalPortMap->{'mongos'}; }
		 */
		completeJvmOpts.append(" -DMONGODB_HOST=" + nosqlHostname + " -DMONGODB_PORT=" + mongodbPort + " ");

		if (nosqlServer.getNosqlReplicated()) {
			completeJvmOpts.append(" -DMONGODB_REPLICA_SET=");
			for (NosqlServer nosqlService : nosqlServers) {
				nosqlHostname = getHostnameForUsedService(nosqlService);
				mongodbPort = nosqlService.getMongodPort();
				if (corunningDockerized(nosqlService)) {
					mongodbPort = nosqlService.getMongodInternalPort();
				}
				completeJvmOpts.append(nosqlHostname + ":" + mongodbPort + ",");
			}
			// remove the last (extra) comma
			completeJvmOpts.deleteCharAt(completeJvmOpts.length() - 1);
		}

		String dbHostname = getHostnameForUsedService(dbServer);
		int dbPort = dbServer.getPostgresqlPort();
		completeJvmOpts.append(" -DDBHOSTNAME=" + dbHostname + " -DDBPORT=" + dbPort + " ");
		logger.debug("Returning jvmOpts : " + completeJvmOpts.toString());
		return completeJvmOpts.toString();
	}

	public String getAppServerJvmOpts() {
		return appServerJvmOpts;
	}

	public void setAppServerJvmOpts(String appServerJvmOpts) {
		this.appServerJvmOpts = appServerJvmOpts;
	}

	public Integer getAppServerThreads() {
		return appServerThreads;
	}

	public void setAppServerThreads(Integer appServerThreads) {
		this.appServerThreads = appServerThreads;
	}

	public Integer getAppServerJdbcConnections() {
		return appServerJdbcConnections;
	}

	public void setAppServerJdbcConnections(Integer appServerJdbcConnections) {
		this.appServerJdbcConnections = appServerJdbcConnections;
	}

	public Integer getAppServerPortOffset() {
		return appServerPortOffset;
	}

	public void setAppServerPortOffset(Integer appServerPortOffset) {
		this.appServerPortOffset = appServerPortOffset;
	}

	public Integer getAppServerPortStep() {
		return appServerPortStep;
	}

	public void setAppServerPortStep(Integer appServerPortStep) {
		this.appServerPortStep = appServerPortStep;
	}

	public String getAppServerImpl() {
		return appServerImpl;
	}

	public void setAppServerImpl(String appServerImpl) {
		this.appServerImpl = appServerImpl;
	}

	public Boolean getAppServerPerformanceMonitor() {
		return appServerPerformanceMonitor;
	}

	public void setAppServerPerformanceMonitor(Boolean appServerPerformanceMonitor) {
		this.appServerPerformanceMonitor = appServerPerformanceMonitor;
	}

	public Boolean getAppServerEnableJprofiler() {
		return appServerEnableJprofiler;
	}

	public void setAppServerEnableJprofiler(Boolean appServerEnableJprofiler) {
		this.appServerEnableJprofiler = appServerEnableJprofiler;
	}

	public Boolean getRandomizeImages() {
		return randomizeImages;
	}

	public void setRandomizeImages(Boolean randomizeImages) {
		this.randomizeImages = randomizeImages;
	}

	public Boolean getUseImageWriterThreads() {
		return useImageWriterThreads;
	}

	public void setUseImageWriterThreads(Boolean useImageWriterThreads) {
		this.useImageWriterThreads = useImageWriterThreads;
	}

	public Integer getImageWriterThreads() {
		return imageWriterThreads;
	}

	public void setImageWriterThreads(Integer imageWriterThreads) {
		this.imageWriterThreads = imageWriterThreads;
	}

	public Integer getNumClientUpdateThreads() {
		return numClientUpdateThreads;
	}

	public void setNumClientUpdateThreads(Integer numClientUpdateThreads) {
		this.numClientUpdateThreads = numClientUpdateThreads;
	}

	public Integer getNumAuctioneerThreads() {
		return numAuctioneerThreads;
	}

	public void setNumAuctioneerThreads(Integer numAuctioneerThreads) {
		this.numAuctioneerThreads = numAuctioneerThreads;
	}

	public Integer getAppServerThumbnailImageCacheSizeMultiplier() {
		return appServerThumbnailImageCacheSizeMultiplier;
	}

	public void setAppServerThumbnailImageCacheSizeMultiplier(Integer appServerThumbnailImageCacheSizeMultiplier) {
		this.appServerThumbnailImageCacheSizeMultiplier = appServerThumbnailImageCacheSizeMultiplier;
	}

	public Integer getAppServerPreviewImageCacheSizeMultiplier() {
		return appServerPreviewImageCacheSizeMultiplier;
	}

	public void setAppServerPreviewImageCacheSizeMultiplier(Integer appServerPreviewImageCacheSizeMultiplier) {
		this.appServerPreviewImageCacheSizeMultiplier = appServerPreviewImageCacheSizeMultiplier;
	}

	public Integer getAppServerFullImageCacheSizeMultiplier() {
		return appServerFullImageCacheSizeMultiplier;
	}

	public void setAppServerFullImageCacheSizeMultiplier(Integer appServerFullImageCacheSizeMultiplier) {
		this.appServerFullImageCacheSizeMultiplier = appServerFullImageCacheSizeMultiplier;
	}

	public String getTomcatCatalinaHome() {
		return tomcatCatalinaHome;
	}

	public void setTomcatCatalinaHome(String tomcatCatalinaHome) {
		this.tomcatCatalinaHome = tomcatCatalinaHome;
	}

	public String getTomcatCatalinaBase() {
		return tomcatCatalinaBase;
	}

	public void setTomcatCatalinaBase(String tomcatCatalinaBase) {
		this.tomcatCatalinaBase = tomcatCatalinaBase;
	}

	public Integer getUsersPerAuctionScaleFactor() {
		return usersPerAuctionScaleFactor;
	}

	public void setUsersPerAuctionScaleFactor(Integer usersPerAuctionScaleFactor) {
		this.usersPerAuctionScaleFactor = usersPerAuctionScaleFactor;
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
	
	public Integer getShutdownPort() {
		return shutdownPort;
	}

	public void setShutdownPort(Integer shutdownPort) {
		this.shutdownPort = shutdownPort;
	}

	public Integer getShutdownInternalPort() {
		return shutdownInternalPort;
	}

	public void setShutdownInternalPort(Integer shutdownInternalPort) {
		this.shutdownInternalPort = shutdownInternalPort;
	}

	public Integer getNewBidQueueConcurrency() {
		return newBidQueueConcurrency;
	}

	public void setNewBidQueueConcurrency(Integer newBidQueueConcurrency) {
		this.newBidQueueConcurrency = newBidQueueConcurrency;
	}

	public Integer getHighBidQueueConcurrency() {
		return highBidQueueConcurrency;
	}

	public void setHighBidQueueConcurrency(Integer highBidQueueConcurrency) {
		this.highBidQueueConcurrency = highBidQueueConcurrency;
	}

	public String getAppServerCacheImpl() {
		return appServerCacheImpl;
	}

	public void setAppServerCacheImpl(String appServerCacheImpl) {
		this.appServerCacheImpl = appServerCacheImpl;
	}

	public String getIgniteAuthTokenCacheMode() {
		return igniteAuthTokenCacheMode;
	}

	public void setIgniteAuthTokenCacheMode(String igniteAuthTokenCacheMode) {
		this.igniteAuthTokenCacheMode = igniteAuthTokenCacheMode;
	}


	public Boolean getIgniteCopyOnRead() {
		return igniteCopyOnRead;
	}

	public void setIgniteCopyOnRead(Boolean igniteCopyOnRead) {
		this.igniteCopyOnRead = igniteCopyOnRead;
	}

	public Boolean getPrewarmAppServers() {
		return prewarmAppServers;
	}

	public void setPrewarmAppServers(Boolean prewarmAppServers) {
		this.prewarmAppServers = prewarmAppServers;
	}

	public AppServer mergeDefaults(final AppServerDefaults defaults) {

		AppServer mergedAppServer = (AppServer) super.mergeDefaults(this, defaults);

		mergedAppServer
				.setAppServerJvmOpts(appServerJvmOpts != null ? appServerJvmOpts : defaults.getAppServerJvmOpts());
		mergedAppServer
				.setAppServerThreads(appServerThreads != null ? appServerThreads : defaults.getAppServerThreads());
		mergedAppServer.setAppServerJdbcConnections(
				appServerJdbcConnections != null ? appServerJdbcConnections : defaults.getAppServerJdbcConnections());

		logger.debug("mergeDefaults setting appServerPortOffset default value = " + defaults.getAppServerPortOffset());
		mergedAppServer.setAppServerPortOffset(
				appServerPortOffset != null ? appServerPortOffset : defaults.getAppServerPortOffset());

		logger.debug("mergeDefaults setting appServerPortStep default value = " + defaults.getAppServerPortStep());
		mergedAppServer
				.setAppServerPortStep(appServerPortStep != null ? appServerPortStep : defaults.getAppServerPortStep());

		mergedAppServer.setAppServerImpl(appServerImpl != null ? appServerImpl : defaults.getAppServerImpl());
		mergedAppServer.setAppServerCacheImpl(appServerCacheImpl != null ? appServerCacheImpl : defaults.getAppServerCacheImpl());
		mergedAppServer.setIgniteAuthTokenCacheMode(igniteAuthTokenCacheMode != null ? igniteAuthTokenCacheMode : defaults.getIgniteAuthTokenCacheMode());
		mergedAppServer.setIgniteCopyOnRead(igniteCopyOnRead != null ? igniteCopyOnRead : defaults.getIgniteCopyOnRead());

		mergedAppServer.setAppServerPerformanceMonitor(appServerPerformanceMonitor != null ? appServerPerformanceMonitor
				: defaults.getAppServerPerformanceMonitor());
		mergedAppServer.setAppServerEnableJprofiler(
				appServerEnableJprofiler != null ? appServerEnableJprofiler : defaults.getAppServerEnableJprofiler());
		mergedAppServer.setRandomizeImages(randomizeImages != null ? randomizeImages : defaults.getRandomizeImages());
		mergedAppServer.setUseImageWriterThreads(
				useImageWriterThreads != null ? useImageWriterThreads : defaults.getUseImageWriterThreads());
		mergedAppServer.setImageWriterThreads(
				imageWriterThreads != null ? imageWriterThreads : defaults.getImageWriterThreads());
		mergedAppServer.setNumClientUpdateThreads(
				numClientUpdateThreads != null ? numClientUpdateThreads : defaults.getNumClientUpdateThreads());
		mergedAppServer.setNumAuctioneerThreads(
				numAuctioneerThreads != null ? numAuctioneerThreads : defaults.getNumAuctioneerThreads());
		mergedAppServer.setHighBidQueueConcurrency(
				highBidQueueConcurrency != null ? highBidQueueConcurrency : defaults.getHighBidQueueConcurrency());
		mergedAppServer.setNewBidQueueConcurrency(
				newBidQueueConcurrency != null ? newBidQueueConcurrency : defaults.getNewBidQueueConcurrency());
		mergedAppServer.setAppServerThumbnailImageCacheSizeMultiplier(
				appServerThumbnailImageCacheSizeMultiplier != null ? appServerThumbnailImageCacheSizeMultiplier
						: defaults.getAppServerThumbnailImageCacheSizeMultiplier());
		mergedAppServer.setAppServerPreviewImageCacheSizeMultiplier(appServerPreviewImageCacheSizeMultiplier != null
				? appServerPreviewImageCacheSizeMultiplier : defaults.getAppServerPreviewImageCacheSizeMultiplier());
		mergedAppServer.setAppServerFullImageCacheSizeMultiplier(appServerFullImageCacheSizeMultiplier != null
				? appServerFullImageCacheSizeMultiplier : defaults.getAppServerFullImageCacheSizeMultiplier());
		mergedAppServer.setTomcatCatalinaHome(
				tomcatCatalinaHome != null ? tomcatCatalinaHome : defaults.getTomcatCatalinaHome());
		mergedAppServer.setTomcatCatalinaBase(
				tomcatCatalinaBase != null ? tomcatCatalinaBase : defaults.getTomcatCatalinaBase());
		mergedAppServer
				.setImageStoreType(getImageStoreType() != null ? getImageStoreType() : defaults.getImageStoreType());
		mergedAppServer.setUsersPerAuctionScaleFactor(usersPerAuctionScaleFactor != null ? usersPerAuctionScaleFactor
				: defaults.getUsersPerAuctionScaleFactor());
		mergedAppServer.setPrewarmAppServers(prewarmAppServers != null ? prewarmAppServers
				: defaults.getPrewarmAppServers());

		return mergedAppServer;
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof AppServer))
			return false;
		if (obj == this)
			return true;

		AppServer rhs = (AppServer) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}

	@Override
	public String toString() {
		return "AppServer [appServerJvmOpts=" + appServerJvmOpts + ", appServerThreads=" + appServerThreads
				+ ", appServerJdbcConnections=" + appServerJdbcConnections + ", appServerPortOffset="
				+ appServerPortOffset + ", appServerPortStep=" + appServerPortStep + ", appServerImpl=" + appServerImpl
				+ ", appServerCacheImpl=" + appServerCacheImpl + ", igniteAuthTokenCacheMode=" + igniteAuthTokenCacheMode 
				+", igniteCopyOnRead=" + getIgniteCopyOnRead()
				+ ", appServerPerformanceMonitor=" + appServerPerformanceMonitor + ", appServerEnableJprofiler="
				+ appServerEnableJprofiler + ", randomizeImages=" + randomizeImages + ", useImageWriterThreads="
				+ useImageWriterThreads + ", imageWriterThreads=" + imageWriterThreads + ", numClientUpdateThreads="
				+ numClientUpdateThreads + ", numAuctioneerThreads=" + numAuctioneerThreads 
				+ ", newBidQueueConcurrency=" + newBidQueueConcurrency 
				+ ", highBidQueueConcurrency=" + highBidQueueConcurrency 
				+ ", appServerThumbnailImageCacheSizeMultiplier="
				+ appServerThumbnailImageCacheSizeMultiplier + ", appServerPreviewImageCacheSizeMultiplier="
				+ appServerPreviewImageCacheSizeMultiplier + ", appServerFullImageCacheSizeMultiplier="
				+ appServerFullImageCacheSizeMultiplier + ", tomcatCatalinaHome=" + tomcatCatalinaHome
				+ ", tomcatCatalinaBase=" + tomcatCatalinaBase + ", httpPort=" + httpPort + ", httpsPort=" + httpsPort
				+ ", httpInternalPort=" + httpInternalPort + ", httpsInternalPort=" + httpsInternalPort
				+ ", imageStoreType=" + getImageStoreType() + ", usersPerAuctionScaleFactor="
				+ usersPerAuctionScaleFactor + ", getId()=" + getId() + ", getHostName()=" + getHostName()
				+ ", getVmName()=" + getVmName() + ", getDockerName()=" + getDockerName() + ", getDockerHostPort()="
				+ getDockerHostPort() + ", getId()=" + getId() + ", getUseDocker()=" + getUseDocker()
				+ ", getDockerMemorySwap()=" + getDockerMemorySwap() + ", getDockerMemory()=" + getDockerMemory()
				+ ", getDockerCpuSetCpus()=" + getDockerCpuSetCpus() + ", getDockerNet()=" + getDockerNet()
				+ ", getUsers()=" + getUsers() + ", getFrontendConnectionMultiplier()="
				+ getFrontendConnectionMultiplier() + ", getSsl()=" + getSsl() + ", getLogLevel()=" + getLogLevel()
				+ ", getHostHostName()=" + getHostHostName() + ", getHostIpAddr()=" + getHostIpAddr()
				+ ", getHostCpus()=" + getHostCpus() + ", getHostMemKb()=" + getHostMemKb() + ", getDockerCpuShares()="
				+ getDockerCpuShares() + ", getHostIsBonneville()=" + getHostIsBonneville() + "]";
	}

	private class AppServerWarmer implements Runnable {
		
		private final int interations;
		private final String username;
		private final String password = "warmer";
		
		protected AppServerWarmer(String username, int iterations) {
			this.username = username;
			
			this.interations = iterations;
		}
		
		@Override
		public void run() {
			RestTemplate restTemplate = new RestTemplate();
			
			String baseUrl = "http://" + getHostHostName() + ":" + getHttpPort() + "/auction";
			String loginUrl = baseUrl + "/login";
			String logoutUrl = baseUrl + "/logout";
			String getActiveAuctionsUrl = baseUrl + "/live/auction?pageSize=5&page=0";
			String getAuctionUrl = baseUrl + "/auction/1";
			String getItemsForAuctionUrl = baseUrl + "/item/auction/1";		
			
			HttpHeaders requestHeaders = new HttpHeaders();
			requestHeaders.setContentType(MediaType.APPLICATION_JSON);
			
			AuthenticationRequestRepresentation authenticationRequest = new AuthenticationRequestRepresentation();
			authenticationRequest.setUsername(username);
			authenticationRequest.setPassword(password);
			
			HttpEntity<AuthenticationRequestRepresentation> authenticationRequestEntity 
						= new HttpEntity<AuthenticationRequestRepresentation>(authenticationRequest, requestHeaders);

					
			for (int i = 0; i <= interations; i++) {
				ResponseEntity<LoginResponse> loginResponseEntity 
						= restTemplate.exchange(loginUrl, HttpMethod.POST, authenticationRequestEntity, LoginResponse.class);
				LoginResponse loginResponse = loginResponseEntity.getBody();
				String authtoken = loginResponse.getAuthToken();
				logger.trace("Executed login for " + authenticationRequest + ". authtoken = " + authtoken);
				HttpHeaders authTokenHeaders = new HttpHeaders();
				authTokenHeaders.add("API_TOKEN", authtoken);
				
				HttpEntity<String> requestEntity = new HttpEntity<String>(null, authTokenHeaders);

				try {
					String getUserProfileUrl = baseUrl + "/user/" + loginResponse.getId();
					logger.trace("Executing getUserProfile with url " + getUserProfileUrl);	
					ResponseEntity<UserRepresentation> userRE =
							restTemplate.exchange(getUserProfileUrl, HttpMethod.GET, requestEntity, 
									UserRepresentation.class);
					logger.trace("Executed getUserProfile");	
					
					UserRepresentation user = userRE.getBody();
					user.setFirstname(UUID.randomUUID().toString());
					user.setPassword(password);
					user.setRepeatPassword(password);
					HttpEntity<UserRepresentation> userEntity = new HttpEntity<UserRepresentation>(user, authTokenHeaders);

					logger.trace("Executing updateUserProfile with url " + getUserProfileUrl);	
					userRE = restTemplate.exchange(getUserProfileUrl, HttpMethod.PUT, userEntity, 
									UserRepresentation.class);
					logger.trace("Executed updateUserProfile");			
					
					logger.trace("Executing getActiveAuctions with url " + getActiveAuctionsUrl);	
					ResponseEntity<CollectionRepresentation<AuctionRepresentation>> auctionCollectionRE =
							restTemplate.exchange(getActiveAuctionsUrl, HttpMethod.GET, requestEntity, 
									new ParameterizedTypeReference<CollectionRepresentation<AuctionRepresentation>>() {});
					logger.trace("Executed getActiveAuctions");			
					CollectionRepresentation<AuctionRepresentation> auctionCollection = auctionCollectionRE.getBody();
					
					logger.trace("Executing getAuction with url " + getAuctionUrl);	
					restTemplate.exchange(getAuctionUrl, HttpMethod.GET, requestEntity, AuctionRepresentation.class);
					logger.trace("Executed getAuction");			
				
					logger.trace("Executing getItemsForAuction with url " + getItemsForAuctionUrl);	
					ResponseEntity<CollectionRepresentation<ItemRepresentation>> itemCollectionRE =
							restTemplate.exchange(getItemsForAuctionUrl, HttpMethod.GET, requestEntity,
									new ParameterizedTypeReference<CollectionRepresentation<ItemRepresentation>>() {});
					logger.trace("Executed getItemsForAuction");			

					CollectionRepresentation<ItemRepresentation> itemCollection = itemCollectionRE.getBody();
					if (itemCollection.getResults().size() > 0) {
						ItemRepresentation item = itemCollection.getResults().get(0);
						List<Map<Representation.RestAction,String>> links = item.getLinks().get("ItemImage");
						if ((links != null) && (links.size() > 0)) {
							String itemImageUrl = baseUrl + "/" + links.get(0).get(RestAction.READ);
							itemImageUrl += "?size=THUMBNAIL";
							logger.trace("Executing getImageForItem with url " + itemImageUrl);	
							restTemplate.exchange(itemImageUrl, HttpMethod.GET, requestEntity, String.class);
							logger.trace("Executed getImageForItem ");			

						}

						String addItemUrl = baseUrl + "/item";
						item.setId(null);
						item.setBidCount(0);
						HttpEntity<ItemRepresentation> itemEntity = new HttpEntity<ItemRepresentation>(item, authTokenHeaders);
						logger.trace("Executing addItem with url " + addItemUrl);	
						restTemplate.exchange(addItemUrl, HttpMethod.POST, itemEntity, ItemRepresentation.class);
						logger.trace("Executed addItem");	
						
					}
				
					if (auctionCollection.getResults().size() > 0) {
						AuctionRepresentation auction = auctionCollection.getResults().get(0);
						
						AttendanceRecordRepresentation arr = new AttendanceRecordRepresentation();
						arr.setAuctionId(auction.getId());
						arr.setUserId(user.getId());
						HttpEntity<AttendanceRecordRepresentation> arrEntity = new HttpEntity<AttendanceRecordRepresentation>(arr, authTokenHeaders);
						String joinAuctionUrl = baseUrl + "/live/auction";
						logger.trace("Executing joinAuction with url " + getAuctionUrl);	
						ResponseEntity<AttendanceRecordRepresentation>  arrRE= restTemplate.exchange(joinAuctionUrl, HttpMethod.POST, arrEntity, 
										AttendanceRecordRepresentation.class);
						logger.trace("Executed joinAuction");	
						
						String getCurrentItemUrl = baseUrl + "/item/current/auction/" + auction.getId();
						logger.trace("Executing getCurrentItem with url " + getCurrentItemUrl);	
						ResponseEntity<ItemRepresentation> itemRE 
							= restTemplate.exchange(getCurrentItemUrl, HttpMethod.GET, requestEntity, ItemRepresentation.class);
						ItemRepresentation curItem = itemRE.getBody();
						logger.trace("Executed getCurrentItem");
						
						String getItemUrl = baseUrl + "/item/" + curItem.getId();
						logger.trace("Executing getItem with url " + getCurrentItemUrl);	
						restTemplate.exchange(getItemUrl, HttpMethod.GET, requestEntity, ItemRepresentation.class);
						logger.trace("Executed getItem");
						
						String getCurrentBidUrl = baseUrl + "/bid/auction/" + auction.getId() + "/item/" + curItem.getId() + "/count/0";
						logger.trace("Executing getNextBid with url " + getCurrentBidUrl);	
						ResponseEntity<BidRepresentation> bidRE 
							= restTemplate.exchange(getCurrentBidUrl, HttpMethod.GET, requestEntity, BidRepresentation.class);
						logger.trace("Executed getNextBid");
						
						String postBidUrl = baseUrl + "/bid";
						BidRepresentation bidRepresentation = bidRE.getBody();
						bidRepresentation.setAmount((float) 0.0);
						bidRepresentation.setUserId(user.getId());
						bidRepresentation.setId(null);
						HttpEntity<BidRepresentation> bidEntity = new HttpEntity<BidRepresentation>(bidRepresentation, authTokenHeaders);
						logger.trace("Executing postBid with url " + postBidUrl);	
						bidRE= restTemplate.exchange(postBidUrl, HttpMethod.POST, bidEntity,BidRepresentation.class);
						logger.trace("Executed postBid");	

						String leaveAuctionUrl = baseUrl + "/live/auction/"  + auction.getId();
						logger.trace("Executing leaveAuction with url " + leaveAuctionUrl);	
						arrRE = restTemplate.exchange(leaveAuctionUrl, HttpMethod.DELETE, requestEntity, 
								AttendanceRecordRepresentation.class);
						logger.trace("Executed leaveAuction");

					}

					String getPurchaseHistoryUrl = baseUrl + "/item/user/" + user.getId() + "/purchased?page=0&pageSize=5";
					logger.trace("Executing getPurchaseHistory with url " + getPurchaseHistoryUrl);	
					itemCollectionRE =
							restTemplate.exchange(getPurchaseHistoryUrl, HttpMethod.GET, requestEntity,
									new ParameterizedTypeReference<CollectionRepresentation<ItemRepresentation>>() {});
					logger.trace("Executed getPurchaseHistory");

					String getAttendanceHistoryUrl = baseUrl + "/attendance/user/" + user.getId();
					logger.trace("Executing getAttendanceHistory with url " + getAttendanceHistoryUrl);	
					restTemplate.exchange(getAttendanceHistoryUrl, HttpMethod.GET, requestEntity,
								new ParameterizedTypeReference<CollectionRepresentation<AttendanceRecordRepresentation>>() {});
					logger.trace("Executed getAttendanceHistory");

					String getbidHistoryUrl = baseUrl + "/bid/user/" + user.getId() + "?page=0&pageSize=5";
					logger.trace("Executing getBidHistory with url " + getbidHistoryUrl);	
					restTemplate.exchange(getbidHistoryUrl, HttpMethod.GET, requestEntity,
								new ParameterizedTypeReference<CollectionRepresentation<BidRepresentation>>() {});
					logger.trace("Executed getBidHistory");
					
					logger.trace("Executing logout with url " + logoutUrl);	
					restTemplate.exchange(logoutUrl, HttpMethod.GET, requestEntity, String.class);
					logger.trace("Executed logout");
				} catch (RestClientException e) {
					logger.warn("Got RestClientException: " +  e.getMessage());
				}
			}
			
			
		}
		
	}
	
}

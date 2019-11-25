/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.workloadDriver.common.http;

/**
 * @author Hal
 *
 */
import java.io.IOException;
import java.io.UnsupportedEncodingException;
import java.net.InetSocketAddress;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;
import com.vmware.weathervane.workloadDriver.common.core.User;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.Channel;
import io.netty.channel.pool.AbstractChannelPoolMap;
import io.netty.channel.pool.ChannelHealthChecker;
import io.netty.channel.pool.ChannelPoolMap;
import io.netty.channel.pool.FixedChannelPool;
import io.netty.channel.pool.FixedChannelPool.AcquireTimeoutAction;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpResponse;
import io.netty.handler.codec.http.cookie.ClientCookieDecoder;
import io.netty.handler.codec.http.cookie.ClientCookieEncoder;
import io.netty.handler.codec.http.cookie.Cookie;
import io.netty.handler.ssl.ReferenceCountedOpenSslContext;
import io.netty.handler.ssl.SslContextBuilder;
import io.netty.handler.ssl.SslProvider;
import io.netty.handler.ssl.util.InsecureTrustManagerFactory;
import io.netty.util.concurrent.Future;

/**
 * The HttpTransport class is used to issue various HTTP requests.
 */
public class HttpTransport {
	
	private static final Logger logger = LoggerFactory.getLogger(HttpTransport.class);
	private static final Logger channelStatsCollectorLogger = LoggerFactory.getLogger(ChannelStatsCollector.class);

	private static final Integer _maxConnPerUser = Integer.getInteger("MAXCONNPERUSER", 4);

	static private ReferenceCountedOpenSslContext _sslContext = null;
	static {
		try {
			_sslContext = (ReferenceCountedOpenSslContext) SslContextBuilder.forClient()
								.sslProvider(SslProvider.OPENSSL_REFCNT)
								.trustManager(InsecureTrustManagerFactory.INSTANCE).build();
		} catch (Exception e) {
			logger.error("Caught exception when creating sslContext: " + e.getMessage());
		}

	}
	
	/*
	 * The user who owns this AsyncHttpTransport
	 */
	private User _user;
	
	private List<Cookie> cookies = new ArrayList<Cookie>();

	private ChannelPoolMap<ChannelPoolKey, FixedChannelPool> _poolMap;
	
	private Set<FixedChannelPool> _pools = new HashSet<FixedChannelPool>();
 	
	private ChannelStatsCollector _channelStatsCollector = ChannelStatsCollector.getInstance();
	
	/**
	 * Creates an HttpTransport. This entails creating and initializing the HTTP
	 * client used to execute requests.
	 * @throws Exception 
	 */
	public HttpTransport(User user) {
		logger.debug("HttpTransport constructor for user with userId = " + user.getId());
		_user = user;
		
		_poolMap = new AbstractChannelPoolMap<ChannelPoolKey, FixedChannelPool>() {
			@Override
			protected FixedChannelPool newPool(ChannelPoolKey key) {
				logger.debug("newPool: Creating new FixedChannelPool for userId = " + _user.getId() + ".  remoteAddress = " + key.getAddress()
								+ ", useSSl = " + key.isUseSsl());
				Bootstrap bootstrap = ClientBootstrapFactory.getInstance();
				FixedChannelPool pool = new FixedChannelPool(bootstrap.remoteAddress(key.getAddress()), 
						new HttpClientChannelPoolHandler(_sslContext, key.isUseSsl(), _user.getId()), 
						ChannelHealthChecker.ACTIVE, AcquireTimeoutAction.FAIL,
						5000, _maxConnPerUser, 20, true);
				return pool;
			}
		};
	}

	public void close( ) {
		logger.debug("close for userId = " + _user.getId());
		for (FixedChannelPool pool : _pools) {
			pool.close();
		}
		_pools.clear();
		_pools = null;
		_user = null;
	}
	
	
	protected void setCookies(HttpRequest httpRequest) {
		
		if ((cookies != null) && !cookies.isEmpty()) {
			httpRequest.headers().set(HttpHeaderNames.COOKIE, ClientCookieEncoder.STRICT.encode(cookies));
		}
	}
	
	protected void extractCookies(HttpResponse httpResponse) {
		List<String> setCookieStrings = httpResponse.headers().getAll(HttpHeaderNames.SET_COOKIE);		
		if ((setCookieStrings != null) && (setCookieStrings.size() > 0)) {
			for (String cookieValue: setCookieStrings) {
				cookies.add(ClientCookieDecoder.STRICT.decode(cookieValue));
			}
		}
	}

	/**
	 * Executes the given URL as an HTTP GET request. Adds the provided headers
	 * to the request before executing it.
	 * 
	 * @param url
	 *            The URL of the request.
	 * @param headers
	 *            The headers to add to the request.
	 */
	public void executeGet(SimpleUri uri, Map<String, String> urlBindVariables,
			Map<String, String> headers, HttpRequestCompleteCallback callback, boolean dropResponse) {
		logger.debug("executeGet with uri " + uri.getUriString());

		 this.executeRequest(HttpMethod.GET, uri, urlBindVariables, headers, null, null, null, dropResponse, callback);
	}
	
	
	public void executeDelete(SimpleUri uri, Map<String, String> urlBindVariables, Map<String, String> headers,
			HttpRequestCompleteCallback callback, boolean dropResponse) {

		 this.executeRequest(HttpMethod.DELETE, uri, urlBindVariables, headers, null, null, null, dropResponse, callback);

	}
	
	/**
	 * Executes the given URL and postBody as an HTTP POST request. Adds the
	 * provided headers to the request before executing it.
	 * 
	 * @param url
	 *            The URL of the request.
	 * @param formString
	 *            The contents of the POST body.
	 * @param headers
	 *            The headers to add to the request.
	 */
	public void executePostForm(SimpleUri uri, Map<String, String> urlBindVariables, Map<String, String> formParameters,
			Map<String, String> headers, HttpRequestCompleteCallback callback, boolean dropResponse) {

		if (headers == null) {
			headers = new HashMap<String, String>();
		}

		this.executeRequest(HttpMethod.POST, uri, urlBindVariables, headers, null, formParameters, null, dropResponse, callback);

	}

	/**
	 * Executes an HTTP POST request.
	 * 
	 * @param httpPost
	 *            The HTTP POST request to execute.
	 * @param headers
	 *            The headers to add to the request.
	 * 
	 * @throws IOException
	 */
	public void executePostFiles(SimpleUri uri, Map<String, String> urlBindVariables, List<FileUploadInfo> fileUploads,
			Map<String, String> headers, HttpRequestCompleteCallback callback, boolean dropResponse) throws IOException {

		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		
		this.executeRequest(HttpMethod.POST, uri, urlBindVariables, headers, null, null, fileUploads, 
																		dropResponse, callback);

	}

	/**
	 * Executes an HTTP POST request.
	 * 
	 * @param httpPost
	 *            The HTTP POST request to execute.
	 * @param headers
	 *            The headers to add to the request.
	 * @throws UnsupportedEncodingException 
	 * 
	 * @throws IOException
	 */
	public void executePost(SimpleUri uri, Map<String, String> urlBindVariables, String body, Map<String, String> headers,
			HttpRequestCompleteCallback callback, boolean dropResponse)  {

		// Set the headers as necessary.
		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		if (!headers.containsKey("Content-Type")) {
			headers.put("Content-Type", "text/plain");
		}

		this.executeRequest(HttpMethod.POST, uri, urlBindVariables, headers, body, null, null, dropResponse, callback);

	}

	/**
	 * Executes an HTTP Put request.
	 * 
	 * @param httpPut
	 *            The HTTP Put request to execute.
	 * @param headers
	 *            The headers to add to the request.
	 * @throws UnsupportedEncodingException 
	 * 
	 * @throws IOException
	 */
	public void executePut(SimpleUri uri, Map<String, String> urlBindVariables, String body,	Map<String, String> headers, 
			HttpRequestCompleteCallback callback, boolean dropResponse) throws UnsupportedEncodingException {
		// Set the headers as necessary.
		if (headers == null) {
			headers = new HashMap<String, String>();
		}
		if (!headers.containsKey("Content-Type")) {
			headers.put("Content-Type", "text/plain");
		}

		this.executeRequest(HttpMethod.PUT, uri, urlBindVariables, headers, body, null, null, dropResponse, callback);

	}

	/**
	 * Executes an HTTP Request.
	 * This is the method that eventually gets called to submit all requests
	 */
	protected void executeRequest(HttpMethod httpMethod, SimpleUri simpleUri, 
			Map<String, String> urlBindVariables,
			Map<String, String> headers, 
			String content,
			Map<String, String> formParameters,
			List<FileUploadInfo> fileUploads,
			boolean dropResponse, HttpRequestCompleteCallback callback) {
		
		logger.debug("executeRequest: Allocating channel for request " + httpMethod 
				+ ":" + simpleUri.getUriString() + ", remoteHostname = " + simpleUri.getHostname()
				+ ", remotePort = " + simpleUri.getPort()
				+ ", behaviorId = " + callback.getBehaviorId() + ", userId = " + _user.getId());

		InetSocketAddress address = new InetSocketAddress(simpleUri.getHostname(), simpleUri.getPort());
		boolean useSsl = (simpleUri.getScheme().equalsIgnoreCase("https")) ? true : false;
		ChannelPoolKey poolKey = new ChannelPoolKey(address, useSsl);
		
		final FixedChannelPool pool = _poolMap.get(poolKey);
		_pools.add(pool);
		Future<Channel> f = pool.acquire();

		long now = 0;
		if (channelStatsCollectorLogger.isDebugEnabled()) {
			now = System.currentTimeMillis();
			_channelStatsCollector.incrementNumChannelsRequested();
		}
		
		f.addListener(new ChannelAllocatedFutureListener(this, httpMethod, simpleUri, 
								urlBindVariables, headers, content, formParameters, fileUploads, dropResponse, 
								callback, pool, now, _user.getId()));

	}
	
	private class ChannelPoolKey {
		private InetSocketAddress _address;
		private boolean _useSsl;
		
		public ChannelPoolKey(InetSocketAddress address, boolean useSsl) {
			super();
			this._address = address;
			this._useSsl = useSsl;
		}
		
		public InetSocketAddress getAddress() {
			return _address;
		}

		public boolean isUseSsl() {
			return _useSsl;
		}
		
		@Override
		public int hashCode() {
			logger.debug("ChannelPoolKey::hashCode");

			int addrHashCode = _address.hashCode();
			int useSslHashCode = _useSsl ? 0 : 1;
			int result = addrHashCode + useSslHashCode;
			logger.debug("ChannelPoolKey::hashCode returning " + result);

			return result;
			
		}

		@Override
		public	boolean equals(Object thatObject) {
			logger.debug("ChannelPoolKey::equals");
			if (!(thatObject instanceof ChannelPoolKey)) {
				return false;
			}
			ChannelPoolKey that = (ChannelPoolKey) thatObject;
			boolean retVal =  this._address.equals(that.getAddress()) && (_useSsl == that.isUseSsl());
			logger.debug("ChannelPoolKey::equals.  " 
					+ "this.address = " + _address
					+ ", this.useSsl = " + _useSsl
					+ ", that.address = " + that._address
					+ ", that.useSsl = " + that._useSsl
					+ ", userId = " + _user.getId()
					+ ", returning " + retVal
					);
			return retVal;
			
		}
		
	}
	
}

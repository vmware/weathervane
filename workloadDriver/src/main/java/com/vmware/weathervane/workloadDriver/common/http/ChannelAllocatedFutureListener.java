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
package com.vmware.weathervane.workloadDriver.common.http;

import java.util.List;
import java.util.Map;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.workloadDriver.common.core.SimpleUri;

import io.netty.buffer.ByteBuf;
import io.netty.channel.Channel;
import io.netty.channel.pool.FixedChannelPool;
import io.netty.handler.codec.http.DefaultFullHttpRequest;
import io.netty.handler.codec.http.HttpHeaderNames;
import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.handler.codec.http.HttpObjectAggregator;
import io.netty.handler.codec.http.HttpRequest;
import io.netty.handler.codec.http.HttpVersion;
import io.netty.handler.codec.http.multipart.DefaultHttpDataFactory;
import io.netty.handler.codec.http.multipart.HttpDataFactory;
import io.netty.handler.codec.http.multipart.HttpPostRequestEncoder;
import io.netty.handler.logging.LoggingHandler;
import io.netty.util.AttributeKey;
import io.netty.util.concurrent.Future;
import io.netty.util.concurrent.FutureListener;

public class ChannelAllocatedFutureListener implements FutureListener<Channel> {
	private static final Logger logger = LoggerFactory.getLogger(ChannelAllocatedFutureListener.class);
	private static final Logger channelStatsCollectorLogger = LoggerFactory.getLogger(ChannelStatsCollector.class);

	private static HttpDataFactory _factory = new DefaultHttpDataFactory(false);
	
	private HttpTransport _httpTransport;
	private HttpMethod _httpMethod;
	private SimpleUri _simpleUri;
	private Map<String, String> _urlBindVariables;
	private Map<String, String> _headers;
	private String _content;
	private Map<String, String> _formParameters;
	private List<FileUploadInfo> _fileUploads;
	private boolean _dropResponse;
	private HttpRequestCompleteCallback _callback;
	private FixedChannelPool _pool;
	private long _allocateStartTimeMillis;
	private long _userId;
	
	public static final AttributeKey<Boolean> WASCREATEDKEY =  AttributeKey.valueOf("wasCreated");
	private ChannelStatsCollector _channelStatsCollector = ChannelStatsCollector.getInstance();

	public ChannelAllocatedFutureListener(HttpTransport _httpTransport, 
			HttpMethod httpMethod,
			SimpleUri simpleUri, Map<String, String> urlBindVariables,
			Map<String, String> headers, String content,
			Map<String, String> formParameters,
			List<FileUploadInfo> fileUploads,
			boolean _dropResponse, HttpRequestCompleteCallback _callback,
			FixedChannelPool _pool, long allocateStartTimeMillis, long userId) {
		super();
		this._httpTransport = _httpTransport;
		this._httpMethod = httpMethod;
		this._simpleUri = simpleUri;
		this._urlBindVariables = urlBindVariables;
		this._headers = headers;
		this._content = content;
		this._formParameters = formParameters;
		this._fileUploads = fileUploads;
		this._dropResponse = _dropResponse;
		this._callback = _callback;
		this._pool = _pool;
		this._allocateStartTimeMillis = allocateStartTimeMillis;
		this._userId = userId;
	}
	
	@Override
	public void operationComplete(Future<Channel> future) throws Exception {		String uri;
		if ((_urlBindVariables != null) && !_urlBindVariables.isEmpty()) {
			uri = _simpleUri.getUriString(_urlBindVariables);
		} else {
			uri = _simpleUri.getUriString();
		}
		
		if (future.isSuccess()) {

			Channel ch = future.getNow();			

			if (!ch.isActive()) {
				logger.info("operationComplete received an inactive channel for userId = " + _userId + ".  Retrying."
						+ " isActive = " + ch.isActive()
						+ ", isOpen = " + ch.isOpen()
						+ ", isRegistered = " + ch.isRegistered()
						);
				ch.close();
				_pool.release(ch);
				Future<Channel> f = _pool.acquire();
				long now = _allocateStartTimeMillis;
				if (channelStatsCollectorLogger.isDebugEnabled()) {
					now = System.currentTimeMillis();
					_channelStatsCollector.incrementNumChannelsRequested();
					_channelStatsCollector.incrementNumChannelsAcquiredClosed();
				}
				f.addListener(new ChannelAllocatedFutureListener(_httpTransport, _httpMethod, _simpleUri, 
										_urlBindVariables, _headers, _content, _formParameters, _fileUploads, _dropResponse, 
										_callback, _pool, now, _userId));
				return;
			}			
			
			/*
			 * Add a channelFutureListener to listen for the channel being closed.
			 */
			ChannelCloseFutureListener closeListener = new ChannelCloseFutureListener(_pool, 
							_httpTransport, _httpMethod, _simpleUri, 
							_urlBindVariables, _headers, _content, _formParameters, _fileUploads, _dropResponse, 
							_callback, _userId, _channelStatsCollector);
			ch.closeFuture().addListener(closeListener);			
			
			if (channelStatsCollectorLogger.isDebugEnabled()) {
				long channelAllocDelayMillis = System.currentTimeMillis() - _allocateStartTimeMillis;
				Boolean wasCreated = ch.attr(WASCREATEDKEY).get();
				if (wasCreated != null) {
					if (wasCreated) {
						_channelStatsCollector.addCreateTime(channelAllocDelayMillis);
					} else {
						_channelStatsCollector.addAcquireTime(channelAllocDelayMillis);
					}
				}
				logger.trace("Took " + channelAllocDelayMillis + " millisec to allocate a channel for userId = " + _userId + " for " + _httpMethod + " of URL "
						+ _simpleUri.getUriString(_urlBindVariables));
			}
			
			logger.debug("channel allocation succeeded for " + _httpMethod + " request with url "
					+ uri + ", userId = " + _userId + ", behaviorId = " + _callback.getBehaviorId()
					+ ". Creating and writing request. Channel isActive = " + ch.isActive()
					+ ", isWriteable = " + ch.isWritable()
					+ ", isRegistered = " + ch.isRegistered()
					+ ", remoteAddress = " + ch.remoteAddress()
					+ ", localAddress = " + ch.localAddress()
					);
			if ((_content != null) && (_formParameters != null) && !_formParameters.isEmpty()) {
				logger.warn("Got a " + _httpMethod + " request with url "
					+ uri + " which has both content and form parameters.  This is not currently supported.  Only content will be sent.");
			}

			if ((_content != null) && (_fileUploads != null) && !_fileUploads.isEmpty()) {
				logger.warn("Got a " + _httpMethod + " request with url "
					+ uri + " which has both content and file uploads.  This is not currently supported.  Only content will be sent.");
			}
			
			// Create the request.
			HttpRequest request = null;
			ByteBuf buf = null;
			HttpPostRequestEncoder bodyRequestEncoder = null;
			if (_content != null) {
				buf = ch.alloc().buffer();
				buf.writeBytes(_content.getBytes());
				
				request = new DefaultFullHttpRequest(HttpVersion.HTTP_1_1, _httpMethod, uri, buf);
				request.headers().set(HttpHeaderNames.CONTENT_LENGTH, buf.readableBytes());

			} else if ((_fileUploads != null) && !_fileUploads.isEmpty())  {

				request = new DefaultFullHttpRequest(HttpVersion.HTTP_1_1, _httpMethod, uri);				
				/*
				 * Handle a multipart request
				 */
				bodyRequestEncoder = new HttpPostRequestEncoder(_factory, request, true);
				/*
				 * Add any form parameters
				 */
				if (_formParameters != null)  {
					for (String key: _formParameters.keySet()) {
						bodyRequestEncoder.addBodyAttribute(key, _formParameters.get(key));
					}
				}
				
				/*
				 * Add the files
				 */
				for (FileUploadInfo uploadInfo : _fileUploads) {
					bodyRequestEncoder.addBodyFileUpload(uploadInfo.getName(), uploadInfo.getFile(), 
												uploadInfo.getContentType(), uploadInfo.isText());
				}
				
			} else if ((_formParameters != null) && !_formParameters.isEmpty()) {
				request = new DefaultFullHttpRequest(HttpVersion.HTTP_1_1, _httpMethod, uri);
				bodyRequestEncoder = new HttpPostRequestEncoder(_factory, request, false);
				for (String key : _formParameters.keySet()) {
					bodyRequestEncoder.addBodyAttribute(key, _formParameters.get(key));
				}
			} else {
				request = new DefaultFullHttpRequest(HttpVersion.HTTP_1_1, _httpMethod, uri);
				request.headers().set(HttpHeaderNames.CONTENT_LENGTH, 0);
			}

			setHeaders(request, _headers);
			request.headers().set(HttpHeaderNames.HOST, _simpleUri.getHostname());
			request.headers().set(HttpHeaderNames.USER_AGENT, "Weathervane Workload Driver");
			_httpTransport.setCookies(request);			
			
			if (bodyRequestEncoder != null) {
				request = bodyRequestEncoder.finalizeRequest();
			}
			
			if (!_dropResponse) {
				/*
				 * If not dropping response, then use the HttpObjectAggregator to get 
				 * a FullHttpMessage 
				 */
				if (ch.pipeline().get("aggregator") == null) {
					logger.debug("Adding httpObjectAggregator to pipeline for " + _httpMethod + " request with url " + uri + ",  userId = " + _userId + ", behaviorId = "
							+ _callback.getBehaviorId());
					if (ch.pipeline().get("chunkedWriter") != null) {
						ch.pipeline().addAfter("chunkedWriter", "aggregator", new HttpObjectAggregator(512*1024));
					} else {
						logger.warn("Trying to add aggregator but there is no chunkedWriter. "
								+ " isActive = " + ch.isActive()
								+ ", localAddress = " + ch.localAddress()
								+ ", remoteAddress = " + ch.remoteAddress()
								);
						StringBuilder handlerNames = new StringBuilder("Pipeline has handlers: ");
						for (String name : ch.pipeline().names()) {
							handlerNames.append(name + ", ");
						}
						logger.warn(handlerNames.toString());
						throw new RuntimeException("Trying to add aggregator but there is no chunkedWriter.");
					}
				}
			} else {
				if (ch.pipeline().get("aggregator") != null) {
					logger.debug("Removing httpObjectAggregator from pipeline for " + _httpMethod + " request with url " + uri + ",  userId = " + _userId + ", behaviorId = "
							+ _callback.getBehaviorId());
					ch.pipeline().remove("aggregator");
				}
			}

			if (ch.pipeline().get("responseHandler") != null) {
				ch.pipeline().remove("responseHandler");
			}
			ch.pipeline().addLast("responseHandler", new ResponseInboundHandler(_httpTransport, request, _dropResponse, 
							_callback, ch, _pool, closeListener, _userId));

			if (logger.isTraceEnabled()) {
				if (ch.pipeline().get("logger") == null) {
					logger.debug("Adding logger to pipeline for " + _httpMethod + " request with url "
							+ uri + ", behaviorId = " + _callback.getBehaviorId());
					ch.pipeline().addBefore("codec", "logger", new LoggingHandler(ChannelAllocatedFutureListener.class));
				}
						
				StringBuilder handlerNames = new StringBuilder("Pipeline has handlers: ");
				for (String name : ch.pipeline().names()) {
					handlerNames.append(name + ", ");
				}
				logger.debug(handlerNames.toString());
			}
						
			logger.debug("Writing request " + _httpMethod + ":" + uri + ",  userId = " + _userId + ", behaviorId = " + _callback.getBehaviorId());
			ch.write(request);
			if ((bodyRequestEncoder != null) && (bodyRequestEncoder.isChunked())) {
				ch.write(bodyRequestEncoder);
			}
			ch.flush();			
			
		} else {
			logger.info("channel allocation failed for " + _httpMethod + " request with url "
					+ uri + ",  userId = " + _userId + ", behaviorId = " + _callback.getBehaviorId() + ", cause = " + future.cause().getMessage());
			// retry
			long now = _allocateStartTimeMillis;
			if (channelStatsCollectorLogger.isDebugEnabled()) {
				now = System.currentTimeMillis();
				_channelStatsCollector.incrementNumChannelsRequested();
				_channelStatsCollector.incrementNumChannelsAcquiredFailed();
			}
			Future<Channel> f = _pool.acquire();
			f.addListener(new ChannelAllocatedFutureListener(_httpTransport, _httpMethod, _simpleUri, 
									_urlBindVariables, _headers, _content, _formParameters, _fileUploads, _dropResponse, 
									_callback, _pool, now, _userId));
		}
		
	}
	
	/**
	 * Sets the headers of an HTTP request necessary to execute.
	 * 
	 * @param httpRequest
	 *            The HTTP request to add the basic headers.
	 * @param headers
	 *            A map of key-value pairs representing the headers.
	 */
	protected void setHeaders(HttpRequest httpRequest, Map<String, String> headers) {

		HttpHeaders httpHeaders = httpRequest.headers();
		
		synchronized (headers) {
			if (headers == null) {
				logger.warn("Headers for " + _httpMethod + " request with url " 
							+ _simpleUri.getUriString() + ",  userId = " + _userId + ", behaviorId = " + _callback.getBehaviorId() + " are null");
			} else {
				for (Map.Entry<String, String> entry : headers.entrySet()) {
					httpHeaders.set(entry.getKey(), entry.getValue());
				}
			}
		}
	}

}

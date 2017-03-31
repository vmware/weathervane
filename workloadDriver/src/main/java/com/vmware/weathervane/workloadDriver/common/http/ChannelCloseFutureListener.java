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

import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;
import io.netty.channel.pool.FixedChannelPool;
import io.netty.handler.codec.http.HttpMethod;
import io.netty.util.concurrent.Future;

public class ChannelCloseFutureListener implements ChannelFutureListener {
	private static final Logger logger = LoggerFactory.getLogger(ChannelCloseFutureListener.class);
	private static final Logger channelStatsCollectorLogger = LoggerFactory.getLogger(ChannelStatsCollector.class);

	private FixedChannelPool _pool;
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
	private long _userId;
	private ChannelStatsCollector _channelStatsCollector;

	public ChannelCloseFutureListener(FixedChannelPool pool, HttpTransport httpTransport, HttpMethod httpMethod, SimpleUri simpleUri,
			Map<String, String> urlBindVariables, Map<String, String> headers, String content, Map<String, String> formParameters,
			List<FileUploadInfo> fileUploads, boolean dropResponse, HttpRequestCompleteCallback callback, long userId,
			ChannelStatsCollector channelStatsCollector) {
		super();
		this._pool = pool;
		this._httpTransport = httpTransport;
		this._httpMethod = httpMethod;
		this._simpleUri = simpleUri;
		this._urlBindVariables = urlBindVariables;
		this._headers = headers;
		this._content = content;
		this._formParameters = formParameters;
		this._fileUploads = fileUploads;
		this._dropResponse = dropResponse;
		this._callback = callback;
		this._userId = userId;
		this._channelStatsCollector = channelStatsCollector;
	}	
	
	@Override
	public void operationComplete(ChannelFuture future) throws Exception {
		Channel ch = future.channel();
		logger.info("operationComplete channel closed for userId = " + _userId + ".  Retrying."
				+ " localAddress = " + ch.localAddress()
				+ ", remoteAddress = " + ch.remoteAddress()
				);
		_pool.release(ch);
		Future<Channel> f = _pool.acquire();
		long now = 0;
		if (channelStatsCollectorLogger.isDebugEnabled()) {
			now = System.currentTimeMillis();
			_channelStatsCollector.incrementNumChannelsRequested();
			_channelStatsCollector.incrementNumChannelsAcquiredClosed();
		}
		f.addListener(new ChannelAllocatedFutureListener(_httpTransport, _httpMethod, _simpleUri, 
								_urlBindVariables, _headers, _content, _formParameters, _fileUploads, _dropResponse, 
								_callback, _pool, now, _userId));
	}

}

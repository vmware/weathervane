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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.channel.Channel;
import io.netty.channel.pool.AbstractChannelPoolHandler;
import io.netty.handler.codec.http.HttpClientCodec;
import io.netty.handler.ssl.SslContext;
import io.netty.handler.stream.ChunkedWriteHandler;
import io.netty.handler.timeout.ReadTimeoutHandler;

public class HttpClientChannelPoolHandler extends AbstractChannelPoolHandler {

	private static final Logger logger = LoggerFactory.getLogger(HttpClientChannelPoolHandler.class);
	private static final Logger channelStatsCollectorLogger = LoggerFactory.getLogger(ChannelStatsCollector.class);

	private SslContext _sslContext = null;
	private boolean _useSsl = false;
	private long _userId;
	private long _channelsCreated = 0;
	private long _channelsOutstanding = 0;
	private ChannelStatsCollector _channelStatsCollector = ChannelStatsCollector.getInstance();
	
	public HttpClientChannelPoolHandler(SslContext sslContext, boolean useSsl, long userId) {
		super();
		this._useSsl = useSsl;
		this._sslContext = sslContext;
		this._userId = userId;
	}

	@Override
	public void channelCreated(Channel ch) throws Exception {
		LoggingChannelCloseFutureListener closeListener = new LoggingChannelCloseFutureListener(_userId);
		ch.closeFuture().addListener(closeListener);

		if (channelStatsCollectorLogger.isDebugEnabled()) {
			_channelStatsCollector.incrementNumChannelsCreated();
		}
		
		/*
		 * Add an attribute to indicate that the channel was created
		 */
		ch.attr(ChannelAllocatedFutureListener.WASCREATEDKEY).set(true);
		
		_channelsCreated++;
		_channelsOutstanding++;
		logger.debug("channelCreated for userId = " + _userId + ", remoteAddress = " + ch.remoteAddress() + ", localAddress = " + ch.localAddress()
				+ ", useSsl = " + _useSsl + ", channelsCreated = " + _channelsCreated + ", channelsOutstanding = " + _channelsOutstanding);
		ch.pipeline().addFirst("codec", new HttpClientCodec());
		ch.pipeline().addAfter("codec", "chunkedWriter", new ChunkedWriteHandler());
		if (_useSsl) {
			ch.pipeline().addFirst("ssl", _sslContext.newHandler(ch.alloc()));
		}

		/*
		 * Add a read timeout handler to close the connection if a request takes
		 * too long. ToDo: Need to parameterize the timeout as 60 seconds may
		 * not be correct for some workloads.
		 */
		if (ch.pipeline().get("readTimeoutHandler") != null) {
			ch.pipeline().remove("readTimeoutHandler");
		}
		ch.pipeline().addLast("readTimeoutHandler", new ReadTimeoutHandler(1200));

	}

	@Override
	public void channelReleased(Channel ch) throws Exception {
		_channelsOutstanding--;
		logger.debug("channelReleased for userId = " + _userId + ", remoteAddress = " + ch.remoteAddress() + ", localAddress = " + ch.localAddress()
				+ ", useSsl = " + _useSsl + ", channelsCreated = " + _channelsCreated + ", channelsOutstanding = " + _channelsOutstanding);

		ch.attr(ChannelAllocatedFutureListener.WASCREATEDKEY).getAndSet(null);

		if (ch.pipeline().get("readTimeoutHandler") != null) {
			ch.pipeline().remove("readTimeoutHandler");
		}

	}

	@Override
	public void channelAcquired(Channel ch) throws Exception {
		
		if (channelStatsCollectorLogger.isDebugEnabled()) {
			_channelStatsCollector.incrementNumChannelsAcquired();
		}
		
		/*
		 * Add an attribute to indicate that the channel was acquired, not created
		 */
		ch.attr(ChannelAllocatedFutureListener.WASCREATEDKEY).set(false);

		_channelsOutstanding++;
		logger.debug("channelAcquired for userId = " + _userId + ", remoteAddress = " + ch.remoteAddress() + ", localAddress = " + ch.localAddress()
				+ ", useSsl = " + _useSsl + ", channelsCreated = " + _channelsCreated + ", channelsOutstanding = " + _channelsOutstanding);

		/*
		 * Add a read timeout handler to close the connection if a request takes
		 * too long. ToDo: Need to parameterize the timeout as 60 seconds may
		 * not be correct for some workloads.
		 */
		if (ch.pipeline().get("readTimeoutHandler") != null) {
			ch.pipeline().remove("readTimeoutHandler");
		}
		ch.pipeline().addLast("readTimeoutHandler", new ReadTimeoutHandler(60));
	}

}

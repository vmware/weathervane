/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.http;

import java.net.SocketAddress;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.channel.Channel;
import io.netty.channel.ChannelFuture;
import io.netty.channel.ChannelFutureListener;

public class LoggingChannelCloseFutureListener implements ChannelFutureListener {
	private static final Logger logger = LoggerFactory.getLogger(LoggingChannelCloseFutureListener.class);

	private long _userId;
	
	
	public LoggingChannelCloseFutureListener(long userId) {
		_userId = userId;
	}
	
	@Override
	public void operationComplete(ChannelFuture future) throws Exception {
		Channel ch = future.channel();
		SocketAddress localAddress = ch.localAddress();
		SocketAddress remoteAddress = ch.remoteAddress();
		logger.debug("Channel closed for userId = " + _userId + ", localAddress = " + localAddress
				+ ", remoteAddress = " + remoteAddress);
	}

}

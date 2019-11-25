/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.http;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import io.netty.bootstrap.Bootstrap;
import io.netty.channel.ChannelOption;
import io.netty.channel.EventLoopGroup;
import io.netty.channel.epoll.EpollEventLoopGroup;
import io.netty.channel.epoll.EpollSocketChannel;

public class ClientBootstrapFactory {
	private static final Logger logger = LoggerFactory.getLogger(ClientBootstrapFactory.class);
	
	private static final Integer numHttpPoolThreads = Integer.getInteger("NUMHTTPPOOLTHREADS", 4 * Runtime.getRuntime().availableProcessors());
	private static Bootstrap bootstrapInstance;
	
	static {
		EventLoopGroup group = new EpollEventLoopGroup(numHttpPoolThreads);
		bootstrapInstance = new Bootstrap();
		bootstrapInstance.group(group).option(ChannelOption.TCP_NODELAY, true)
		.option(ChannelOption.SO_SNDBUF, 64*1024)
		.option(ChannelOption.SO_RCVBUF, 64*1024)
		.option(ChannelOption.CONNECT_TIMEOUT_MILLIS, 2000)
						 .channel(EpollSocketChannel.class);
	}
	
	public static Bootstrap getInstance() {
		logger.debug("getInstance");
		return bootstrapInstance;
	}

}

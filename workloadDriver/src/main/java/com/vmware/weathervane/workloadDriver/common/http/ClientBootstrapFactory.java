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

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
package com.vmware.weathervane.auction.mvc;

import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import javax.inject.Inject;
import javax.inject.Named;
import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.servlet.DispatcherServlet;

public class AsyncDispatcherServlet extends DispatcherServlet {

	private static final long serialVersionUID = 1L;
	private static final Logger logger = LoggerFactory.getLogger(AsyncDispatcherServlet.class);

	@Inject
	@Named("asyncDispatcherThreadPool")
	private ExecutorService asyncDispatcherThreadPool;
	
	// Need to inject this value
    private static final int NUM_ASYNC_TASKS = 15;
	public static final long timeout=0;
	
	@Override
	public void init(ServletConfig config) throws ServletException {
		super.init(config);
		asyncDispatcherThreadPool = Executors.newFixedThreadPool(NUM_ASYNC_TASKS);
	}
	
	@Override
	public void destroy() {
		asyncDispatcherThreadPool.shutdownNow();
		super.destroy();
	}
	
	@Override
	protected void doDispatch(final HttpServletRequest request, final HttpServletResponse response) throws Exception {
//		final AsyncContext asyncCtxt = request.startAsync(request, response);
//		asyncCtxt.setTimeout(timeout);
//		
//		FutureTask futureTask = new FutureTask(new Runnable() {
//			
//			@Override
//			public void run() {
//				try {
//					logger.info("Dispatching request " + request);
//					AsyncDispatcherServlet.super.doDispatch(request, response);
//					logger.info("doDispatch returned from processing request " + request);
//					asyncCtxt.complete();
//				} catch (Exception ex) {
//					logger.warning("Error in async request " +  ex.toString());
//				}
//			}
//		}, null);
//		
//		asyncCtxt.addListener(new AsyncDispatcherServletListener(futureTask));
//		asyncDispatcherThreadPool.execute(futureTask);
		
		
		logger.info("AsyncDispatcherServlet::doDispatch start. contextConfigLocation = " + getContextConfigLocation());
//		logger.info("AsyncDispatcherServlet::doDispatch. request.getRequestUri = " + request.getRequestURI());
//
		super.doDispatch(request, response);
		logger.info("AsyncDispatcherServlet::doDispatch complete");
	}
	
	
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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

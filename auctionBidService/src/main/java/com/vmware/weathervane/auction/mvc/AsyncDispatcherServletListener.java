/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.mvc;

import java.io.IOException;
import java.io.PrintWriter;

import javax.servlet.AsyncEvent;
import javax.servlet.AsyncListener;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class AsyncDispatcherServletListener implements AsyncListener {
	private static final Logger logger = LoggerFactory.getLogger(AsyncDispatcherServletListener.class);
	
	public AsyncDispatcherServletListener() {
	}
		
	@Override
	public void onComplete(AsyncEvent arg0) throws IOException {
		logger.info("Completed async processing");
	}

	@Override
	public void onError(AsyncEvent event) throws IOException {
        logger.warn("Error in async request " + event.getThrowable().toString());
        event.getThrowable().printStackTrace();
        handleTimeoutOrError(event, "Error processing " + event.getThrowable().getMessage());
	}

	@Override
	public void onStartAsync(AsyncEvent arg0) throws IOException {
		logger.info("Starting async processing");
	}

	@Override
	public void onTimeout(AsyncEvent event) throws IOException {
		HttpServletRequest request = (HttpServletRequest) event.getSuppliedRequest();
        logger.warn("Async request did not complete. timeout occured. URL =  " + request.getRequestURL().toString());
        handleTimeoutOrError(event, "Request timed out");
	}
 
	private void handleTimeoutOrError(AsyncEvent event, String message) {
        PrintWriter writer = null;
        try {
            HttpServletResponse response = (HttpServletResponse) event.getAsyncContext().getResponse();
            response.setStatus(HttpServletResponse.SC_REQUEST_TIMEOUT);
            writer = response.getWriter();
            writer.print(message);
            writer.flush();
        } catch (IOException ex) {
            logger.warn(ex.toString());
        } finally {
            if (writer != null) {
                writer.close();
            }
            event.getAsyncContext().complete();
        }
    }
}

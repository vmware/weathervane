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

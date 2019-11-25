/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.http;

import java.util.UUID;

import io.netty.handler.codec.http.HttpHeaders;
import io.netty.handler.codec.http.HttpResponseStatus;


/**
 * This interface is used by Classes that call the fetch methods on the HttpTransport and
 * that want a callback when the operation completes or fails.
 * 
 * @author Hal
 *
 */
public interface HttpRequestCompleteCallback {
	
	public void httpRequestCompleted(HttpResponseStatus status,  HttpHeaders headers, String content, boolean isGet);
		
	public void httpRequestFailed(Throwable cause, boolean isGet);
	
	public UUID getBehaviorId();

}

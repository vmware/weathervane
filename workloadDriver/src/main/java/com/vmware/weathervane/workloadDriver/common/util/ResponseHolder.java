/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.common.util;

public class ResponseHolder<T, U> {
	
	private T rawResponse;
	private U parsedResponse;
	
	public ResponseHolder() {
		this.setRawResponse(null);
		this.setParsedResponse(null);
	}

	public ResponseHolder(T rawResponse) {
		this.setRawResponse(rawResponse);
	}

	public ResponseHolder(T rawResponse, U parsedResponse) {
		this.setRawResponse(rawResponse);
		this.setParsedResponse(parsedResponse);
	}

	public void clear() {
		this.setRawResponse(null);
		this.setParsedResponse(null);
	}

	public T getRawResponse() {
		return rawResponse;
	}

	public void setRawResponse(T rawResponse) {
		this.rawResponse = rawResponse;
	}

	public U getParsedResponse() {
		return parsedResponse;
	}

	public void setParsedResponse(U parsedResponse) {
		this.parsedResponse = parsedResponse;
	}

}

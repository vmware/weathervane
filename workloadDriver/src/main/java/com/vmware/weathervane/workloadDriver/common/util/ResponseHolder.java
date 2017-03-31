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

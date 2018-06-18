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
package com.vmware.weathervane.auction.interceptors;

import java.util.Enumeration;

import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.web.servlet.handler.HandlerInterceptorAdapter;

/**
 * @author Keesun Baik
 */
public class CorsInterceptor extends HandlerInterceptorAdapter {

	private static final Logger logger = LoggerFactory.getLogger(CorsInterceptor.class);

	private static final String ORIGIN = "Origin";
	private static final String AC_REQUEST_METHOD = "Access-Control-Request-Method";
	private static final String AC_REQUEST_HEADERS = "Access-Control-Request-Headers";

	private static final String AC_ALLOW_ORIGIN = "Access-Control-Allow-Origin";
	private static final String AC_ALLOW_METHODS = "Access-Control-Allow-Methods";
	private static final String AC_ALLOW_HEADERS = "Access-Control-Allow-Headers";
	private static final String AC_MAX_AGE = "Access-Control-Max-Age";
	private static final String DEFAULT_MAX_AGE = "3600";

	private CorsData corsData;

	private String origin;
	private String allowMethods = "GET, HEAD, POST, PUT, DELETE, TRACE, OPTIONS";
	private String allowHeaders;

	public void setOrigin(String origin) {
		this.origin = origin;
	}

	public void setAllowMethods(String allowMethods) {
		this.allowMethods = allowMethods;
	}

	public void setAllowHeaders(String allowHeaders) {
		this.allowHeaders = allowHeaders;
	}

	@Override
	public boolean preHandle(HttpServletRequest request, HttpServletResponse response, Object handler) throws Exception {
		this.corsData = new CorsData(request);

		if (this.corsData.isPreflighted()) {
			logger.debug("CorsInterceptor:preHandle: isPreflighted == true");
			response.setHeader(AC_ALLOW_ORIGIN, this.corsData.getOrigin());
			response.setHeader(AC_ALLOW_METHODS, allowMethods);
			response.setHeader(AC_ALLOW_HEADERS, this.corsData.getRequestHeaders());
			response.setHeader(AC_MAX_AGE, DEFAULT_MAX_AGE);
			return false;
		} else if (this.corsData.isSimple()) {
			response.setHeader(AC_ALLOW_ORIGIN, this.corsData.getOrigin());
			response.setHeader(AC_MAX_AGE, DEFAULT_MAX_AGE);

		}

		return true;
	}

	class CorsData {

		private String origin;
		private String requestMethods;
		private String requestHeaders;

		CorsData(HttpServletRequest request) {
			Enumeration<String> headers = request.getHeaderNames();
			int i = 1;
			this.origin = request.getHeader(ORIGIN);
			this.requestMethods = request.getHeader(AC_REQUEST_METHOD);
			this.requestHeaders = request.getHeader(AC_REQUEST_HEADERS);
		}

		public boolean hasOrigin() {
			boolean retval = origin != null && !origin.isEmpty();
			logger.debug("hasOrigin = " + retval);
			return retval;
		}

		public boolean hasRequestMethods() {
			boolean retval = requestMethods != null && !requestMethods.isEmpty();
			return retval;
		}

		public boolean hasRequestHeaders() {
			boolean retval = requestHeaders != null && !requestHeaders.isEmpty();
			return retval;
		}

		public String getOrigin() {
			return origin;
		}

		public String getRequestMethods() {
			return requestMethods;
		}

		public String getRequestHeaders() {
			return requestHeaders;
		}

		public boolean isPreflighted() {
			return hasOrigin() && hasRequestHeaders() && hasRequestMethods();
		}

		public boolean isSimple() {
			return hasOrigin() && !hasRequestHeaders();
		}
	}
}
/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/*
 * Copyright 2002-2012 the original author or authors.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
package com.vmware.weathervane.auction.controllers;

import javax.annotation.Resource;

import org.springframework.http.HttpHeaders;

import com.vmware.weathervane.auction.security.SecurityUtil;

public class BaseController {

	@Resource
	private SecurityUtil securityUtil;


	public SecurityUtil getSecurityUtil() {
		return securityUtil;
	}

	public void setSecurityUtil(SecurityUtil securityUtil) {
		this.securityUtil = securityUtil;
	}

	public HttpHeaders getNoCacheHeaders() {
		HttpHeaders responseHeaders = new HttpHeaders();
		responseHeaders.set("Cache-Control", "no-cache");
		return responseHeaders;
	}
	
}

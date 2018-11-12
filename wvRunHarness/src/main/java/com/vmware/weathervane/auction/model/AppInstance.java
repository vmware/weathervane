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
package com.vmware.weathervane.auction.model;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.defaults.AppInstanceDefaults;

@JsonIgnoreProperties(ignoreUnknown = true)
public class AppInstance {

	private Long id;

	private String edgeService;

	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}
	
	public String getEdgeService() {
		return edgeService;
	}

	public void setEdgeService(String edgeService) {
		this.edgeService = edgeService;
	}


	public AppInstance mergeDefaults(final AppInstanceDefaults defaults) {
		
		this.setEdgeService(edgeService != null ? edgeService : defaults.getEdgeService());

		return this;
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof AppInstance))
			return false;
		if (obj == this)
			return true;

		AppInstance rhs = (AppInstance) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}

	@Override
	public String toString() {
		return "AppInstance [edgeService=" + edgeService + "]";
	}

}

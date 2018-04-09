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
package com.vmware.weathervane.auction.representation.configuration;

import java.util.List;

import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.configuration.WebServer;

public class ChangeConfigurationRequest {

	private List<AppServer> appServersToAdd;
	private List<WebServer> webServersToAdd;
	private Long numAppServersToRemove;
	private Long numWebServersToRemove;

	public ChangeConfigurationRequest() {
	};

	public ChangeConfigurationRequest(List<AppServer> appServersToAdd, List<WebServer> webServersToAdd, 
				Long numAppServersToRemove,	Long numWebServersToRemove) {
		this.appServersToAdd = appServersToAdd;
		this.webServersToAdd = webServersToAdd;
		this.numAppServersToRemove = numAppServersToRemove;
		this.numWebServersToRemove = numWebServersToRemove;
	}

	public List<AppServer> getAppServersToAdd() {
		return appServersToAdd;
	}

	public List<WebServer> getWebServersToAdd() {
		return webServersToAdd;
	}

	public void setAppServersToAdd(List<AppServer> appServersToAdd) {
		this.appServersToAdd = appServersToAdd;
	}

	public void setWebServersToAdd(List<WebServer> webServersToAdd) {
		this.webServersToAdd = webServersToAdd;
	}

	public Long getNumAppServersToRemove() {
		return numAppServersToRemove;
	}

	public Long getNumWebServersToRemove() {
		return numWebServersToRemove;
	}

	public void setNumAppServersToRemove(Long numAppServersToRemove) {
		this.numAppServersToRemove = numAppServersToRemove;
	}

	public void setNumWebServersToRemove(Long numWebServersToRemove) {
		this.numWebServersToRemove = numWebServersToRemove;
	}

	@Override
	public String toString() {
		StringBuilder retString = new StringBuilder();

		if (appServersToAdd != null) {
			if (appServersToAdd.size() > 0) {
				retString.append("AppServersToAdd: [");
			}
			int index = 0;
			for (AppServer appServer : appServersToAdd) {
				retString.append("AppServer" + index + " hostname: " + appServer.getHostHostName() + ",");
				index++;
			}
			if (appServersToAdd.size() > 0) {
				retString.append("], ");
			}
		}

		if (webServersToAdd != null) {
			if (webServersToAdd.size() > 0) {
				retString.append("WebServersToAdd: [");
			}
			int index = 0;
			for (WebServer webServer : webServersToAdd) {
				retString.append("WebServer" + index + " hostname: " + webServer.getHostHostName() + ",");
				index++;
			}
			if (webServersToAdd.size() > 0) {
				retString.append("], ");
			}
		}

		if (numAppServersToRemove != null) {
				retString.append("NumAppServersToRemove: [ " + numAppServersToRemove + " ], ");
		}

		if (numWebServersToRemove != null) {
			retString.append("NumWebServersToRemove: [ " + numWebServersToRemove + " ], ");
		}
		return retString.toString();
	}

}

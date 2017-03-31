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

import org.springframework.hateoas.ResourceSupport;

import com.vmware.weathervane.auction.model.configuration.AppServer;
import com.vmware.weathervane.auction.model.configuration.ConfigurationManager;
import com.vmware.weathervane.auction.model.configuration.DbServer;
import com.vmware.weathervane.auction.model.configuration.FileServer;
import com.vmware.weathervane.auction.model.configuration.IpManager;
import com.vmware.weathervane.auction.model.configuration.LbServer;
import com.vmware.weathervane.auction.model.configuration.MsgServer;
import com.vmware.weathervane.auction.model.configuration.NosqlServer;
import com.vmware.weathervane.auction.model.configuration.WebServer;

public class ConfigurationResponse extends ResourceSupport {
	private List<ConfigurationManager> configurationManagers;
	private List<IpManager> ipManagers;
	private List<LbServer> lbServers;
	private List<WebServer> webServers;
	private List<AppServer> appServers;
	private List<MsgServer> msgServers;
	private List<DbServer> dbServers;
	private List<NosqlServer> nosqlServers;
	private List<FileServer> fileServers;
	
	public List<ConfigurationManager> getConfigurationManagers() {
		return configurationManagers;
	}
	public void setConfigurationManagers(List<ConfigurationManager> configurationManagers) {
		this.configurationManagers = configurationManagers;
	}
	public List<IpManager> getIpManagers() {
		return ipManagers;
	}
	public void setIpManagers(List<IpManager> ipManagers) {
		this.ipManagers = ipManagers;
	}
	public List<LbServer> getLbServers() {
		return lbServers;
	}
	public void setLbServers(List<LbServer> lbServers) {
		this.lbServers = lbServers;
	}
	public List<WebServer> getWebServers() {
		return webServers;
	}
	public void setWebServers(List<WebServer> webServers) {
		this.webServers = webServers;
	}
	public List<AppServer> getAppServers() {
		return appServers;
	}
	public void setAppServers(List<AppServer> appServers) {
		this.appServers = appServers;
	}
	public List<MsgServer> getMsgServers() {
		return msgServers;
	}
	public void setMsgServers(List<MsgServer> msgServers) {
		this.msgServers = msgServers;
	}
	public List<DbServer> getDbServers() {
		return dbServers;
	}
	public void setDbServers(List<DbServer> dbServers) {
		this.dbServers = dbServers;
	}
	public List<NosqlServer> getNosqlServers() {
		return nosqlServers;
	}
	public void setNosqlServers(List<NosqlServer> nosqlServers) {
		this.nosqlServers = nosqlServers;
	}
	public List<FileServer> getFileServers() {
		return fileServers;
	}
	public void setFileServers(List<FileServer> fileServers) {
		this.fileServers = fileServers;
	}
	
}

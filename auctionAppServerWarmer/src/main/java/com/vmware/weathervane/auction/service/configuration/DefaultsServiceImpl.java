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
package com.vmware.weathervane.auction.service.configuration;

import org.springframework.stereotype.Service;

import com.vmware.weathervane.auction.model.defaults.AppInstanceDefaults;
import com.vmware.weathervane.auction.model.defaults.AppServerDefaults;
import com.vmware.weathervane.auction.model.defaults.ConfigurationManagerDefaults;
import com.vmware.weathervane.auction.model.defaults.CoordinationServerDefaults;
import com.vmware.weathervane.auction.model.defaults.DbServerDefaults;
import com.vmware.weathervane.auction.model.defaults.FileServerDefaults;
import com.vmware.weathervane.auction.model.defaults.IpManagerDefaults;
import com.vmware.weathervane.auction.model.defaults.LbServerDefaults;
import com.vmware.weathervane.auction.model.defaults.MsgServerDefaults;
import com.vmware.weathervane.auction.model.defaults.NosqlServerDefaults;
import com.vmware.weathervane.auction.model.defaults.ServiceDefaults;
import com.vmware.weathervane.auction.model.defaults.WebServerDefaults;

@Service
public class DefaultsServiceImpl implements DefaultsService {
		
	private ServiceDefaults defaults = new ServiceDefaults();
	
	@Override
	public ServiceDefaults getDefaults() {
		return defaults;
	}
	
	public void setDefaults(ServiceDefaults defaults) {
		this.defaults = defaults;
	}
	
	@Override
	public void setAppInstanceDefaults(AppInstanceDefaults server) {
		defaults.setAppInstance(server);
	}
	@Override
	public AppInstanceDefaults getAppInstanceDefaults() {
		return defaults.getAppInstance();
	}
	
	@Override
	public void setConfigurationManagerDefaults(ConfigurationManagerDefaults server) {
		defaults.setConfigurationManager(server);
	}
	@Override
	public ConfigurationManagerDefaults getConfigurationManagerDefaults() {
		return defaults.getConfigurationManager();
	}
	
	@Override
	public void setIpManagerDefaults(IpManagerDefaults ipManager) {
		defaults.setIpManager(ipManager);
	}
	@Override
	public IpManagerDefaults getIpManagerDefaults() {
		return defaults.getIpManager();
	}
	
	@Override
	public void setLbServerDefaults(LbServerDefaults lbServer) {
		defaults.setLbServer(lbServer);	
	}
	@Override
	public LbServerDefaults getLbServerDefaults() {
		return defaults.getLbServer();
	}

	@Override
	public void setWebServerDefaults(WebServerDefaults webServer) {
		defaults.setWebServer(webServer);	
	}
	@Override
	public WebServerDefaults getWebServerDefaults() {
		return defaults.getWebServer();
	}

	@Override
	public void setAppServerDefaults(AppServerDefaults appServer) {
		defaults.setAppServer(appServer);	
	}
	@Override
	public AppServerDefaults getAppServerDefaults() {
		return defaults.getAppServer();
	}

	@Override
	public void setMsgServerDefaults(MsgServerDefaults msgServer) {
		defaults.setMsgServer(msgServer);	
	}
	@Override
	public MsgServerDefaults getMsgServerDefaults() {
		return defaults.getMsgServer();
	}

	@Override
	public void setDbServerDefaults(DbServerDefaults dbServer) {
		defaults.setDbServer(dbServer);	
	}
	@Override
	public DbServerDefaults getDbServerDefaults() {
		return defaults.getDbServer();
	}

	@Override
	public void setNosqlServerDefaults(NosqlServerDefaults nosqlServer) {
		defaults.setNosqlServer(nosqlServer);	
	}
	@Override
	public NosqlServerDefaults getNosqlServerDefaults() {
		return defaults.getNosqlServer();
	}

	@Override
	public void setFileServerDefaults(FileServerDefaults fileServer) {
		defaults.setFileServer(fileServer);	
	}
	@Override
	public FileServerDefaults getFileServerDefaults() {
		return defaults.getFileServer();
	}

	@Override
	public void setCoordinationServerDefaults(CoordinationServerDefaults server) {
		defaults.setCoordinationServer(server);	
	}

	@Override
	public CoordinationServerDefaults getCoordinationServerDefaults() {
		return defaults.getCoordinationServer();
	}
	
}

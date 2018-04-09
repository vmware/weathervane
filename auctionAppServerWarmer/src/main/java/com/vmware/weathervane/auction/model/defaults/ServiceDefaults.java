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
/**
 * This class holds the configuration for a deployment of the Auction application
 */
package com.vmware.weathervane.auction.model.defaults;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown=true)
public class ServiceDefaults {
		
	private AppInstanceDefaults appInstance = new AppInstanceDefaults();
	private ConfigurationManagerDefaults  configurationManager = new ConfigurationManagerDefaults();
	private CoordinationServerDefaults  coordinationServer = new CoordinationServerDefaults();
	private IpManagerDefaults  ipManager = new IpManagerDefaults();
	private LbServerDefaults  lbServer = new LbServerDefaults();
	private WebServerDefaults  webServer = new WebServerDefaults();
	private AppServerDefaults  appServer = new AppServerDefaults();
	private MsgServerDefaults  msgServer = new MsgServerDefaults();
	private DbServerDefaults  dbServer = new DbServerDefaults();
	private NosqlServerDefaults  nosqlServer = new NosqlServerDefaults();
	private FileServerDefaults  fileServer = new FileServerDefaults();
		
	public AppInstanceDefaults getAppInstance() {
		return appInstance;
	}
	public void setAppInstance(AppInstanceDefaults appInstance) {
		this.appInstance = appInstance;
	}
	public ConfigurationManagerDefaults getConfigurationManager() {
		return configurationManager;
	}
	public void setConfigurationManager(ConfigurationManagerDefaults configurationManager) {
		this.configurationManager = configurationManager;
	}
	public IpManagerDefaults getIpManager() {
		return ipManager;
	}
	public void setIpManager(IpManagerDefaults ipManager) {
		this.ipManager = ipManager;
	}
	public LbServerDefaults getLbServer() {
		return lbServer;
	}
	public void setLbServer(LbServerDefaults lbServer) {
		this.lbServer = lbServer;
	}
	public WebServerDefaults getWebServer() {
		return webServer;
	}
	public void setWebServer(WebServerDefaults webServer) {
		this.webServer = webServer;
	}
	public AppServerDefaults getAppServer() {
		return appServer;
	}
	public void setAppServer(AppServerDefaults appServer) {
		this.appServer = appServer;
	}
	public MsgServerDefaults getMsgServer() {
		return msgServer;
	}
	public void setMsgServer(MsgServerDefaults msgServer) {
		this.msgServer = msgServer;
	}
	public DbServerDefaults getDbServer() {
		return dbServer;
	}
	public void setDbServer(DbServerDefaults dbServer) {
		this.dbServer = dbServer;
	}
	public NosqlServerDefaults getNosqlServer() {
		return nosqlServer;
	}
	public void setNosqlServer(NosqlServerDefaults nosqlServer) {
		this.nosqlServer = nosqlServer;
	}
	public FileServerDefaults getFileServer() {
		return fileServer;
	}
	public void setFileServer(FileServerDefaults fileServer) {
		this.fileServer = fileServer;
	}
	public CoordinationServerDefaults getCoordinationServer() {
		return coordinationServer;
	}
	public void setCoordinationServer(CoordinationServerDefaults coordinationServer) {
		this.coordinationServer = coordinationServer;
	}
	
}

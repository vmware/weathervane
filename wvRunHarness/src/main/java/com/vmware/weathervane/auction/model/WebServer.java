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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.defaults.WebServerDefaults;

@JsonIgnoreProperties(ignoreUnknown = true)
public class WebServer extends Service {
	private static final Logger logger = LoggerFactory.getLogger(WebServer.class);

	private String webServerImpl;
	private Integer webServerPortStep;
	private Integer webServerPortOffset;

	private Integer httpPort;
	private Integer httpsPort;
	private Integer httpInternalPort;
	private Integer httpsInternalPort;

	private Integer nginxMaxKeepaliveRequests;
	private Integer nginxKeepaliveTimeout;
	private Integer nginxWorkerConnections;
	private String nginxServerRoot;
	private String nginxDocumentRoot;

	public WebServer() {

	}

	public WebServer mergeDefaults(final WebServerDefaults defaults) {
		WebServer mergedWebServer = (WebServer) super.mergeDefaults(this, defaults);
		mergedWebServer.setWebServerImpl(webServerImpl != null ? webServerImpl : defaults.getWebServerImpl());
		mergedWebServer.setWebServerPortOffset(webServerPortOffset != null ? webServerPortOffset : defaults.getWebServerPortOffset());
		mergedWebServer.setWebServerPortStep(webServerPortStep != null ? webServerPortStep : defaults.getWebServerPortStep());
		mergedWebServer.setNginxDocumentRoot(nginxDocumentRoot != null ? nginxDocumentRoot : defaults.getNginxDocumentRoot());
		mergedWebServer.setNginxKeepaliveTimeout(nginxKeepaliveTimeout != null ? nginxKeepaliveTimeout : defaults.getNginxKeepaliveTimeout());
		mergedWebServer.setNginxMaxKeepaliveRequests(nginxMaxKeepaliveRequests != null ? nginxMaxKeepaliveRequests : defaults.getNginxMaxKeepaliveRequests());
		mergedWebServer.setNginxServerRoot(nginxServerRoot != null ? nginxServerRoot : defaults.getNginxServerRoot());
		mergedWebServer.setNginxWorkerConnections(nginxWorkerConnections != null ? nginxWorkerConnections : defaults.getNginxWorkerConnections());
		mergedWebServer.setImageStoreType(getImageStoreType() != null ? getImageStoreType() : defaults.getImageStoreType());

		logger.debug("mergeDefaults setting webServerPortOffset default value = " + defaults.getWebServerPortOffset());
		mergedWebServer.setWebServerPortOffset(webServerPortOffset != null ? webServerPortOffset : defaults.getWebServerPortOffset());

		logger.debug("mergeDefaults setting webServerPortStep default value = " + defaults.getWebServerPortStep());
		mergedWebServer.setWebServerPortStep(webServerPortStep != null ? webServerPortStep : defaults.getWebServerPortStep());

		return mergedWebServer;
	}

	public String getWebServerImpl() {
		return webServerImpl;
	}

	public void setWebServerImpl(String webServerImpl) {
		this.webServerImpl = webServerImpl;
	}

	public Integer getWebServerPortStep() {
		return webServerPortStep;
	}

	public void setWebServerPortStep(Integer webServerPortStep) {
		this.webServerPortStep = webServerPortStep;
	}

	public Integer getWebServerPortOffset() {
		return webServerPortOffset;
	}

	public void setWebServerPortOffset(Integer webServerPortOffset) {
		this.webServerPortOffset = webServerPortOffset;
	}

	public Integer getHttpPort() {
		return httpPort;
	}

	public void setHttpPort(Integer httpPort) {
		this.httpPort = httpPort;
	}

	public Integer getHttpsPort() {
		return httpsPort;
	}

	public void setHttpsPort(Integer httpsPort) {
		this.httpsPort = httpsPort;
	}

	public Integer getHttpInternalPort() {
		return httpInternalPort;
	}

	public void setHttpInternalPort(Integer httpInternalPort) {
		this.httpInternalPort = httpInternalPort;
	}

	public Integer getHttpsInternalPort() {
		return httpsInternalPort;
	}

	public void setHttpsInternalPort(Integer httpsInternalPort) {
		this.httpsInternalPort = httpsInternalPort;
	}

	public Integer getNginxMaxKeepaliveRequests() {
		return nginxMaxKeepaliveRequests;
	}

	public void setNginxMaxKeepaliveRequests(Integer nginxMaxKeepaliveRequests) {
		this.nginxMaxKeepaliveRequests = nginxMaxKeepaliveRequests;
	}

	public Integer getNginxKeepaliveTimeout() {
		return nginxKeepaliveTimeout;
	}

	public void setNginxKeepaliveTimeout(Integer nginxKeepaliveTimeout) {
		this.nginxKeepaliveTimeout = nginxKeepaliveTimeout;
	}

	public Integer getNginxWorkerConnections() {
		return nginxWorkerConnections;
	}

	public void setNginxWorkerConnections(Integer nginxWorkerConnections) {
		this.nginxWorkerConnections = nginxWorkerConnections;
	}

	public String getNginxServerRoot() {
		return nginxServerRoot;
	}

	public void setNginxServerRoot(String nginxServerRoot) {
		this.nginxServerRoot = nginxServerRoot;
	}

	public String getNginxDocumentRoot() {
		return nginxDocumentRoot;
	}

	public void setNginxDocumentRoot(String nginxDocumentRoot) {
		this.nginxDocumentRoot = nginxDocumentRoot;
	}

	@Override
	public String toString() {
		return "WebServer [webServerImpl=" + webServerImpl + ", webServerPortStep=" + webServerPortStep + ", webServerPortOffset=" + webServerPortOffset
				+ ", httpPort=" + httpPort + ", httpsPort=" + httpsPort + ", httpInternalPort=" + httpInternalPort + ", httpsInternalPort=" + httpsInternalPort
				+ ", nginxMaxKeepaliveRequests=" + nginxMaxKeepaliveRequests + ", nginxKeepaliveTimeout=" + nginxKeepaliveTimeout + ", nginxWorkerConnections="
				+ nginxWorkerConnections + ", nginxServerRoot=" + nginxServerRoot + ", nginxDocumentRoot=" + nginxDocumentRoot + "]";
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof WebServer))
			return false;
		if (obj == this)
			return true;

		WebServer rhs = (WebServer) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}

}

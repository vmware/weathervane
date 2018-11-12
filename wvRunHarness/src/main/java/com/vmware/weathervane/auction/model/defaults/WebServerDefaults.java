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
package com.vmware.weathervane.auction.model.defaults;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown=true)
public class WebServerDefaults extends Defaults {
	
	private String webServerImpl;
    private Integer webServerPortStep;
    private Integer webServerPortOffset;

    private Integer nginxMaxKeepaliveRequests;
    private Integer nginxKeepaliveTimeout;
    private Integer nginxWorkerConnections;
    private String nginxServerRoot;
    private String nginxDocumentRoot;

    private String nginxConfFile;
    private String nginxDockerConfFile;
    private String defaultConfFile;
    private String sslConfFile;
	private String imageStoreType;

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

	public String getNginxConfFile() {
		return nginxConfFile;
	}
	public void setNginxConfFile(String nginxConfFile) {
		this.nginxConfFile = nginxConfFile;
	}
	public String getNginxDockerConfFile() {
		return nginxDockerConfFile;
	}
	public void setNginxDockerConfFile(String nginxDockerConfFile) {
		this.nginxDockerConfFile = nginxDockerConfFile;
	}
	public String getDefaultConfFile() {
		return defaultConfFile;
	}
	public void setDefaultConfFile(String defaultConfFile) {
		this.defaultConfFile = defaultConfFile;
	}
	public String getSslConfFile() {
		return sslConfFile;
	}
	public void setSslConfFile(String sslConfFile) {
		this.sslConfFile = sslConfFile;
	}
	public String getImageStoreType() {
		return imageStoreType;
	}
	public void setImageStoreType(String imageStoreType) {
		this.imageStoreType = imageStoreType;
	}
	
	@Override
	public String toString() {
		return "WebServerDefaults [webServerImpl=" + webServerImpl + ", webServerPortStep=" + webServerPortStep
				+ ", webServerPortOffset=" + webServerPortOffset + ", nginxMaxKeepaliveRequests="
				+ nginxMaxKeepaliveRequests + ", nginxKeepaliveTimeout=" + nginxKeepaliveTimeout
				+ ", nginxWorkerConnections=" + nginxWorkerConnections + ", nginxServerRoot=" + nginxServerRoot
				+ ", nginxDocumentRoot=" + nginxDocumentRoot + ", nginxConfFile=" + nginxConfFile
				+ ", nginxDockerConfFile=" + nginxDockerConfFile + ", defaultConfFile=" + defaultConfFile
				+ ", sslConfFile=" + sslConfFile + ", imageStoreType=" + imageStoreType + "]";
	}
}

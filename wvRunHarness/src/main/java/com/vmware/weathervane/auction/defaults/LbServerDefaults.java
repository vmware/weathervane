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
package com.vmware.weathervane.auction.defaults;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

@JsonIgnoreProperties(ignoreUnknown=true)
public class LbServerDefaults extends Defaults {
	
	private String lbServerImpl;
	
    private Integer haproxyMaxConn;
    private String haproxyServerRoot;

    private String haproxyCfgFile;
    private String haproxyTerminateTLSCfgFile;
    private String haproxyDockerCfgFile;
    
    private Boolean haproxyTerminateTLS;
    
	public String getLbServerImpl() {
		return lbServerImpl;
	}

	public void setLbServerImpl(String lbServerImpl) {
		this.lbServerImpl = lbServerImpl;
	}

	public Integer getHaproxyMaxConn() {
		return haproxyMaxConn;
	}

	public void setHaproxyMaxConn(Integer haproxyMaxConn) {
		this.haproxyMaxConn = haproxyMaxConn;
	}

	public String getHaproxyServerRoot() {
		return haproxyServerRoot;
	}

	public void setHaproxyServerRoot(String haproxyServerRoot) {
		this.haproxyServerRoot = haproxyServerRoot;
	}

	public String getHaproxyCfgFile() {
		return haproxyCfgFile;
	}

	public void setHaproxyCfgFile(String haproxyCfgFile) {
		this.haproxyCfgFile = haproxyCfgFile;
	}

	public String getHaproxyDockerCfgFile() {
		return haproxyDockerCfgFile;
	}

	public void setHaproxyDockerCfgFile(String haproxyDockerCfgFile) {
		this.haproxyDockerCfgFile = haproxyDockerCfgFile;
	}

	public Boolean getHaproxyTerminateTLS() {
		return haproxyTerminateTLS;
	}

	public void setHaproxyTerminateTLS(Boolean haproxyTerminateTLS) {
		this.haproxyTerminateTLS = haproxyTerminateTLS;
	}

	public String getHaproxyTerminateTLSCfgFile() {
		return haproxyTerminateTLSCfgFile;
	}

	public void setHaproxyTerminateTLSCfgFile(String haproxyTerminateTLSCfgFile) {
		this.haproxyTerminateTLSCfgFile = haproxyTerminateTLSCfgFile;
	}
}

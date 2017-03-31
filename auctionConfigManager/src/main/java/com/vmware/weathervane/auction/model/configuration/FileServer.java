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
package com.vmware.weathervane.auction.model.configuration;

import javax.persistence.Entity;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.model.defaults.FileServerDefaults;

@Entity
@JsonIgnoreProperties(ignoreUnknown=true)
public class FileServer extends Service {

	private String fileServerImpl;
	private Integer nfsPort;
	private Integer nfsInternalPort;
	

	public String getFileServerImpl() {
		return fileServerImpl;
	}

	public void setFileServerImpl(String fileServerImpl) {
		this.fileServerImpl = fileServerImpl;
	}

	public Integer getNfsPort() {
		return nfsPort;
	}

	public void setNfsPort(Integer nfsPort) {
		this.nfsPort = nfsPort;
	}

	public Integer getNfsInternalPort() {
		return nfsInternalPort;
	}

	public void setNfsInternalPort(Integer nfsInternalPort) {
		this.nfsInternalPort = nfsInternalPort;
	}

	public FileServer mergeDefaults(final FileServerDefaults defaults) {
		FileServer mergedFileServer = (FileServer) super.mergeDefaults(this, defaults);
		mergedFileServer.setFileServerImpl(fileServerImpl != null ? fileServerImpl : defaults.getFileServerImpl());

		return mergedFileServer;
	}
	
    @Override
    public boolean equals(Object obj) {
       if (!(obj instanceof FileServer))
            return false;
        if (obj == this)
            return true;

        FileServer rhs = (FileServer) obj;

        if (this.getId().equals(rhs.getId())) {
        	return true;
        } else {
        	return false;
        }
    }
	
}

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
import com.vmware.weathervane.auction.defaults.CoordinationServerDefaults;

@JsonIgnoreProperties(ignoreUnknown=true)
public class CoordinationServer extends Service {
	
	private String coordinationServerImpl;
	private Integer coordinationServerPortOffset;
	private Integer coordinationServerPortStep;
	private Integer clientInternalPort;
	private Integer clientPort;
	private Integer peerInternalPort;
	private Integer peerPort;
	private Integer electionInternalPort;
	private Integer electionPort;

	public String getCoordinationServerImpl() {
		return coordinationServerImpl;
	}

	public void setCoordinationServerImpl(String coordinationServerImpl) {
		this.coordinationServerImpl = coordinationServerImpl;
	}

	public Integer getCoordinationServerPortOffset() {
		return coordinationServerPortOffset;
	}

	public Integer getCoordinationServerPortStep() {
		return coordinationServerPortStep;
	}

	public void setCoordinationServerPortOffset(Integer coordinationServerPortOffset) {
		this.coordinationServerPortOffset = coordinationServerPortOffset;
	}

	public void setCoordinationServerPortStep(Integer coordinationServerPortStep) {
		this.coordinationServerPortStep = coordinationServerPortStep;
	}

	public Integer getClientInternalPort() {
		return clientInternalPort;
	}

	public Integer getClientPort() {
		return clientPort;
	}

	public Integer getPeerInternalPort() {
		return peerInternalPort;
	}

	public Integer getPeerPort() {
		return peerPort;
	}

	public Integer getElectionInternalPort() {
		return electionInternalPort;
	}

	public Integer getElectionPort() {
		return electionPort;
	}

	public void setClientInternalPort(Integer clientInternalPort) {
		this.clientInternalPort = clientInternalPort;
	}

	public void setClientPort(Integer clientPort) {
		this.clientPort = clientPort;
	}

	public void setPeerInternalPort(Integer peerInternalPort) {
		this.peerInternalPort = peerInternalPort;
	}

	public void setPeerPort(Integer peerPort) {
		this.peerPort = peerPort;
	}

	public void setElectionInternalPort(Integer electionInternalPort) {
		this.electionInternalPort = electionInternalPort;
	}

	public void setElectionPort(Integer electionPort) {
		this.electionPort = electionPort;
	}

	public CoordinationServer mergeDefaults(final CoordinationServerDefaults defaults) {
		CoordinationServer mergedCoordinationServer= (CoordinationServer) super.mergeDefaults(this, defaults);;
		mergedCoordinationServer.setCoordinationServerImpl(coordinationServerImpl != null ? coordinationServerImpl : defaults.getCoordinationServerImpl());

		return mergedCoordinationServer;
	}
	
    @Override
    public boolean equals(Object obj) {
       if (!(obj instanceof CoordinationServer))
            return false;
        if (obj == this)
            return true;

        CoordinationServer rhs = (CoordinationServer) obj;

        if (this.getId().equals(rhs.getId())) {
        	return true;
        } else {
        	return false;
        }
    }

}

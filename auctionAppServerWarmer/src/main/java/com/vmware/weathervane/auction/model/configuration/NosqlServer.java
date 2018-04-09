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
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;
import com.vmware.weathervane.auction.model.defaults.NosqlServerDefaults;

@Entity
@JsonIgnoreProperties(ignoreUnknown = true)
public class NosqlServer extends Service {
	
	private String nosqlServerImpl;
	private Boolean nosqlSharded;
	private Boolean nosqlReplicated;

	private Integer mongosInternalPort;
	private Integer mongodInternalPort;
	private Integer mongoc1InternalPort;
	private Integer mongoc2InternalPort;
	private Integer mongoc3InternalPort;

	private Integer mongosPort;
	private Integer mongodPort;
	private Integer mongoc1Port;
	private Integer mongoc2Port;
	private Integer mongoc3Port;


	public String getNosqlServerImpl() {
		return nosqlServerImpl;
	}

	public void setNosqlServerImpl(String nosqlServerImpl) {
		this.nosqlServerImpl = nosqlServerImpl;
	}

	public Integer getMongosInternalPort() {
		return mongosInternalPort;
	}

	public void setMongosInternalPort(Integer mongosInternalPort) {
		this.mongosInternalPort = mongosInternalPort;
	}

	public Integer getMongodInternalPort() {
		return mongodInternalPort;
	}

	public void setMongodInternalPort(Integer mongodInternalPort) {
		this.mongodInternalPort = mongodInternalPort;
	}

	public Integer getMongoc1InternalPort() {
		return mongoc1InternalPort;
	}

	public void setMongoc1InternalPort(Integer mongoc1InternalPort) {
		this.mongoc1InternalPort = mongoc1InternalPort;
	}

	public Integer getMongoc2InternalPort() {
		return mongoc2InternalPort;
	}

	public void setMongoc2InternalPort(Integer mongoc2InternalPort) {
		this.mongoc2InternalPort = mongoc2InternalPort;
	}

	public Integer getMongoc3InternalPort() {
		return mongoc3InternalPort;
	}

	public void setMongoc3InternalPort(Integer mongoc3InternalPort) {
		this.mongoc3InternalPort = mongoc3InternalPort;
	}

	public Integer getMongosPort() {
		return mongosPort;
	}

	public void setMongosPort(Integer mongosPort) {
		this.mongosPort = mongosPort;
	}

	public Integer getMongodPort() {
		return mongodPort;
	}

	public void setMongodPort(Integer mongodPort) {
		this.mongodPort = mongodPort;
	}

	public Integer getMongoc1Port() {
		return mongoc1Port;
	}

	public void setMongoc1Port(Integer mongoc1Port) {
		this.mongoc1Port = mongoc1Port;
	}

	public Integer getMongoc2Port() {
		return mongoc2Port;
	}

	public void setMongoc2Port(Integer mongoc2Port) {
		this.mongoc2Port = mongoc2Port;
	}

	public Integer getMongoc3Port() {
		return mongoc3Port;
	}

	public void setMongoc3Port(Integer mongoc3Port) {
		this.mongoc3Port = mongoc3Port;
	}

	public Boolean getNosqlSharded() {
		return nosqlSharded;
	}

	public void setNosqlSharded(Boolean nosqlSharded) {
		this.nosqlSharded = nosqlSharded;
	}

	public Boolean getNosqlReplicated() {
		return nosqlReplicated;
	}

	public void setNosqlReplicated(Boolean nosqlReplicated) {
		this.nosqlReplicated = nosqlReplicated;
	}

	public NosqlServer mergeDefaults(final NosqlServerDefaults defaults) {
		NosqlServer mergedNosqlServer = (NosqlServer) super.mergeDefaults(this, defaults);
		mergedNosqlServer.setNosqlServerImpl(nosqlServerImpl != null ? nosqlServerImpl : defaults
				.getNosqlServerImpl());
		mergedNosqlServer.setNosqlSharded(nosqlSharded != null ? nosqlSharded : defaults
				.getNosqlSharded());
		mergedNosqlServer.setNosqlReplicated(nosqlReplicated != null ? nosqlReplicated : defaults
				.getNosqlReplicated());

		return mergedNosqlServer;
	}

	@Override
	public boolean equals(Object obj) {
		if (!(obj instanceof NosqlServer))
			return false;
		if (obj == this)
			return true;

		NosqlServer rhs = (NosqlServer) obj;

		if (this.getId().equals(rhs.getId())) {
			return true;
		} else {
			return false;
		}
	}
}

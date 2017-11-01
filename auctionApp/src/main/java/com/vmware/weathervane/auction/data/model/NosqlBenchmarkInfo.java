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
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;

import org.bson.types.ObjectId;
import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.mapping.Document;

@Document
public class NosqlBenchmarkInfo implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;


	private ObjectId id;
	
	private Long maxusers;
		
	private Integer numShards;
	
	private Integer numReplicas;
	
	private String imageStoreType;

	public NosqlBenchmarkInfo() {

	}

	@Id
	public ObjectId getId() {
		return id;
	}

	public void setId(ObjectId id) {
		this.id = id;
	}
	
	public String getImageStoreType() {
		return imageStoreType;
	}

	public void setImageStoreType(String imageStoreType) {
		this.imageStoreType = imageStoreType;
	}

	@Override
	public String toString() {
		return "NosqlBenchmarkInfo.  maxusers = " + maxusers 
				+ ", numShards = " + numShards
				+ ", numReplicas = " + numReplicas
				+ ", imageStoreType = " + imageStoreType;
	}

	public Long getMaxusers() {
		return maxusers;
	}

	public void setMaxusers(Long maxusers) {
		this.maxusers = maxusers;
	}

	public Integer getNumShards() {
		return numShards;
	}

	public void setNumShards(Integer numShards) {
		this.numShards = numShards;
	}

	public Integer getNumReplicas() {
		return numReplicas;
	}

	public void setNumReplicas(Integer numReplicas) {
		this.numReplicas = numReplicas;
	}
	
}

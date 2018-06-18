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

import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;


@Entity
@Table(name = "dbbenchmarkinfo")
public class DbBenchmarkInfo implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;


	private Long id;
	
	private Long maxusers;
	
	private Long maxduration;
	
	private Long numnosqlshards;
	
	private Long numnosqlreplicas;

	private String imagestoretype;
	
	public DbBenchmarkInfo() {

	}

	@Id
	@GeneratedValue(strategy=GenerationType.TABLE)
	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}
	
	public String getImagestoretype() {
		return imagestoretype;
	}

	public void setImagestoretype(String imageStoreType) {
		this.imagestoretype = imageStoreType;
	}
	
	@Override
	public String toString() {
		return "DbBenchmarkInfo. ";
	}

	public Long getMaxusers() {
		return maxusers;
	}

	public void setMaxusers(Long maxusers) {
		this.maxusers = maxusers;
	}

	public Long getNumnosqlshards() {
		return numnosqlshards;
	}

	public void setNumnosqlshards(Long numnosqlshards) {
		this.numnosqlshards = numnosqlshards;
	}

	public Long getNumnosqlreplicas() {
		return numnosqlreplicas;
	}

	public void setNumnosqlreplicas(Long numnosqlreplicas) {
		this.numnosqlreplicas = numnosqlreplicas;
	}

	public Long getMaxduration() {
		return maxduration;
	}

	public void setMaxduration(Long maxduration) {
		this.maxduration = maxduration;
	}

}

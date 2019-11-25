/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.UUID;

import org.springframework.data.cassandra.mapping.Column;
import org.springframework.data.cassandra.mapping.PrimaryKey;
import org.springframework.data.cassandra.mapping.Table;

@Table("nosql_benchmark_info")
public class NosqlBenchmarkInfo implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	@PrimaryKey
	private UUID id;
	
	@Column("max_users")
	private Long maxusers;
			
	@Column("imagestore_type")
	private String imageStoreType;

	public NosqlBenchmarkInfo() {

	}

	public UUID getId() {
		return id;
	}

	public void setId(UUID id) {
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
		return "NosqlBenchmarkInfo. maxusers = " + maxusers 
				+ ", imageStoreType = " + imageStoreType;
	}

	public Long getMaxusers() {
		return maxusers;
	}

	public void setMaxusers(Long maxusers) {
		this.maxusers = maxusers;
	}	
}

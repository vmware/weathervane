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

@Table("imagestore_benchmark_info")
public class ImageStoreBenchmarkInfo implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	@PrimaryKey
	private UUID id;
	
	@Column("max_users")
	private Long maxusers;
		
	@Column("imagestore_type")
	private String imageStoreType;

	public ImageStoreBenchmarkInfo() {

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
		return "ImageStoreBenchmarkInfo.  ";
	}

	public Long getMaxusers() {
		return maxusers;
	}

	public void setMaxusers(Long maxusers) {
		this.maxusers = maxusers;
	}
	
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
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

}

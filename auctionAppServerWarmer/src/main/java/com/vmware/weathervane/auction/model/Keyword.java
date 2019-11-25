/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.model;

import java.io.Serializable;

public class Keyword implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	private Long id;
	private String keyword;

	private Integer version;

	public Keyword() {

	}

	public Long getId() {
		return id;
	}

	private void setId(Long id) {
		this.id = id;
	}

	public Integer getVersion() {
		return version;
	}

	public void setVersion(Integer version) {
		this.version = version;
	}

	public String getKeyword() {
		return keyword;
	}

	public void setKeyword(String keyword) {
		this.keyword = keyword;
	}

	@Override
	public String toString() {
		
		return keyword;		
	}

}

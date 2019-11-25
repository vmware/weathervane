/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.statsModel;

import java.io.Serializable;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.Table;
import javax.persistence.Version;

import com.vmware.weathervane.auction.data.model.DomainObject;

@Entity
@Table(name="fixedtimeoffset")
public class FixedTimeOffset implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	private Long id;
	private Long timeOffset;

	private Integer version;

	public FixedTimeOffset() {

	}

	@Id
	@GeneratedValue(strategy=GenerationType.TABLE)
	public Long getId() {
		return id;
	}

	private void setId(Long id) {
		this.id = id;
	}

	@Column(name="timeoffset")
	public Long getTimeOffset() {
		return timeOffset;
	}

	public void setTimeOffset(Long timeOffset) {
		this.timeOffset = timeOffset;
	}

	@Version
	public Integer getVersion() {
		return version;
	}

	public void setVersion(Integer version) {
		this.version = version;
	}

}

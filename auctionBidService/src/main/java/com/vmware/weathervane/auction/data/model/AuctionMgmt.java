/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;

import javax.persistence.Entity;
import javax.persistence.Id;
import javax.persistence.Table;

@Entity
@Table(name = "auctionmgmt")
public class AuctionMgmt implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	private Long id;

	private Long masternodeid;

	public AuctionMgmt(Long id, Long nodeid) {
		this.id = id;
		this.masternodeid = nodeid;
	}

	public AuctionMgmt() {

	}

	@Id
	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	public Long getMasternodeid() {
		return masternodeid;
	}

	public void setMasternodeid(Long masternodeid) {
		this.masternodeid = masternodeid;
	}

}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service.liveAuction.message;

import java.io.Serializable;

public class StartAuctioneer implements Serializable  {

	private static final long serialVersionUID = 1L;

	private Long auctionId;

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}
	
}
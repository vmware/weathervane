/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.rest.representation;

import java.io.Serializable;

/**
 * @author Hal
 * 
 */
public class NextBidRequestRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;
	
	private Long auctionId;
	private Long itemId;
	private Integer bidCount;
	
	
	public Long getAuctionId() {
		return auctionId;
	}
	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}
	public Long getItemId() {
		return itemId;
	}
	public void setItemId(Long itemId) {
		this.itemId = itemId;
	}
	public Integer getBidCount() {
		return bidCount;
	}
	public void setBidCount(Integer bidCount) {
		this.bidCount = bidCount;
	}
	
	
}

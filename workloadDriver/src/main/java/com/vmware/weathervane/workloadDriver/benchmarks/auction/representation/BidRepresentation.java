/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;
import java.util.Date;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

public class BidRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;
	private static final Logger logger = LoggerFactory.getLogger(BidRepresentation.class);

	public enum BiddingState {OPEN, LASTCALL, SOLD, INFO, AUCTIONCOMPLETE, AUCTIONNOTACTIVE, 
		NOSUCHAUCTION, ITEMNOTACTIVE, NOSUCHITEM, NOSUCHUSER, ACCEPTED, UNKNOWN};

	private String id;
	private Float amount;
	private BiddingState biddingState;
	private Integer lastBidCount;
	private Date bidTime;

	// The number of the node that received this bid
	private Long receivingNode;
	
	// The unique ID of the user placing the bid
	private Long userId;

	// The id of the item on which the bid is placed
	private Long itemId;

	// The id of the auction for which the bid is placed
	private Long auctionId;
	
	private String message;

	public BidRepresentation() {}

	public Float getAmount() {
		return amount;
	}

	public void setAmount(Float amount) {
		this.amount = amount;
	}

	public BiddingState getBiddingState() {
		return biddingState;
	}

	public void setBiddingState(BiddingState biddingState) {
		this.biddingState = biddingState;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

	public Long getUserId() {
		return userId;
	}

	public void setUserId(Long userId) {
		this.userId = userId;
	}

	public Long getItemId() {
		return itemId;
	}

	public void setItemId(Long itemId) {
		this.itemId = itemId;
	}

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}

	public Integer getLastBidCount() {
		return lastBidCount;
	}

	public void setLastBidCount(Integer lastBidCount) {
		this.lastBidCount = lastBidCount;
	}

	public Date getBidTime() {
		return bidTime;
	}

	public void setBidTime(Date bidTime) {
		this.bidTime = bidTime;
	}

	public String getMessage() {
		return message;
	}

	public void setMessage(String message) {
		this.message = message;
	}

	public Long getReceivingNode() {
		return receivingNode;
	}

	public void setReceivingNode(Long receivingNode) {
		this.receivingNode = receivingNode;
	}

	@Override
	public String toString() {
		String bidString;
		
		bidString = "Bid Id: " + id 
				+ " amount : " + amount 
				+ " biddingState : " + biddingState
				+ " lastBidCount : " + lastBidCount
				+ " itemId : " + itemId
				+ " auctionId : " + auctionId;
		
		return bidString;		
	}
	
	@Override
	public boolean equals(Object that) {
		if (that == null) {
			return false;
		}
		
		if (this.getClass() != that.getClass()) {
			return false;
		}

		BidRepresentation thatBiRepresentation = (BidRepresentation) that;
		
		if (this.getId().equals(thatBiRepresentation.getId())) {
			return true;
		} else {
			return false;
		}
		
	}

}

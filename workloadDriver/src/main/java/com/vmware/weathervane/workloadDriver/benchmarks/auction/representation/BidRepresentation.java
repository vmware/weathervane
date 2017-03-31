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

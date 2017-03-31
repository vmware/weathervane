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
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.Date;

import org.springframework.data.annotation.Id;
import org.springframework.data.mongodb.core.index.CompoundIndex;
import org.springframework.data.mongodb.core.index.CompoundIndexes;
import org.springframework.data.mongodb.core.index.Indexed;
import org.springframework.data.mongodb.core.mapping.Document;

@Document
@CompoundIndexes({
	@CompoundIndex(name="bid_bidder_bidTime_idx", def="{'bidderId': 1, 'bidTime': 1 }"),
	@CompoundIndex(name="bid_bidder_id_idx", def="{'bidderId': 1, '_id': 1 }")
})
public class Bid implements Serializable {

	private static final long serialVersionUID = 1L;

	public enum BidState {
		HIGH, PROVISIONALLYHIGH, WINNING, ALREADYHIGHBIDDER, AFTERHIGHER, AFTERMATCHING, BELOWSTARTING, AUCTIONNOTRUNNING, 
		AUCTIONCOMPLETE, NOSUCHAUCTION, NOSUCHITEM, ITEMSOLD, ITEMNOTACTIVE, INSUFFICIENTFUNDS, DUMMY, STARTING, 
		NOSUCHUSER, UNKNOWN
	};

	private String id;
	private Float amount;
	private BidState state;
	private Date bidTime;
	private Integer bidCount;
	
	private Long receivingNode;
	
	// References to other entities
	private Long auctionId;
	
	@Indexed
	private Long itemId;
	
	private Long bidderId;

	public Bid() {

	}

	public Bid(Bid that) {
		this.setId(that.getId());
		this.setAmount(that.getAmount());
		this.setState(that.getState());
		this.setBidTime(that.getBidTime());
		this.setBidCount(that.getBidCount());
		this.setReceivingNode(that.getReceivingNode());
		this.setAuctionId(that.getAuctionId());
		this.setItemId(that.getItemId());
		this.setBidderId(that.getBidderId());
	}
	
	@Id
	public String getId() {
		return id;
	}

	private void setId(String id) {
		this.id = id;
	}

	public Float getAmount() {
		return amount;
	}

	public void setAmount(Float amount) {
		this.amount = amount;
	}

	public BidState getState() {
		return state;
	}

	public void setState(BidState bidState) {
		this.state = bidState;
	}

	public Date getBidTime() {
		return bidTime;
	}

	public void setBidTime(Date bidTime) {
		this.bidTime = bidTime;
	}

	public Long getItemId() {
		return itemId;
	}

	public void setItemId(Long itemId) {
		// defer to the item to connect the two
		this.itemId = itemId;
	}

	public Long getBidderId() {
		return bidderId;
	}

	public void setBidderId(Long bidderId) {
		this.bidderId = bidderId;
	}

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}

	public Integer getBidCount() {
		return bidCount;
	}

	public void setBidCount(Integer bidCount) {
		this.bidCount = bidCount;
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
				+ " state : " + state;
		
		return bidString;		
	}

}

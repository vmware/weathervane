/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.model;

import java.io.Serializable;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;

public class Bid implements Serializable {

	private static final long serialVersionUID = 1L;

	public enum BidState {
		HIGH, PROVISIONALLYHIGH, WINNING, ALREADYHIGHBIDDER, AFTERHIGHER, AFTERMATCHING, BELOWSTARTING, AUCTIONNOTRUNNING, 
		AUCTIONCOMPLETE, NOSUCHAUCTION, NOSUCHITEM, ITEMSOLD, ITEMNOTACTIVE, INSUFFICIENTFUNDS, DUMMY, STARTING, 
		NOSUCHUSER, UNKNOWN
	};
	
	public static class BidKey implements Serializable {
		private static final long serialVersionUID = 1L;

		private Long bidderId;

		private Date bidTime;

		public Date getBidTime() {
			return bidTime;
		}

		public void setBidTime(Date bidTime) {
			this.bidTime = bidTime;
		}

		public Long getBidderId() {
			return bidderId;
		}

		public void setBidderId(Long bidderId) {
			this.bidderId = bidderId;
		}

		@Override
		public int hashCode() {
			return Objects.hash(bidTime, bidderId);
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			BidKey other = (BidKey) obj;
			return Objects.equals(bidTime, other.bidTime) && Objects.equals(bidderId, other.bidderId);
		}
	}
	
	private BidKey key;
	
	private Long itemId;

	private Float amount;
	private BidState state;
	
	private UUID id;
	
	private Integer bidCount;
	
	private Long receivingNode;
	
	private Long auctionId;

	public BidKey getKey() {
		return key;
	}

	public void setKey(BidKey key) {
		this.key = key;
	}

	public Float getAmount() {
		return amount;
	}

	public void setAmount(Float amount) {
		this.amount = amount;
	}

	public UUID getId() {
		return id;
	}

	public void setId(UUID bidId) {
		this.id = bidId;
	}

	public BidState getState() {
		return state;
	}

	public void setState(BidState bidState) {
		this.state = bidState;
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

	public Long getItemId() {
		return itemId;
	}

	public void setItemId(Long itemId) {
		// defer to the item to connect the two
		this.itemId = itemId;
	}

	@Override
	public String toString() {
		String bidString;
		
		bidString = "Bidder Id: " + getKey().getBidderId()
				+ " amount : " + amount 
				+ " state : " + state;
		
		return bidString;		
	}

}

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

import org.springframework.data.cassandra.core.cql.Ordering;
import org.springframework.data.cassandra.core.cql.PrimaryKeyType;
import org.springframework.data.cassandra.core.mapping.Column;
import org.springframework.data.cassandra.core.mapping.PrimaryKey;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.core.mapping.Table;

@Table("bid_by_bidderid")
public class Bid implements Serializable {

	private static final long serialVersionUID = 1L;

	public enum BidState {
		HIGH, PROVISIONALLYHIGH, WINNING, ALREADYHIGHBIDDER, AFTERHIGHER, AFTERMATCHING, BELOWSTARTING, AUCTIONNOTRUNNING, 
		AUCTIONCOMPLETE, NOSUCHAUCTION, NOSUCHITEM, ITEMSOLD, ITEMNOTACTIVE, INSUFFICIENTFUNDS, DUMMY, STARTING, 
		NOSUCHUSER, UNKNOWN
	};
	
	@PrimaryKeyClass
	public static class BidKey {

		@PrimaryKeyColumn(name="bidder_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private Long bidderId;

		@PrimaryKeyColumn(name="bid_time", ordinal= 1, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.ASCENDING)
		private Date bidTime;

		@PrimaryKeyColumn(name="item_id", ordinal= 2, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.ASCENDING)
		private Long itemId;


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

	}
	
	@PrimaryKey
	private BidKey key;
	
	private Float amount;
	private BidState state;
	
	@Column("bid_count")
	private Integer bidCount;
	
	@Column("receiving_node")
	private Long receivingNode;
	
	@Column("auction_id")
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

	@Override
	public String toString() {
		String bidString;
		
		bidString = "Bidder Id: " + getKey().getBidderId()
				+ " amount : " + amount 
				+ " state : " + state;
		
		return bidString;		
	}

}

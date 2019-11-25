/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.representation;

import java.io.Serializable;
import java.util.Date;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.model.Bid;
import com.vmware.weathervane.auction.model.Bid.BidKey;
import com.vmware.weathervane.auction.model.HighBid;

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

	private BidRepresentation() {}

	/**
	 * This is a constructor to create a bidRepresentation from a bid. It
	 * uses the business rules to determine what the allowable next actions are
	 * based on the current state of the auction, item, and bid. It then
	 * includes appropriate links for those actions in the representation.
	 * 
	 * @author hrosenbe
	 */
	public BidRepresentation(Bid theBid, HighBid theHighBid) {
		if (theBid == null) {
			this.setBiddingState(BiddingState.UNKNOWN);
			return;
		}
		BidKey key = theBid.getKey();
		this.setAmount(theBid.getAmount());
		this.setId(theBid.getId().toString());
		this.setMessage(theBid.getState().toString());
		this.setBidTime(key.getBidTime());

		this.setAuctionId(theBid.getAuctionId());
		this.setItemId(theBid.getItemId());
		this.setUserId(key.getBidderId());
		this.setReceivingNode(theBid.getReceivingNode());
		
		if (theHighBid!= null) {
			this.setLastBidCount(theHighBid.getBidCount());
			switch (theHighBid.getState()) {
			case OPEN:
				this.setBiddingState(BiddingState.OPEN);
				break;

			case LASTCALL:
				this.setBiddingState(BiddingState.LASTCALL);
				break;

			case SOLD:
				this.setBiddingState(BiddingState.SOLD);
				break;

			default:
				this.setBiddingState(null);
				break;
			}
		} else {
			this.setLastBidCount(theBid.getBidCount());
			
			switch (theBid.getState()) {
			case HIGH:
			case AFTERHIGHER:
			case AFTERMATCHING:
			case ALREADYHIGHBIDDER:
			case BELOWSTARTING:
			case INSUFFICIENTFUNDS:
			case STARTING:
				this.setBiddingState(BiddingState.OPEN);
				break;
				
			case WINNING:
				this.setBiddingState(BiddingState.SOLD);
				break;

			case AUCTIONCOMPLETE:
				this.setBiddingState(BiddingState.AUCTIONCOMPLETE);
				break;

			case AUCTIONNOTRUNNING:
				this.setBiddingState(BiddingState.AUCTIONNOTACTIVE);
				break;

			case NOSUCHITEM:
				this.setBiddingState(BiddingState.NOSUCHITEM);
				break;

			case ITEMNOTACTIVE:
				this.setBiddingState(BiddingState.ITEMNOTACTIVE);
				break;

			case ITEMSOLD:
				this.setBiddingState(BiddingState.SOLD);
				break;

			case NOSUCHAUCTION:
				this.setBiddingState(BiddingState.NOSUCHAUCTION);
				break;

			case NOSUCHUSER:
				this.setBiddingState(BiddingState.NOSUCHUSER);
				break;

			case DUMMY:
			case UNKNOWN:
				this.setBiddingState(BiddingState.UNKNOWN);
				break;

			default:
				break;
			}
			
		}
		
	}


	/**
	 * This is a constructor to create a bidRepresentation from a HighBid. It
	 * uses the business rules to determine what the allowable next actions are
	 * based on the current state of the highbid. It then
	 * includes appropriate links for those actions in the representation.
	 * 
	 * @author hrosenbe
	 */
	public BidRepresentation(HighBid theHighBid) {
		if (theHighBid == null) {
			this.setBiddingState(BiddingState.UNKNOWN);
			return;
		}
		
		this.setId(theHighBid.getBidId().toString());
		this.setAmount(theHighBid.getAmount());
		this.setLastBidCount(theHighBid.getBidCount());
		this.setBidTime(theHighBid.getCurrentBidTime());
		this.setMessage(theHighBid.getState().toString());
		this.setReceivingNode(-1L);

		this.setAuctionId(theHighBid.getAuctionId());			
		this.setItemId(theHighBid.getItemId());
		this.setUserId(theHighBid.getBidderId());

		logger.debug("BidRepresentation(HighBid theHighBid): auctionId = " + auctionId + 
				", itemId = " + itemId + ", userId =  " + userId);
		
		switch (theHighBid.getState()) {
		case OPEN:
			this.setBiddingState(BiddingState.OPEN);
			break;

		case LASTCALL:
			this.setBiddingState(BiddingState.LASTCALL);
			break;

		case SOLD:
			this.setBiddingState(BiddingState.SOLD);
			break;

		default:
			this.setBiddingState(null);
			break;
		}
		
	}


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

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.representation;

import java.io.Serializable;
import java.text.DateFormat;
import java.util.Date;

import com.vmware.weathervane.auction.model.Auction;
import com.vmware.weathervane.auction.model.Auction.AuctionState;

public class AuctionRepresentation extends Representation implements Serializable {
	
	private static final long serialVersionUID = 1L;
	
	private Long id;
	private String name;
	private String category;
	private String startDate;
	private String startTime;
	private Date startTimeDate;
	private Auction.AuctionState state;

	
	/*
	 * Only create an auction representation with the constructor that understands 
	 * the business rules.
	 */
	private AuctionRepresentation() {}
	
	public  AuctionRepresentation(Long auctionId) {

		this.setState(AuctionState.INVALID);
		
		this.setId(auctionId);
	}
	
	public  AuctionRepresentation(Auction theAuction) {

			if (theAuction == null) {
				this.setState(AuctionState.NOSUCHAUCTION);
				return;
			}
			
			this.setId(theAuction.getId());
		this.setCategory(theAuction.getCategory());
		this.setName(theAuction.getName());
		this.setStartTime(DateFormat.getTimeInstance(DateFormat.LONG).format(theAuction.getStartTime()));
		this.setStartDate(DateFormat.getDateInstance(DateFormat.LONG).format(theAuction.getStartTime()));
		this.setStartTimeDate(theAuction.getStartTime());
		/*
		 * ToDo: This is where the links should be returned. Right now am
		 * just returning a state in the LiveBid.
		 */
		this.setState(theAuction.getState());
		
	}
	
	public Long getId() {
		return id;
	}
	public void setId(Long id) {
		this.id = id;
	}
	public String getName() {
		return name;
	}
	public void setName(String name) {
		this.name = name;
	}
	public String getStartDate() {
		return startDate;
	}

	public void setStartDate(String startDate) {
		this.startDate = startDate;
	}

	public String getStartTime() {
		return startTime;
	}
	public void setStartTime(String startTime) {
		this.startTime = startTime;
	}
	public String getCategory() {
		return category;
	}
	public void setCategory(String category) {
		this.category = category;
	}


	public Auction.AuctionState getState() {
		return state;
	}

	public void setState(Auction.AuctionState state) {
		this.state = state;
	}

	public Date getStartTimeDate() {
		return startTimeDate;
	}

	public void setStartTimeDate(Date startDate) {
		this.startTimeDate = startDate;
	}	

}

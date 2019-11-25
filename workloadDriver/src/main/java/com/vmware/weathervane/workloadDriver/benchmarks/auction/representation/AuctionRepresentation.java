/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;
import java.util.Date;

public class AuctionRepresentation extends Representation implements Serializable {
	
	private static final long serialVersionUID = 1L;

	public enum AuctionState {
		FUTURE, PENDING, RUNNING, COMPLETE, INVALID, NOSUCHAUCTION
	};

	private Long id;
	private String name;
	private String category;
	private String startDate;
	private String startTime;
	private Date startTimeDate;
	private AuctionState state;
	
	public AuctionRepresentation() {}
	
	public  AuctionRepresentation(Long auctionId) {

		this.setState(AuctionState.INVALID);
		
		this.setId(auctionId);
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


	public AuctionState getState() {
		return state;
	}

	public void setState(AuctionState state) {
		this.state = state;
	}

	public Date getStartTimeDate() {
		return startTimeDate;
	}

	public void setStartTimeDate(Date startDate) {
		this.startTimeDate = startDate;
	}	

}

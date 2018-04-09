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
package com.vmware.weathervane.auction.model;

import java.io.Serializable;
import java.text.DateFormat;
import java.util.Date;
import java.util.HashSet;
import java.util.Set;

public class Auction implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	public enum AuctionState {
		FUTURE, PENDING, RUNNING, COMPLETE, INVALID, NOSUCHAUCTION
	};

	private Long id;
	private AuctionState state;
	private String name;
	private String category;
	private Date startTime;
	private Date endTime;

	// References to other entities
	private User auctioneer;

	private Set<Item> items = new HashSet<Item>();
	private Set<Keyword> keywords = new HashSet<Keyword>();
	
	private Integer version;

	/*
	 * These flags exists to provide information that simplifies
	 * preloading and preparing benchmark runs.  It is not used by 
	 * the Auction application
	 */
	private boolean current;
	private boolean activated;
	
	public Auction() {

	}

	public Long getId() {
		return id;
	}

	private void setId(Long id) {
		this.id = id;
	}

	public AuctionState getState() {
		return state;
	}

	public void setState(AuctionState state) {
		this.state = state;
	}

	public String getName() {
		return name;
	}

	public void setName(String name) {
		this.name = name;
	}

	public String getCategory() {
		return category;
	}

	public void setCategory(String category) {
		this.category = category;
	}

	public Date getStartTime() {
		return startTime;
	}

	public void setStartTime(Date startTime) {
		this.startTime = startTime;
	}

	public Date getEndTime() {
		return endTime;
	}

	public void setEndTime(Date endTime) {
		this.endTime = endTime;
	}

	public Set<Item> getItems() {
		return items;
	}

	public void setItems(Set<Item> items) {
		this.items = items;
	}

	public Set<Keyword> getKeywords() {
		return keywords;
	}

	private void setKeywords(Set<Keyword> keywords) {
		this.keywords = keywords;
	}
	
	public void addKeyword(Keyword keyword) {
		this.keywords.add(keyword);
	}

	public User getAuctioneer() {
		return auctioneer;
	}

	public void setAuctioneer(User auctioneer) {
		this.auctioneer = auctioneer;
	}

	public Integer getVersion() {
		return version;
	}

	public void setVersion(Integer version) {
		this.version = version;
	}

	public boolean addItemToAuction(Item item) {
		item.setAuction(this);
		return this.getItems().add(item);
	}

	public boolean isCurrent() {
		return current;
	}

	public void setCurrent(boolean current) {
		this.current = current;
	}

	public boolean isActivated() {
		return activated;
	}

	public void setActivated(boolean activated) {
		this.activated = activated;
	}

	@Override
	public String toString() {
		String theString = "Auction name: " + name + " : Auction State: " + state
				+ " : Id: " + id + " : Category: " + category.toString()
				+ " : Start Time: " + DateFormat.getDateTimeInstance().format(startTime);

		return theString;
	}
	
}

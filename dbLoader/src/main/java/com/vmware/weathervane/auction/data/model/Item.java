/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.Date;

import javax.persistence.CascadeType;
import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.EnumType;
import javax.persistence.Enumerated;
import javax.persistence.FetchType;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.ManyToOne;
import javax.persistence.OneToOne;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

@Entity
@Table(name="item")
public class Item implements Serializable,DomainObject {

	private static final long serialVersionUID = 1L;
	public enum ItemState {NOTLISTED, INAUCTION, ACTIVE, SOLD, PAID, SHIPPED, NOSUCHITEM};

	private Long id;
	private String shortDescription;
	private String longDescription;
	private String manufacturer;
	private Float startingBidAmount;
	private ItemState state;
	private Condition condition;
	private Date dateOfOrigin;
	
	// References to other entities
	private Auction auction;
	private User auctioneer;
	private HighBid highbid;

	/*
	 * These flags exists to provide information that simplifies
	 * preloading and prepare benchmark runs.  It is not used by 
	 * the Auction application
	 */
	private boolean preloaded;

	private Integer version;
	
	public Item() {
		
	}

	@Id
	@GeneratedValue(strategy=GenerationType.TABLE)
	public Long getId() {
		return id;
	}

	public void setId(Long id) {
		this.id = id;
	}

	@Column(name="shortdescription")
	public String getShortDescription() {
		return shortDescription;
	}

	public void setShortDescription(String name) {
		this.shortDescription = name;
	}

	@Column(name="longdescription")
	public String getLongDescription() {
		return longDescription;
	}

	public void setLongDescription(String name) {
		this.longDescription = name;
	}

	public String getManufacturer() {
		return manufacturer;
	}

	public void setManufacturer(String manufacturer) {
		this.manufacturer = manufacturer;
	}

//	public Condition getCondition() {
//		return condition;
//	}
//
//	public void setCondition(Condition condition) {
//		this.condition = condition;
//	}

	@Column(name="startingbidamount")
	public Float getStartingBidAmount() {
		return startingBidAmount;
	}

	public void setStartingBidAmount(Float startingBidAmount) {
		this.startingBidAmount = startingBidAmount;
	}

	@Enumerated(EnumType.STRING)
	public ItemState getState() {
		return state;
	}

	public void setState(ItemState state) {
		this.state = state;
	}

	@ManyToOne
	public Auction getAuction() {
		return auction;
	}

	public void setAuction(Auction auction) {
		this.auction = auction;
	}

	@OneToOne(cascade = { javax.persistence.CascadeType.PERSIST, CascadeType.REFRESH, CascadeType.MERGE },fetch=FetchType.LAZY)
	public User getAuctioneer() {
		return auctioneer;
	}

	public void setAuctioneer(User auctioneer) {
		this.auctioneer = auctioneer;
	}

	@OneToOne(cascade = {CascadeType.ALL},fetch=FetchType.EAGER)
	public HighBid getHighbid() {
		return highbid;
	}
	public void setHighbid(HighBid highBid) {
		this.highbid = highBid;
	}

	@Temporal(TemporalType.DATE)
	@Column(name="dateoforigin")
	public Date getDateOfOrigin() {
		return dateOfOrigin;
	}

	public void setDateOfOrigin(Date origin) {
		this.dateOfOrigin = origin;
	}

	@Enumerated(EnumType.STRING)
	@Column(name="cond")
	public Condition getCondition() {
		return condition;
	}

	public void setCondition(Condition condition) {
		this.condition = condition;
	}
	
	@Version
	public Integer getVersion() {
		return version;
	}
	public void setVersion(Integer version) {
		this.version = version;
	}
	
	@Override
	public String toString() {
		String itemString;
		itemString = "Item Id: " + id 
				+ " Item Name: " + shortDescription 
				+ " Manufacturer: " + manufacturer;
		
		return itemString;		
	}

	public boolean isPreloaded() {
		return preloaded;
	}

	public void setPreloaded(boolean preloaded) {
		this.preloaded = preloaded;
	}
	
}

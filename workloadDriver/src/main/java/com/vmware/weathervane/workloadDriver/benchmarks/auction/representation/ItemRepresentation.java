/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.workloadDriver.benchmarks.auction.representation;

import java.io.Serializable;
import java.util.Date;

public class ItemRepresentation extends Representation implements Serializable {

	private static final long serialVersionUID = 1L;
	public enum ItemState {NOTLISTED, INAUCTION, ACTIVE, SOLD, PAID, SHIPPED, NOSUCHITEM};
	public enum Condition {
		New, Excellent, VeryGood, Good, Fair, Poor, Bad
	}

	private Long id;
	private String name;
	private String manufacturer;
	private Long auctionId;

	private ItemState state;
	private Date biddingEndTime;
	private Float purchasePrice;

	private String longDescription;
	private Float startingBidAmount;
	private Condition condition;
	private Date dateOfOrigin;
	private Integer bidCount;
	
	public ItemRepresentation() {
	}

	public ItemRepresentation(Long itemId) {
			this.id = itemId;
			this.state = ItemState.NOSUCHITEM;
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

	public String getManufacturer() {
		return manufacturer;
	}

	public void setManufacturer(String manufacturer) {
		this.manufacturer = manufacturer;
	}

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}

	public ItemState getState() {
		return state;
	}

	public void setState(ItemState state) {
		this.state = state;
	}

	public Date getBiddingEndTime() {
		return biddingEndTime;
	}

	public void setBiddingEndTime(Date biddingEndTimeDate) {
		this.biddingEndTime = biddingEndTimeDate;
	}

	public Float getPurchasePrice() {
		return purchasePrice;
	}

	public void setPurchasePrice(Float purchasePrice) {
		this.purchasePrice = purchasePrice;
	}

	public String getLongDescription() {
		return longDescription;
	}

	public void setLongDescription(String longDescription) {
		this.longDescription = longDescription;
	}

	public Float getStartingBidAmount() {
		return startingBidAmount;
	}

	public void setStartingBidAmount(Float startingBidAmount) {
		this.startingBidAmount = startingBidAmount;
	}

	public Condition getCondition() {
		return condition;
	}

	public void setCondition(Condition condition) {
		this.condition = condition;
	}

	public Date getDateOfOrigin() {
		return dateOfOrigin;
	}

	public void setDateOfOrigin(Date dateOfOrigin) {
		this.dateOfOrigin = dateOfOrigin;
	}

	public Integer getBidCount() {
		return bidCount;
	}

	public void setBidCount(Integer bidCount) {
		this.bidCount = bidCount;
	}

	@Override
	public String toString() {
		String itemString;

		itemString = "Item Id: " + id + " Item Name: " + name + " Manufacturer: " + manufacturer;

		return itemString;
	}

}

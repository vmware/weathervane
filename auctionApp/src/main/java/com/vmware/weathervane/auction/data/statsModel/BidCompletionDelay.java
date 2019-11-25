/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.statsModel;

import java.io.Serializable;
import java.util.Date;
import java.util.UUID;

import javax.persistence.Column;
import javax.persistence.Entity;
import javax.persistence.GeneratedValue;
import javax.persistence.GenerationType;
import javax.persistence.Id;
import javax.persistence.ManyToOne;
import javax.persistence.Table;
import javax.persistence.Temporal;
import javax.persistence.TemporalType;
import javax.persistence.Version;

import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.DomainObject;
import com.vmware.weathervane.auction.data.model.Item;

@Entity
@Table(name="bidcompletiondelay")
public class BidCompletionDelay implements Serializable, DomainObject {

	private static final long serialVersionUID = 1L;

	private Long id;
	private Long delay;
	private String host;
	private Long numCompletedBids;
	private Date timestamp;
	private String biddingState;
	
	private Date bidTime;
	private Long receivingNode;
	private Long completingNode;
	
	// References to other entities
	private UUID bidId;
	private Auction auction;
	private Item item;

	private Integer version;

	public BidCompletionDelay() {

	}

	@Id
	@GeneratedValue(strategy=GenerationType.TABLE)
	public Long getId() {
		return id;
	}

	private void setId(Long id) {
		this.id = id;
	}

	public Long getDelay() {
		return delay;
	}

	public void setDelay(Long delay) {
		this.delay = delay;
	}

	public String getHost() {
		return host;
	}

	public void setHost(String host) {
		this.host = host;
	}

	@Column(name="numcompletedbids")
	public Long getNumCompletedBids() {
		return numCompletedBids;
	}

	public void setNumCompletedBids(Long numCompletedBids) {
		this.numCompletedBids = numCompletedBids;
	}

	@Version
	public Integer getVersion() {
		return version;
	}

	public void setVersion(Integer version) {
		this.version = version;
	}

	@Column(name="bidid")
	public UUID getBidId() {
		return bidId;
	}

	public void setBidId(UUID bidId) {
		this.bidId = bidId;
	}

	@Temporal(TemporalType.TIMESTAMP)
	public Date getTimestamp() {
		return timestamp;
	}

	public void setTimestamp(Date timestamp) {
		this.timestamp = timestamp;
	}

	@ManyToOne
	public Auction getAuction() {
		return auction;
	}

	public void setAuction(Auction auction) {
		this.auction = auction;
	}

	@ManyToOne
	public Item getItem() {
		return item;
	}

	public void setItem(Item item) {
		this.item = item;
	}

	@Column(name="biddingstate")
	public String getBiddingState() {
		return biddingState;
	}

	public void setBiddingState(String biddingState) {
		this.biddingState = biddingState;
	}

	@Column(name="bidtime")
	public Date getBidTime() {
		return bidTime;
	}

	public void setBidTime(Date bidTime) {
		this.bidTime = bidTime;
	}

	@Column(name="receivingnode")
	public Long getReceivingNode() {
		return receivingNode;
	}

	public void setReceivingNode(Long receivingNode) {
		this.receivingNode = receivingNode;
	}

	@Column(name="completingnode")
	public Long getCompletingNode() {
		return completingNode;
	}

	public void setCompletingNode(Long completingNode) {
		this.completingNode = completingNode;
	}

}

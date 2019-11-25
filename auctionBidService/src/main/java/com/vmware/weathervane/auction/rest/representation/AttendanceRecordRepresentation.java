/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.rest.representation;

import java.io.Serializable;
import java.util.Date;

import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordKey;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordState;
import com.vmware.weathervane.auction.rest.representation.Representation;

/**
 * @author Hal
 * 
 */
public class AttendanceRecordRepresentation extends Representation implements Serializable {

	/**
	 * 
	 */
	private static final long serialVersionUID = 1L;

	private String id;
	private Date timestamp;

	private AttendanceRecordState state;
	private String auctionName;

	// References to other entities
	private Long auctionId;
	private Long userId;

	public AttendanceRecordRepresentation() {

	}

	public AttendanceRecordRepresentation(AttendanceRecord theRecord) {
		if (theRecord == null) {
			this.setState(AttendanceRecord.AttendanceRecordState.BADRECORD);
			return;
		}

		AttendanceRecordKey key = theRecord.getKey();
		this.id = theRecord.getId().toString();
		this.timestamp = key.getTimestamp();
		this.state = theRecord.getState();
		this.auctionId = theRecord.getAuctionId();
		this.userId = key.getUserId();
		this.auctionName = theRecord.getAuctionName();

	}

	public Date getTimestamp() {
		return timestamp;
	}

	public void setTimestamp(Date timestamp) {
		this.timestamp = timestamp;
	}

	public AttendanceRecordState getState() {
		return state;
	}

	public void setState(AttendanceRecordState state) {
		this.state = state;
	}

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}

	public Long getUserId() {
		return userId;
	}

	public void setUserId(Long userId) {
		this.userId = userId;
	}

	public String getAuctionName() {
		return auctionName;
	}

	public void setAuctionName(String auctionName) {
		this.auctionName = auctionName;
	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
	}

}

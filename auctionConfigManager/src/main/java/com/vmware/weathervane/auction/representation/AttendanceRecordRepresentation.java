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
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.representation;

import java.io.Serializable;
import java.util.Date;

import com.vmware.weathervane.auction.model.AttendanceRecord;
import com.vmware.weathervane.auction.model.AttendanceRecord.AttendanceRecordState;
import com.vmware.weathervane.auction.representation.Representation;

/**
 * @author Hal
 * 
 */
public class AttendanceRecordRepresentation extends Representation implements Serializable {

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

		this.id = theRecord.getId();
		this.timestamp = theRecord.getTimestamp();
		this.state = theRecord.getState();
		this.auctionId = theRecord.getAuctionId();
		this.userId = theRecord.getUserId();
		this.auctionName = theRecord.getAuctionName();

		/*
		 * ToDo: This is where the links should be returned. Right now am just
		 * returning a state in the LiveBid.
		 */
		this.setState(theRecord.getState());

	}

	public String getId() {
		return id;
	}

	public void setId(String id) {
		this.id = id;
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

}

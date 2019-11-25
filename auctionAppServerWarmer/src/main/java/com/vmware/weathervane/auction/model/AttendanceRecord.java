/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.model;

import java.io.Serializable;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;

public class AttendanceRecord implements Serializable {

	private static final long serialVersionUID = 1L;
	public enum AttendanceRecordState {ATTENDING, LEFT, AUCTIONCOMPLETE, BADRECORD};

	public static class AttendanceRecordKey implements Serializable {
		private static final long serialVersionUID = 1L;

		private Long userId;

		private Date timestamp;

		@Override
		public int hashCode() {
			return Objects.hash(timestamp, userId);
		}

		@Override
		public boolean equals(Object obj) {
			if (this == obj)
				return true;
			if (obj == null)
				return false;
			if (getClass() != obj.getClass())
				return false;
			AttendanceRecordKey other = (AttendanceRecordKey) obj;
			return Objects.equals(timestamp, other.timestamp) && Objects.equals(userId, other.userId);
		}

		public Date getTimestamp() {
			return timestamp;
		}

		public void setTimestamp(Date timestamp) {
			this.timestamp = timestamp;
		}

		public Long getUserId() {
			return userId;
		}

		public void setUserId(Long userId) {
			this.userId = userId;
		}

	}

	private AttendanceRecordKey key;
	
	private UUID id;
	
	private Long auctionId;

	private AttendanceRecordState state;
	
	private String auctionName;
	
	public AttendanceRecord() {
	}	

	public AttendanceRecordState getState() {
		return state;
	}

	public void setState(AttendanceRecordState state) {
		this.state = state;
	}

	public String getAuctionName() {
		return auctionName;
	}

	public void setAuctionName(String auctionName) {
		this.auctionName = auctionName;
	}

	public AttendanceRecordKey getKey() {
		return key;
	}

	public void setKey(AttendanceRecordKey key) {
		this.key = key;
	}

	public UUID getId() {
		return id;
	}

	public void setId(UUID id) {
		this.id = id;
	}

	public Long getAuctionId() {
		return auctionId;
	}

	public void setAuctionId(Long auctionId) {
		this.auctionId = auctionId;
	}

}

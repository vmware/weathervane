/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.Date;
import java.util.Objects;
import java.util.UUID;

import org.springframework.cassandra.core.Ordering;
import org.springframework.cassandra.core.PrimaryKeyType;
import org.springframework.data.cassandra.mapping.Column;
import org.springframework.data.cassandra.mapping.PrimaryKey;
import org.springframework.data.cassandra.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.mapping.Table;

@Table("attendancerecord_by_userid")
public class AttendanceRecord implements Serializable {

	private static final long serialVersionUID = 1L;
	public enum AttendanceRecordState {ATTENDING, LEFT, AUCTIONCOMPLETE, BADRECORD};

	@PrimaryKeyClass
	public static class AttendanceRecordKey implements Serializable {
		private static final long serialVersionUID = 1L;

		@PrimaryKeyColumn(name="user_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private Long userId;

		@PrimaryKeyColumn(name="record_time", ordinal= 1, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.ASCENDING)
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

	@PrimaryKey
	private AttendanceRecordKey key;
	
	private UUID id;
	
	@Column("auction_id")
	private Long auctionId;

	private AttendanceRecordState state;
	
	@Column("auction_name")
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

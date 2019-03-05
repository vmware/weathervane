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
package com.vmware.weathervane.auction.data.model;

import java.io.Serializable;
import java.util.Date;

import org.springframework.data.cassandra.core.cql.Ordering;
import org.springframework.data.cassandra.core.cql.PrimaryKeyType;
import org.springframework.data.cassandra.core.mapping.PrimaryKey;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyClass;
import org.springframework.data.cassandra.core.mapping.PrimaryKeyColumn;
import org.springframework.data.cassandra.core.mapping.Table;

@Table("attendancerecord_by_userid")
public class AttendanceRecord implements Serializable {

	private static final long serialVersionUID = 1L;
	public enum AttendanceRecordState {ATTENDING, LEFT, AUCTIONCOMPLETE, BADRECORD};

	@PrimaryKeyClass
	public static class AttendanceRecordKey {

		@PrimaryKeyColumn(name="user_id", ordinal= 0, type=PrimaryKeyType.PARTITIONED)
		private Long userId;

		@PrimaryKeyColumn(name="timestamp", ordinal= 1, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.ASCENDING)
		private Date timestamp;

		@PrimaryKeyColumn(name="auction_id", ordinal= 2, type=PrimaryKeyType.CLUSTERED, ordering=Ordering.ASCENDING)
		private Long auctionId;

		@Override
		public int hashCode() {
			final int prime = 31;
			int result = 1;
			result = prime * result + ((auctionId == null) ? 0 : auctionId.hashCode());
			result = prime * result + ((timestamp == null) ? 0 : timestamp.hashCode());
			result = prime * result + ((userId == null) ? 0 : userId.hashCode());
			return result;
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
			if (auctionId == null) {
				if (other.auctionId != null)
					return false;
			} else if (!auctionId.equals(other.auctionId))
				return false;
			if (timestamp == null) {
				if (other.timestamp != null)
					return false;
			} else if (!timestamp.equals(other.timestamp))
				return false;
			if (userId == null) {
				if (other.userId != null)
					return false;
			} else if (!userId.equals(other.userId))
				return false;
			return true;
		}

		public Date getTimestamp() {
			return timestamp;
		}

		public void setTimestamp(Date timestamp) {
			this.timestamp = timestamp;
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

	}

	@PrimaryKey
	private AttendanceRecordKey key;
	
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
	
}

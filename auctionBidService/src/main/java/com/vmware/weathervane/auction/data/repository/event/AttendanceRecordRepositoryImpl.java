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
package com.vmware.weathervane.auction.data.repository.event;

import static com.datastax.driver.core.querybuilder.QueryBuilder.eq;
import static com.datastax.driver.core.querybuilder.QueryBuilder.set;
import static com.datastax.driver.core.querybuilder.QueryBuilder.update;

import java.util.Date;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.BuiltStatement;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordState;

public class AttendanceRecordRepositoryImpl implements AttendanceRecordRepositoryCustom {

	@Autowired
	@Qualifier("cassandraEventTemplate")
	CassandraOperations cassandraOperations;
	
	@Override
	public void updateLastActiveTime(Long auctionId, Long userId, Date time) {
		BuiltStatement update = update("attendancerecord_by_userid")
				.with(set("record_time", time))
				.where(eq("auction_id", auctionId)).and(eq("user_id", userId));
		cassandraOperations.execute(update);
	}

	@Override
	public void leaveAuctionsForUser(Long userId) {
		BuiltStatement update = update("attendancerecord_by_userid")
				.with(set("state", AttendanceRecordState.LEFT))
				.where(eq("state", AttendanceRecordState.ATTENDING)).and(eq("user_id", userId));
		cassandraOperations.execute(update);

	}

	@Override
	public void leaveAuctionForUser(Long auctionId, Long userId, Date time) {
		BuiltStatement update = update("attendancerecord_by_userid")
				.with(set("record_time", time))
				.and(set("state", AttendanceRecordState.LEFT))
				.where(eq("auction_id", auctionId)).and(eq("user_id", userId));
		cassandraOperations.execute(update);

	}

	@Override
	public void deleteByAuctionId(Long auctionId) {
		String cql = "DELETE FROM attendancerecord_by_userid WHERE auction_id = " + auctionId + ";";
		cassandraOperations.execute(cql);
	}
}

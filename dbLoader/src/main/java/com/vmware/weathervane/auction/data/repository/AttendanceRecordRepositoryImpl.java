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
package com.vmware.weathervane.auction.data.repository;

import static org.springframework.data.mongodb.core.query.Criteria.where;
import static org.springframework.data.mongodb.core.query.Update.update;

import java.util.Collection;
import java.util.Date;

import javax.inject.Inject;
import javax.inject.Named;

import org.springframework.data.mongodb.core.MongoOperations;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.data.mongodb.core.query.Update;

import com.vmware.weathervane.auction.data.model.AttendanceRecord;
import com.vmware.weathervane.auction.data.model.AttendanceRecord.AttendanceRecordState;

public class AttendanceRecordRepositoryImpl implements AttendanceRecordRepositoryCustom {

	@Inject
	@Named("attendanceRecordMongoTemplate")
	MongoOperations attendanceRecordMongoTemplate;
	
	@Override
	public void updateLastActiveTime(Long auctionId, Long userId, Date time) {
		Query query = new Query(where("auctionId").is(auctionId).and("userId").is(userId));
		attendanceRecordMongoTemplate.updateFirst(query, update("lastActiveTime", time), AttendanceRecord.class);
	}

	@Override
	public void deleteByAuctionId(Long auctionId) {
		Query query = new Query(where("auctionId").is(auctionId));
		attendanceRecordMongoTemplate.remove(query, AttendanceRecord.class);		
	}

	@Override
	public void insertBatch(Collection<AttendanceRecord> attendanceRecords) {
		attendanceRecordMongoTemplate.insert(attendanceRecords, AttendanceRecord.class);		
	}

	@Override
	public void leaveAuctionsForUser(Long userId) {
		Query query = new Query(where("userId").is(userId).and("state").is(AttendanceRecordState.ATTENDING));
		attendanceRecordMongoTemplate.updateMulti(query, update("state", AttendanceRecordState.LEFT), AttendanceRecord.class);
	}

	@Override
	public void leaveAuctionForUser(Long auctionId, Long userId, Date time) {
		Query query = new Query(where("userId").is(userId).and("auctionId").is(auctionId));
		Update theUpdate = new Update();
		theUpdate.set("state", AttendanceRecordState.LEFT);
		theUpdate.set("lastActiveTime", time);
		
		attendanceRecordMongoTemplate.updateMulti(query, theUpdate, AttendanceRecord.class);		
	}

	@Override
	public AttendanceRecord findOneByAuctionIdAndUserId(Long auctionId, Long userId) {
		Query query = new Query(where("userId").is(userId).and("auctionId").is(auctionId));
		return attendanceRecordMongoTemplate.findOne(query, AttendanceRecord.class);
	}

}

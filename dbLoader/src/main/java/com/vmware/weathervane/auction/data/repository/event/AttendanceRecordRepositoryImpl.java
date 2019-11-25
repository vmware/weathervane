/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import static com.datastax.driver.core.querybuilder.QueryBuilder.delete;
import static com.datastax.driver.core.querybuilder.QueryBuilder.eq;

import java.util.List;
import java.util.function.Consumer;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.BuiltStatement;

public class AttendanceRecordRepositoryImpl implements AttendanceRecordRepositoryCustom {

	@Autowired
	@Qualifier("cassandraEventTemplate")
	CassandraOperations cassandraOperations;
	
	@Override
	public void deleteByAuctionId(Long auctionId) {
		
		List<Long> userIds = 
				cassandraOperations.select("select user_id from attendancerecord_by_userid WHERE auction_id = " + auctionId + ";", Long.class);
		
		userIds.parallelStream().forEach(
				new Consumer<Long>() {

					@Override
					public void accept(Long t) {
						BuiltStatement delete = delete().from("attendancerecord_by_userid").where(eq("user_id", t));
						cassandraOperations.execute(delete);						
					}
				});
	}
}

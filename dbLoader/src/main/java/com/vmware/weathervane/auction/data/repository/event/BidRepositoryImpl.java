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

public class BidRepositoryImpl implements BidRepositoryCustom {

	@Autowired
	@Qualifier("cassandraEventTemplate")
	CassandraOperations cassandraOperations;

	@Override
	public void deleteByItemId(Long itemId) {
		
		List<Long> bidderIds = 
				cassandraOperations.select("select bidder_id from bid_by_bidderid WHERE item_id = " + itemId + ";", Long.class);
		
		bidderIds.parallelStream().forEach(
				new Consumer<Long>() {

					@Override
					public void accept(Long t) {
						BuiltStatement delete = delete().from("bid_by_bidderid").where(eq("bidder_id", t));
						cassandraOperations.execute(delete);						
					}
				});

	}

}

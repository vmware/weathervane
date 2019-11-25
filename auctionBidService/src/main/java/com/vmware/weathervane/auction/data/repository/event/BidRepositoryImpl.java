/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import static com.datastax.driver.core.querybuilder.QueryBuilder.delete;
import static com.datastax.driver.core.querybuilder.QueryBuilder.eq;

import java.text.DateFormat;
import java.text.SimpleDateFormat;
import java.util.Date;
import java.util.List;
import java.util.function.Consumer;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.data.cassandra.core.CassandraOperations;

import com.datastax.driver.core.querybuilder.BuiltStatement;
import com.vmware.weathervane.auction.data.model.Bid;

public class BidRepositoryImpl implements BidRepositoryCustom {

	@Autowired
	@Qualifier("cassandraEventTemplate")
	CassandraOperations cassandraOperations;

	private DateFormat dateFormat; 

	public BidRepositoryImpl() {
		super();

		String datePattern = "yyyy-MM-dd";
		dateFormat = new SimpleDateFormat(datePattern); 
	}

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

	@Override
	public List<Bid> findByBidderId(Long bidderId) {
		String selectString = "select * from bid_by_bidderid where bidder_id = " + bidderId;
		return cassandraOperations.select(selectString, Bid.class);
	}

	@Override
	public List<Bid> findByBidderIdAndBidTimeLessThanEqual(Long bidderId, Date toDate) {
		String selectString = "select * from bid_by_bidderid where bidder_id = " + bidderId;
		selectString += " and bid_time <= " + dateFormat.format(toDate);
		return cassandraOperations.select(selectString, Bid.class);
	}

	@Override
	public List<Bid> findByBidderIdAndBidTimeGreaterThanEqual(Long bidderId, Date fromDate) {
		String selectString = "select * from bid_by_bidderid where bidder_id = " + bidderId;
		selectString += " and bid_time >= " + dateFormat.format(fromDate);
		return cassandraOperations.select(selectString, Bid.class);
	}

	@Override
	public List<Bid> findByBidderIdAndBidTimeBetween(Long bidderId, Date fromDate, Date toDate) {
		String selectString = "select * from bid_by_bidderid where bidder_id = " + bidderId;
		selectString += " and bid_time <= " + dateFormat.format(toDate);
		selectString += " and bid_time >= " + dateFormat.format(fromDate);
		return cassandraOperations.select(selectString, Bid.class);
	}

}

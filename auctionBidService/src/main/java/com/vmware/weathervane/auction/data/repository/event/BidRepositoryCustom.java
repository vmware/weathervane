/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.repository.event;

import java.util.Date;
import java.util.List;

import com.vmware.weathervane.auction.data.model.Bid;

public interface BidRepositoryCustom {	
	void deleteByItemId(Long itemId);

	List<Bid> findByBidderId(Long bidderId);
	
	List<Bid> findByBidderIdAndBidTimeLessThanEqual(Long bidderId, Date toDate);	

	List<Bid> findByBidderIdAndBidTimeGreaterThanEqual(Long bidderId, Date fromDate);	

	List<Bid> findByBidderIdAndBidTimeBetween(Long bidderId, Date fromDate, Date toDate);	
}

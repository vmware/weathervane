/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.Date;
import java.util.List;

import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.Item;

public interface HighBidDao extends GenericDao<HighBid, Long> {
	
	int deleteByPreloaded(Boolean preloaded);

	List<HighBid> getActiveHighBids();
	
	HighBid findByAuctionIdAndItemId(Long auctionId, Long itemId);
	
	List<Item> getPurchasedItemsPageForUser(Long userId, Integer page,
			Integer pageSize);
	
	List<Item> getPurchasedItemsPageForUserFromDate(Long userId, Date fromDate, Integer page,
			Integer pageSize);
	
	List<Item> getPurchasedItemsPageForUserToDate(Long userId, Date toDate, Integer page,
			Integer pageSize);
	
	List<Item> getPurchasedItemsPageForUserFromDateToDate(Long userId, Date fromDate, Date toDate, Integer page,
			Integer pageSize);

	Long getPurchasedItemCountforUser(Long userId);

	HighBid findByAuctionIdAndItemIdForUpdate(Long auctionId, Long itemId);

	HighBid findByItemIdForUpdate(Long itemId);

	HighBid findByItemId(Long itemId);

	HighBid getActiveHighBid(Long auctionId);

	List<HighBid> findByAuctionId(Long auctionId);

}

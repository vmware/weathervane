/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.data.dao;

import java.util.List;

import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.User;

public interface ItemDao extends GenericDao<Item, Long> {
	
	Item addItemForAuctioneer(Item anItem, Long userId);

	User getAuctioneer(Long id);

	Item updateItem(Item updateItem);

	Long getItemCountForAuctioneer(long userId);

	List<Item> getItemsPageForAuctioneer(long userId, Integer realPage, Integer realPageSize);
	
	int deleteByPreloaded(boolean preloaded);
}

/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.io.IOException;
import java.util.Date;
import java.util.List;
import java.util.UUID;

import com.vmware.weathervane.auction.data.imageStore.ImageQueueFullException;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ImageInfoRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;

public interface ItemService {

	public ItemRepresentation getItem(Long itemId);

	public CollectionRepresentation<ItemRepresentation> getItems(Long auctionId, Integer page, Integer pageSize);

	public CollectionRepresentation<ItemRepresentation> getPurchasedItemsForUser(long userId, Date fromDate, Date toDate, Integer page, Integer pageSize);

	public ItemRepresentation addItem(ItemRepresentation theItem, Long userId);

	public User getAuctioneerForItem(ItemRepresentation theItem);

	public ItemRepresentation updateItem(ItemRepresentation theItem);

	CollectionRepresentation<ItemRepresentation> getItemsForAuctioneer(long userId,
			Integer page, Integer pageSize);

	public User getAuctioneerForItem(long itemId);

	public ImageInfoRepresentation addImageForItem(Long itemId, byte[] imageBytes, String imageName) throws IOException, ImageQueueFullException;
	
	byte[] getThumbnailImageForItem(long itemId, UUID itemImageId);

	byte[] getPreviewImageForItem(long itemId, UUID itemImageId);

	byte[] getFullImageForItem(long itemId, UUID itemImageId);

	long getPreviewMisses();

	long getThumbnailMisses();

	long getFullMisses();

	byte[] getThumbnailImageForItemCacheable(long itemId, UUID itemImageId);

	List<ImageInfo> getImageInfosForItem(Long itemId);

}

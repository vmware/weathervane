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

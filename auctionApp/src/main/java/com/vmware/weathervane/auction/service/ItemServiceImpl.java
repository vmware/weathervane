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
/**
 * 
 *
 * @author hrosenbe
 */
package com.vmware.weathervane.auction.service;

import java.io.IOException;
import java.util.ArrayList;
import java.util.Date;
import java.util.GregorianCalendar;
import java.util.List;
import java.util.UUID;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.imageStore.ImageQueueFullException;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.NoSuchImageException;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo.ImageInfoKey;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade.ImageSize;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.Item.ItemState;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ImageInfoRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionService;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;

/**
 * @author hrosenbe
 * 
 */
public class ItemServiceImpl implements ItemService {

	private static final Logger logger = LoggerFactory.getLogger(ItemServiceImpl.class);

	@Inject
	@Named("auctionDao")
	private AuctionDao auctionDao;

	@Inject
	@Named("itemDao")
	private ItemDao itemDao;

	@Inject
	@Named("highBidDao")
	private HighBidDao highBidDao;

	@Inject
	@Named("imageStoreFacade")
	private ImageStoreFacade imageStore;

	@Inject
	@Named("liveAuctionService")
	private LiveAuctionService liveAuctionService;
	
	@Inject
	ImageStoreFacade imageStoreFacade;
	
	private static long thumbnailMisses = 0;
	private static long previewMisses = 0;
	private static long fullMisses = 0;
	
	/*
	 * (non-Javadoc)
	 * 
	 * @see com.vmware.liveAuction.services.ItemService#getItem(java.lang.Long)
	 */
	@Override
	@Transactional(readOnly=true)
	@Cacheable(value="itemCache")
	public ItemRepresentation getItem(Long itemId) {

		Item theItem = itemDao.get(itemId);
		List<ImageInfo> theImageInfos = imageStoreFacade.getImageInfos(Item.class.getSimpleName(), itemId);

		// createItemRepresentation can deal with the case where currentItem is
		// null
		return new ItemRepresentation(theItem, theImageInfos, false);
	}

	@Override
	@Transactional(readOnly=true)
	public List<ImageInfo> getImageInfosForItem(Long itemId) {

		Item theItem = itemDao.get(itemId);
		return imageStoreFacade.getImageInfos(Item.class.getSimpleName(), itemId);

	}

	@Override
	@Transactional(readOnly = true)
	@Cacheable(value="itemsForAuctionCache")
	public CollectionRepresentation<ItemRepresentation> getItems(Long auctionId, Integer page, Integer pageSize) {
		ArrayList<ItemRepresentation> liveItems = new ArrayList<ItemRepresentation>();

		Auction theAuction = auctionDao.get(auctionId);
		
		// Get the total number of items for this auction
		Long totalRecords = auctionDao.getItemCountforAuction(theAuction);

		// Get all auctions and convert them to LiveAuctions
		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants
				.getCollectionPageSize(pageSize);
		logger.info("ItemServiceImpl::GetItems totalRecords = "
				+ totalRecords + ", page = " + realPage + ", pageSize = "
				+ realPageSize);

		List<Item> itemList = auctionDao.getItemPageForAuction(theAuction, realPage, realPageSize);
		logger.info("ItemServiceImpl::GetItems Got " + itemList.size()
				+ " records back.");

		for (Item anItem : itemList) {
			List<ImageInfo> theImageInfos = imageStoreFacade.getImageInfos(Item.class.getSimpleName(), anItem.getId());
			liveItems.add(new ItemRepresentation(anItem, theImageInfos, false));
		}

		CollectionRepresentation<ItemRepresentation> colRep = new CollectionRepresentation<ItemRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(totalRecords);
		colRep.setResults(liveItems);

		return colRep;

	}

	@Override
	@Transactional(readOnly = true)
	public CollectionRepresentation<ItemRepresentation> getItemsForAuctioneer(long userId, Integer page, Integer pageSize) {

		// Get the total number of items for this auction
		Long totalRecords = itemDao.getItemCountForAuctioneer(userId);

		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants
				.getCollectionPageSize(pageSize);
		
		logger.info("ItemServiceImpl::getItemsForAuctioneer totalRecords = "
				+ totalRecords + ", page = " + realPage + ", pageSize = "
				+ realPageSize);

		List<Item> queryResults = null;
		
		queryResults = itemDao.getItemsPageForAuctioneer(userId, realPage, realPageSize);
			
		
		ArrayList<ItemRepresentation> liveItems = new ArrayList<ItemRepresentation>();
		for (Item anItem : queryResults) {
			List<ImageInfo> theImageInfos = imageStoreFacade.getImageInfos(Item.class.getSimpleName(), anItem.getId());
			liveItems.add(new ItemRepresentation(anItem, theImageInfos, false));
		}

		CollectionRepresentation<ItemRepresentation> colRep = new CollectionRepresentation<ItemRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(totalRecords);
		colRep.setResults(liveItems);

		return colRep;
	}

	@Override
	@Transactional(readOnly = true)
	public CollectionRepresentation<ItemRepresentation> getPurchasedItemsForUser(
			long userId, Date fromDate, Date toDate, Integer page,
			Integer pageSize) {

		// Get the total number of items for this auction
		Long totalRecords = highBidDao.getPurchasedItemCountforUser(userId);

		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants
				.getCollectionPageSize(pageSize);
		
		logger.info("ItemServiceImpl::getPurchasedItemsForUser totalRecords = "
				+ totalRecords + ", page = " + realPage + ", pageSize = "
				+ realPageSize);

		List<Item> queryResults = null;
		
		if (fromDate == null) 
			if (toDate == null)
				queryResults = highBidDao.getPurchasedItemsPageForUser(userId, realPage, realPageSize);
			else 
				queryResults = highBidDao.getPurchasedItemsPageForUserToDate(userId, toDate, realPage, realPageSize);
		else 
			if (toDate == null)
				queryResults = highBidDao.getPurchasedItemsPageForUserFromDate(userId, fromDate, realPage, realPageSize);	
			else
				queryResults = highBidDao.getPurchasedItemsPageForUserFromDateToDate(userId, fromDate, toDate, realPage, realPageSize);	
			
		
		ArrayList<ItemRepresentation> liveItems = new ArrayList<ItemRepresentation>();
		for (Item anItem : queryResults) {
			List<ImageInfo> theImageInfos = imageStoreFacade.getImageInfos(Item.class.getSimpleName(), anItem.getId());
			liveItems.add(new ItemRepresentation(anItem, theImageInfos, false));
		}

		CollectionRepresentation<ItemRepresentation> colRep = new CollectionRepresentation<ItemRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(totalRecords);
		colRep.setResults(liveItems);

		return colRep;
	}

	@Override
	@Transactional
	public ItemRepresentation addItem(ItemRepresentation theItem, Long userId) {
		Item anItem = new Item();
		anItem.setCondition(theItem.getCondition());
		anItem.setDateOfOrigin(theItem.getDateOfOrigin());
		anItem.setLongDescription(theItem.getLongDescription());
		anItem.setManufacturer(theItem.getManufacturer());
		anItem.setShortDescription(theItem.getName());
		anItem.setStartingBidAmount(theItem.getStartingBidAmount());
		anItem.setState(ItemState.NOTLISTED);
		anItem.setPreloaded(false);
		
		anItem = itemDao.addItemForAuctioneer(anItem, userId);
	
		return new ItemRepresentation(anItem);
	}

	@Override
	public User getAuctioneerForItem(ItemRepresentation theItem) {
		User theAuctioneer = itemDao.getAuctioneer(theItem.getId());
		
		return theAuctioneer;
	}

	@Override
	public User getAuctioneerForItem(long itemId) {
		User theAuctioneer = itemDao.getAuctioneer(itemId);
		
		return theAuctioneer;
	}

	@Override
	@Transactional
	public ItemRepresentation updateItem(ItemRepresentation theItem) {
		logger.info("ItemServiceImpl::updateItem");
		
		Item updateItem = new Item();
		
		updateItem.setId(theItem.getId());
		updateItem.setShortDescription(theItem.getName());
		updateItem.setManufacturer(theItem.getManufacturer());
		updateItem.setLongDescription(theItem.getLongDescription());
		updateItem.setStartingBidAmount(theItem.getStartingBidAmount());
		updateItem.setCondition(theItem.getCondition());
		updateItem.setDateOfOrigin(theItem.getDateOfOrigin());
		

		updateItem = itemDao.updateItem(updateItem);
		List<ImageInfo> theImageInfos = imageStoreFacade.getImageInfos(Item.class.getSimpleName(), updateItem.getId());

		return new ItemRepresentation(updateItem, theImageInfos, false);
	
	}

	@Override
	@Transactional
	public ImageInfoRepresentation addImageForItem(Long itemId, byte[] imageBytes, String imageName) throws IOException, ImageQueueFullException {
		GregorianCalendar foc = FixedOffsetCalendarFactory.getCalendar();
		
		// Now save the image
		ImageInfo imageInfo = new ImageInfo();
		ImageInfoKey key = new ImageInfoKey();
		key.setEntitytype(Item.class.getSimpleName());
		key.setEntityid(itemId);
		key.setPreloaded(false);
		imageInfo.setKey(key);
		imageInfo.setDateadded(foc.getTime());
		imageInfo.setName(imageName);
		
		imageInfo = imageStore.addImage(imageInfo, imageBytes);
		
		return new ImageInfoRepresentation(imageInfo);
	}
	
	@Override
	@Cacheable(value="itemThumbnailImageCache")
	public byte[] getThumbnailImageForItemCacheable(long itemId, UUID itemImageId) {
		logger.info("getThumbnailImageForItem: Getting image for itemId=" + itemId + ", imageId=" + itemImageId);
		thumbnailMisses++;
		byte[] image = null;
		try {
			image = imageStore.retrieveImage(itemImageId, ImageSize.THUMBNAIL);
			logger.info("getThumbnailImageForItem: Got image for itemId=" + itemId + ", imageId=" + itemImageId + ", number of bytes = " + image.length);

		} catch (NoSuchImageException e) {
			logger.warn("getThumbnailImageForItem: Got NoSuchImageException when retrieving image: " + e.getMessage());
		} catch (IOException e) {
			logger.warn("getThumbnailImageForItem: Got Ioexception when retrieving image: " + e.getMessage());
		}
		return image;

		
	}

	
	@Override
	@Cacheable(value="itemThumbnailImageCache")
	public byte[] getThumbnailImageForItem(long itemId, UUID itemImageId) {
		logger.info("getThumbnailImageForItem: Getting image for itemId=" + itemId + ", imageId=" + itemImageId);
		byte[] image = null;
		try {
			image = imageStore.retrieveImage(itemImageId, ImageSize.THUMBNAIL);
			logger.info("getThumbnailImageForItem: Got image for itemId=" + itemId + ", imageId=" + itemImageId + ", number of bytes = " + image.length);

		} catch (NoSuchImageException e) {
			logger.warn("getThumbnailImageForItem: Got NoSuchImageException when retrieving image: " + e.getMessage());
		} catch (IOException e) {
			logger.warn("getThumbnailImageForItem: Got Ioexception when retrieving image: " + e.getMessage());
		}
		return image;

		
	}

	@Override
	@Cacheable(value="itemPreviewImageCache")
	public byte[] getPreviewImageForItem(long itemId, UUID itemImageId) {
		logger.info("getPreviewImageForItem: Getting image for itemId=" + itemId + ", imageId=" + itemImageId);
		previewMisses++;
		
		byte[] image = null;
		try {
			image = imageStore.retrieveImage(itemImageId, ImageSize.PREVIEW);
			logger.info("getPreviewImageForItem: Got image for itemId=" + itemId + ", imageId=" + itemImageId + ", number of bytes = " + image.length);
		} catch (NoSuchImageException e) {
			logger.warn("getPreviewImageForItem: Got NoSuchImageException when retrieving image: " + e.getMessage());
		} catch (IOException e) {
			logger.warn("getPreviewImageForItem: Got Ioexception when retrieving image: " + e.getMessage());
		}
		return image;

		
	}

	@Override
	@Cacheable(value="itemFullImageCache")
	public byte[] getFullImageForItem(long itemId, UUID itemImageId) {
		logger.info("getFullImageForItem: Getting image for itemId=" + itemId + ", imageId=" + itemImageId);
		fullMisses++;
		
		byte[] image = null;
		try {
			image = imageStore.retrieveImage(itemImageId, ImageSize.FULL);
			logger.info("getFullImageForItem: Got image for itemId=" + itemId + ", imageId=" + itemImageId + ", number of bytes = " + image.length);

		} catch (NoSuchImageException e) {
			logger.warn("getFullImageForItem: Got NoSuchImageException when retrieving image: " + e.getMessage());
		} catch (IOException e) {
			logger.warn("getFullImageForItem: Got Ioexception when retrieving image: " + e.getMessage());
		}
		return image;

		
	}

	@Override
	public long getThumbnailMisses() {
		return thumbnailMisses;
	}

	@Override
	public long getPreviewMisses() {
		return previewMisses;
	}

	@Override
	public long getFullMisses() {
		return fullMisses;
	}

}

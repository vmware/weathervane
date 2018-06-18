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
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.List;

import javax.annotation.PostConstruct;
import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.rest.representation.UserRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionService;

/**
 * @author Hal
 * 
 */
public class CacheWarmerServiceImpl implements CacheWarmerService {

	private static final Logger logger = LoggerFactory.getLogger(CacheWarmerServiceImpl.class);

	@Inject
	@Named("liveAuctionService")
	private LiveAuctionService liveAuctionService;

	@Inject
	@Named("itemService")
	private ItemService itemService;

	@Inject
	@Named("auctionService")
	private AuctionService auctionService;
	
	@Inject
	@Named("userService")
	private UserService userService;
	
	@Inject
	@Named("userDao")
	UserDao userDao;

	private Boolean cachesWarmed = false;

	public CacheWarmerServiceImpl() {

	}

	@PostConstruct
	public void warmCaches() {
		logger.debug("Warming caches");
		/*
		 * First get all of the active auction pages by pagesSize=5 and save the
		 * auctionIds.
		 */
		int pageSize = 5;
		List<Long> auctionIds = new ArrayList<Long>();
		CollectionRepresentation<AuctionRepresentation> activeAuctions = liveAuctionService.getActiveAuctions(0, pageSize);
		long totalAuctions = activeAuctions.getTotalRecords();
		long numPages = (long) Math.ceil(totalAuctions / (pageSize * 1.0));
		logger.debug("Warming caches.  There are " + totalAuctions + " auctions in " + numPages + " pages.");
		for (int pageNum = 0; pageNum < numPages; pageNum++) {
			logger.debug("Warming caches. Getting active auctions page " + pageNum);
			activeAuctions = liveAuctionService.getActiveAuctions(pageNum, pageSize);
			List<AuctionRepresentation> results = activeAuctions.getResults();
			for (AuctionRepresentation anAuction : results) {
				auctionIds.add(anAuction.getId());
			}
		}
		
		/*
		 * Get all of the individual active auctions, the
		 * first page of items, and all of the items on that page
		 */
		for (Long auctionId: auctionIds) {
			logger.debug("Warming caches. Getting auction for auctionId " + auctionId);
			auctionService.getAuction(auctionId);
			logger.debug("Warming caches. Getting first items page for auctionId " + auctionId);
			CollectionRepresentation<ItemRepresentation> activeItems = 	itemService.getItems(auctionId, 0, pageSize);
			List<ItemRepresentation> items = activeItems.getResults();
			for (ItemRepresentation item : items) {
				logger.debug("Warming caches. Getting item for itemId " + item.getId());
				itemService.getItem(item.getId());
			}
		}
		
		/*
		 * Warm the auth token cache
		 */
		logger.debug("Warming caches. Getting logged in users");
		List<User> loggedInUsers = userDao.getLoggedInUsers();
		if (loggedInUsers != null) {
			logger.debug("Warming caches. There are " + loggedInUsers.size() + " logged in users");
			for (User aUser : loggedInUsers) {
				if (aUser.isLoggedin()) {
					try {
						UserRepresentation userRep = userService.getUserByAuthToken(aUser.getAuthToken());
						logger.debug("Warming caches. Got userId " + userRep.getId() + " for authToken " + aUser.getAuthToken() );
					} catch (Exception e) {
						
					}
				}
			}
		}
		
		cachesWarmed = true;
	}

	@Override
	public boolean isReady() {
		return cachesWarmed;
	}

}

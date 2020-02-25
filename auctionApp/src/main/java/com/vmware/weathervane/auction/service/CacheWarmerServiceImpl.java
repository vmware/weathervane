/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.atomic.AtomicBoolean;

import javax.annotation.PostConstruct;
import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.dao.AuctionDao;
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

	@Inject
	@Named("auctionDao")
	AuctionDao auctionDao;	

	private boolean cachesWarmed = false;
	private AtomicBoolean warmerRun = new AtomicBoolean(false);

	public CacheWarmerServiceImpl() {

	}

	@Override
	public boolean isReady() {
		if (!warmerRun.getAndSet(true)) {
			Boolean preWarm = Boolean.getBoolean("PREWARM");
			if (preWarm) {
				logger.warn("Prewarming caches");
				// Start the cache warmer on the first healthCheck
				Thread warmerThread = new Thread(new CacheWarmingRunner(), "cacheWarmer");
				warmerThread.start();
			} else {
				logger.warn("Not prewarming caches");
				cachesWarmed = true;
			}
		}
		return cachesWarmed;
	}

	protected class CacheWarmingRunner implements Runnable {

		@Override
		public void run() {
			logger.debug("Warming caches");
			/*
			 * Wait until the number of running auctions equals the number of 
			 * activated auctions
			 */
			long activatedAuctions = auctionDao.countByCurrentAndActivated(true, true);
			long runningAuctions = auctionDao.countActiveAuctions();
			while (runningAuctions < activatedAuctions) {
				logger.debug("activatedAuctions=={}, runningAuctions=={}: Sleeping for 5 seconds", activatedAuctions, runningAuctions);
				try {
					Thread.sleep(5000);
				} catch (InterruptedException e) {
					logger.warn("InterruptedException while waiting for auctions to be running: {}", e.getMessage());
				}
				runningAuctions = auctionDao.countActiveAuctions();
			}
			logger.debug("activatedAuctions==runningAuctions=={}", runningAuctions);
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
	}
}

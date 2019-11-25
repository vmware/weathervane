/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
/**
 * 
 *
 * @author Hal
 */
package com.vmware.weathervane.auction.service.liveAuction;

import java.util.Date;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import javax.inject.Inject;
import javax.inject.Named;
import javax.persistence.NonUniqueResultException;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.EmptyResultDataAccessException;
import org.springframework.transaction.annotation.Transactional;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.dao.AuctionMgmtDao;
import com.vmware.weathervane.auction.data.dao.HighBidDao;
import com.vmware.weathervane.auction.data.dao.ItemDao;
import com.vmware.weathervane.auction.data.dao.UserDao;
import com.vmware.weathervane.auction.data.imageStore.ImageStoreFacade;
import com.vmware.weathervane.auction.data.imageStore.model.ImageInfo;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.data.model.AuctionMgmt;
import com.vmware.weathervane.auction.data.model.HighBid;
import com.vmware.weathervane.auction.data.model.Item;
import com.vmware.weathervane.auction.data.model.User;
import com.vmware.weathervane.auction.data.model.Auction.AuctionState;
import com.vmware.weathervane.auction.data.model.HighBid.HighBidState;
import com.vmware.weathervane.auction.data.model.Item.ItemState;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.BidRepresentation;
import com.vmware.weathervane.auction.rest.representation.ItemRepresentation;
import com.vmware.weathervane.auction.service.BidService;
import com.vmware.weathervane.auction.service.exception.AuctionNoItemsException;
import com.vmware.weathervane.auction.service.exception.InvalidStateException;
import com.vmware.weathervane.auction.util.FixedOffsetCalendarFactory;


/**
 * This class holds all of the transactions that must execute on behalf of
 * the service-specific threads running in the LiveAuctionServiceLocalImpl.
 * They are separated out because an object calling one of its own methods
 * does not start a transaction even if @Transactional is specified unless
 * mode="aspectj" is used in <tx:annotation-driven/>. Using aspectj mode
 * required load-time weaving, which we do not want to have to rely on.
 * 
 * @author Hal
 * 
 */
@Transactional
public class LiveAuctionServiceTxImpl implements LiveAuctionServiceTx {

	private static final Logger logger = LoggerFactory.getLogger(LiveAuctionServiceTxImpl.class);

	@Inject
	@Named("auctionDao")
	AuctionDao auctionDao;

	@Inject
	@Named("itemDao")
	ItemDao itemDao;

	@Inject
	@Named("userDao")
	UserDao userDao;

	@Inject
	@Named("auctionMgmtDao")
	AuctionMgmtDao liveAuctionMgmtDao;

	@Inject
	@Named("highBidDao")
	HighBidDao highBidDao;
	
	@Inject
	@Named("bidService")
	private BidService bidService;
	
	@Inject
	ImageStoreFacade imageStoreFacade;
	
	public LiveAuctionServiceTxImpl() {

	}

	@Override
	@Transactional
	public boolean becomeMaster(Long nodeNumber) {
		AuctionMgmt liveAuctionMgmt = liveAuctionMgmtDao.findByIdForUpdate(0L);
		boolean becameMaster = false;
		if (liveAuctionMgmt.getMasternodeid() == null) {
			becameMaster = true;
			liveAuctionMgmt.setMasternodeid(nodeNumber);
		}
		return becameMaster;	
	}

}

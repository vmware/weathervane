/*
Copyright 2017-2019 VMware, Inc.
SPDX-License-Identifier: BSD-2-Clause
*/
package com.vmware.weathervane.auction.service;

import java.util.ArrayList;
import java.util.List;

import javax.inject.Inject;
import javax.inject.Named;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.Cacheable;

import com.vmware.weathervane.auction.data.dao.AuctionDao;
import com.vmware.weathervane.auction.data.model.Auction;
import com.vmware.weathervane.auction.rest.representation.AuctionRepresentation;
import com.vmware.weathervane.auction.rest.representation.CollectionRepresentation;
import com.vmware.weathervane.auction.service.liveAuction.LiveAuctionServiceConstants;

public class AuctionServiceImpl implements AuctionService {

	private static final Logger logger = LoggerFactory
			.getLogger(AuctionServiceImpl.class);

	private static long auctionMisses = 0;

	@Inject
	@Named("auctionDao")
	AuctionDao auctionDao;

	public CollectionRepresentation<AuctionRepresentation> getAuctions(Integer page, Integer pageSize) {
		logger.info("AuctionServiceImpl::GetAuctions");
		ArrayList<AuctionRepresentation> liveAuctions = new ArrayList<AuctionRepresentation>();

		// Get the total number of auctions
		Long totalRecords = auctionDao.getCount();
		
		// Get all auctions and convect them to AuctionRepresentations
		Integer realPage = LiveAuctionServiceConstants.getCollectionPage(page);
		Integer realPageSize = LiveAuctionServiceConstants.getCollectionPageSize(pageSize);
		logger.info("AuctionServiceImpl::GetAuctions totalRecords = " + totalRecords + ", page = " + realPage + ", pageSize = " + realPageSize);

		List<Auction> auctionList = auctionDao.getPage(realPage, realPageSize);
		logger.info("AuctionServiceImpl::GetAuctions Got " +  auctionList.size() + " records back.");

		for (Auction anAuction : auctionList) {
			liveAuctions.add(new AuctionRepresentation(anAuction));
		}

		CollectionRepresentation<AuctionRepresentation> colRep = new CollectionRepresentation<AuctionRepresentation>();
		colRep.setPage(realPage);
		colRep.setPageSize(realPageSize);
		colRep.setTotalRecords(totalRecords);
		colRep.setResults(liveAuctions);
		
		return colRep;

	}

	@Cacheable(value="auctionRepresentationCache")
	public AuctionRepresentation getAuction(Long id) {

		logger.info("LiveAuctionController::getAuction id = " + id
				+ "; intvalue = " + id.intValue());
		auctionMisses++;
		Auction anAuction = auctionDao.get(id);

		return new AuctionRepresentation(anAuction);
	}

	@Override
	public long getAuctionMisses() {
		return auctionMisses;
	}

}
